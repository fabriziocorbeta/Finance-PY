# FinancePY Mobile App (React Native) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a React Native Android app that captures Google Wallet PYG purchase notifications via a native `NotificationListenerService` module and posts them to FinancePY's existing webhook, plus OAuth login and a read-only recent-transactions view.

**Architecture:** Bare React Native CLI app in `mobile/financespy-app/` inside the `cd-co-erp` repo. Three layers: (1) a thin Kotlin native module that only listens for and forwards raw Wallet notifications, (2) JS/TS business logic (regex extraction, card→account mapping, webhook POST, pending-capture queue) that is fully unit-testable without a device, (3) JS/TS OAuth (Doorkeeper, Authorization Code + PKCE) and a read-only transaction list screen.

**Tech Stack:** React Native (bare CLI) 0.81.x, TypeScript, Kotlin (native module), Jest + `@testing-library/react-native`, `react-native-keychain`, `react-native-app-auth`, `@react-native-async-storage/async-storage` (non-sensitive pending-queue data only).

## Global Constraints

- Never reference the upstream fork's brand name anywhere in code, strings, package IDs, or commit messages — use "FinancePY" / "upstream" only (per project convention, see [[Naming FinancePY]] in the vault).
- Secure tokens (OAuth access/refresh tokens, the Android webhook bearer token) must live in Android Keystore via `react-native-keychain`, never in `AsyncStorage` or hardcoded in JS.
- The capture write path uses the existing `POST /webhooks/android_purchase` endpoint (static bearer token) — do not build new idempotency logic against `api/v1/transactions#create`; that is explicitly out of scope per the design spec's Non-goals.
- Minimum Android SDK: 26 (Android 8.0) — required for reliable `NotificationListenerService` behavior on modern OEM battery management. Target SDK: 35 (latest stable at time of writing; bump to the current Play-required target if this slips before the app is ever store-distributed, though this phase is sideload-only).
- All new UI strings in Spanish (matches FinancePY's Rails `es.yml` default locale and Fabrizio's usage).
- No Play Store/TestFlight work, no Expo, no Detox/Maestro E2E — see spec Non-goals.

Full design context: `docs/superpowers/specs/2026-08-10-financespy-mobile-app-design.md`.

---

## Task 1: Scaffold the React Native project

**Files:**
- Create: `mobile/financespy-app/` (entire RN project, via CLI generator)
- Create: `mobile/financespy-app/.gitignore`
- Modify: `.gitignore` (repo root, if it doesn't already exclude `mobile/financespy-app/node_modules` etc. — RN's own generated `.gitignore` inside the subfolder handles this, but confirm the root one doesn't fight it)

**Interfaces:**
- Produces: a runnable RN Android project at `mobile/financespy-app/` that later tasks add native modules, screens, and business logic into.

- [ ] **Step 1: Generate the project**

Run from the repo root:

```bash
cd mobile 2>/dev/null || mkdir -p mobile && cd mobile
npx @react-native-community/cli@latest init FinancePYApp --directory financespy-app --package-name com.cdco.financespy.mobile --skip-install
cd financespy-app
```

Note the package name `com.cdco.financespy.mobile` — distinct from `financespy-twa`'s `py.com.cd_co.finance.twa`, and contains no upstream brand reference.

- [ ] **Step 2: Install dependencies and TypeScript template deps**

```bash
npm install
```

Expected: completes without error, `node_modules/` populated.

- [ ] **Step 3: Verify the app builds and runs on a connected device/emulator**

```bash
npx react-native run-android
```

Expected: default RN welcome screen launches on the device. If no device/emulator is attached, this step can be deferred to Task 2's verification — do not block scaffolding on having a device connected right now, but do not skip verifying it eventually before Task 2 is considered done.

- [ ] **Step 4: Commit**

```bash
cd ../..  # back to repo root
git add mobile/financespy-app
git commit -m "feat: scaffold FinancePY mobile app (React Native bare CLI)"
```

---

## Task 2: Native module — `NotificationListenerModule` (Kotlin)

**Files:**
- Create: `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/WalletNotificationListenerService.kt`
- Create: `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/NotificationListenerModule.kt`
- Create: `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/NotificationListenerPackage.kt`
- Modify: `mobile/financespy-app/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/MainApplication.kt`
- Test: `mobile/financespy-app/__tests__/NotificationListenerBridge.test.ts`

**Interfaces:**
- Produces (JS-facing): a native module accessible as `NativeModules.NotificationListener` with:
  - `isPermissionGranted(): Promise<boolean>`
  - `openNotificationAccessSettings(): void`
  - A `DeviceEventEmitter` event named `"WalletNotificationReceived"`, payload `{ packageName: string; title: string; text: string }`.

This task's native Kotlin code cannot be meaningfully unit-tested (no JVM test harness is set up for the native Android side in this plan — see spec's Testing section, which explicitly accepts this and defers verification to on-device manual testing plus the JS-side bridge test below). The JS-side test in this task verifies only that the bridge module is correctly exposed and typed from the JS side, using a mock of `NativeModules` — it does not exercise real notification delivery.

- [ ] **Step 1: Add the notification listener service permission and declaration to the manifest**

Edit `mobile/financespy-app/android/app/src/main/AndroidManifest.xml`, inside the `<application>` tag:

```xml
<service
    android:name=".WalletNotificationListenerService"
    android:label="FinancePY Wallet Listener"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
    android:exported="false">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

- [ ] **Step 2: Write the native listener service**

Create `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/WalletNotificationListenerService.kt`:

```kotlin
package com.cdco.financespy.mobile

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.facebook.react.ReactApplication
import com.facebook.react.bridge.Arguments
import com.facebook.react.modules.core.DeviceEventManagerModule

class WalletNotificationListenerService : NotificationListenerService() {
    companion object {
        const val WALLET_PACKAGE = "com.google.android.apps.walletnfcrel"
        const val EVENT_NAME = "WalletNotificationReceived"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != WALLET_PACKAGE) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        val reactApplication = application as? ReactApplication ?: return
        val reactContext = reactApplication.reactHost?.currentReactContext ?: return

        val params = Arguments.createMap().apply {
            putString("packageName", sbn.packageName)
            putString("title", title)
            putString("text", text)
        }

        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(EVENT_NAME, params)
    }
}
```

- [ ] **Step 3: Write the native module bridge (permission check + settings deep link)**

Create `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/NotificationListenerModule.kt`:

```kotlin
package com.cdco.financespy.mobile

import android.content.Intent
import android.provider.Settings
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class NotificationListenerModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName() = "NotificationListener"

    @ReactMethod
    fun isPermissionGranted(promise: Promise) {
        val enabledListeners = Settings.Secure.getString(
            reactApplicationContext.contentResolver,
            "enabled_notification_listeners"
        ) ?: ""
        val granted = enabledListeners.contains(reactApplicationContext.packageName)
        promise.resolve(granted)
    }

    @ReactMethod
    fun openNotificationAccessSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        reactApplicationContext.startActivity(intent)
    }
}
```

- [ ] **Step 4: Register the module in a React package**

Create `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/NotificationListenerPackage.kt`:

```kotlin
package com.cdco.financespy.mobile

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class NotificationListenerPackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
        return listOf(NotificationListenerModule(reactContext))
    }

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        return emptyList()
    }
}
```

- [ ] **Step 5: Register the package in `MainApplication.kt`**

Open `mobile/financespy-app/android/app/src/main/java/com/cdco/financespy/mobile/MainApplication.kt` and find the `getPackages()` override (generated by the RN template). Add the new package to the returned list:

```kotlin
override fun getPackages(): List<ReactPackage> =
    PackageList(this).packages.apply {
        add(NotificationListenerPackage())
    }
```

- [ ] **Step 6: Write the JS-side bridge type test**

Create `mobile/financespy-app/__tests__/NotificationListenerBridge.test.ts`:

```typescript
import { NativeModules, NativeEventEmitter } from 'react-native';

jest.mock('react-native', () => ({
  NativeModules: {
    NotificationListener: {
      isPermissionGranted: jest.fn().mockResolvedValue(true),
      openNotificationAccessSettings: jest.fn(),
    },
  },
  NativeEventEmitter: jest.fn(),
}));

describe('NotificationListener native module bridge', () => {
  it('exposes isPermissionGranted returning a boolean promise', async () => {
    const granted = await NativeModules.NotificationListener.isPermissionGranted();
    expect(granted).toBe(true);
  });

  it('exposes openNotificationAccessSettings as a callable function', () => {
    NativeModules.NotificationListener.openNotificationAccessSettings();
    expect(NativeModules.NotificationListener.openNotificationAccessSettings).toHaveBeenCalled();
  });
});
```

- [ ] **Step 7: Run the test to verify it passes**

```bash
cd mobile/financespy-app
npx jest __tests__/NotificationListenerBridge.test.ts
```

Expected: 2 passing tests. (This test passes trivially against the mock — its purpose is to lock in the exact method names/shapes Task 3 will import, not to exercise real native code.)

- [ ] **Step 8: Manual on-device verification**

Build and install on a real device (`npx react-native run-android`), open the app, call `NotificationListener.openNotificationAccessSettings()` from a temporary debug button or the RN dev menu's JS console, and confirm Android's notification-access settings screen opens and lists the app. Enable it. This step has no automated pass/fail — record in the task's PR/commit message that it was verified on-device.

- [ ] **Step 9: Commit**

```bash
git add mobile/financespy-app/android mobile/financespy-app/__tests__
git commit -m "feat: add native NotificationListenerModule for Google Wallet capture"
```

---

## Task 3: Regex extraction and card→account mapping (pure JS/TS, TDD)

**Files:**
- Create: `mobile/financespy-app/src/capture/extractPurchase.ts`
- Create: `mobile/financespy-app/src/capture/accountMapping.ts`
- Test: `mobile/financespy-app/__tests__/extractPurchase.test.ts`
- Test: `mobile/financespy-app/__tests__/accountMapping.test.ts`

**Interfaces:**
- Produces:
  - `extractPurchase(notificationText: string): { amount: string; cardText: string } | null` — from `src/capture/extractPurchase.ts`.
  - `mapCardToAccountId(cardText: string): string | null` — from `src/capture/accountMapping.ts`.
- Consumes: nothing (pure functions, no native or network dependency — this is why they're plan-ordered before the native module needs to be wired up).

- [ ] **Step 1: Write the failing tests for `extractPurchase`**

Create `mobile/financespy-app/__tests__/extractPurchase.test.ts`:

```typescript
import { extractPurchase } from '../src/capture/extractPurchase';

describe('extractPurchase', () => {
  it('extracts amount and card text from a real confirmed Wallet notification', () => {
    const result = extractPurchase('PYG112,000 con GNB GOOGLE ••6536');
    expect(result).toEqual({ amount: '112,000', cardText: 'GNB GOOGLE ••6536' });
  });

  it('extracts from a larger amount', () => {
    const result = extractPurchase('PYG1,250,000 con Amex Gold ••2269');
    expect(result).toEqual({ amount: '1,250,000', cardText: 'Amex Gold ••2269' });
  });

  it('returns null for text that does not match the expected format', () => {
    expect(extractPurchase('Some unrelated notification text')).toBeNull();
  });

  it('returns null for empty text', () => {
    expect(extractPurchase('')).toBeNull();
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
npx jest __tests__/extractPurchase.test.ts
```

Expected: FAIL — `Cannot find module '../src/capture/extractPurchase'`.

- [ ] **Step 3: Implement `extractPurchase`**

Create `mobile/financespy-app/src/capture/extractPurchase.ts`:

```typescript
const PURCHASE_PATTERN = /PYG([\d,]+) con (.+)/;

export function extractPurchase(
  notificationText: string
): { amount: string; cardText: string } | null {
  const match = notificationText.match(PURCHASE_PATTERN);
  if (!match) return null;

  const [, amount, cardText] = match;
  return { amount, cardText: cardText.trim() };
}
```

- [ ] **Step 4: Run to verify pass**

```bash
npx jest __tests__/extractPurchase.test.ts
```

Expected: 4 passing tests.

- [ ] **Step 5: Write the failing tests for `mapCardToAccountId`**

Create `mobile/financespy-app/__tests__/accountMapping.test.ts`:

```typescript
import { mapCardToAccountId } from '../src/capture/accountMapping';

describe('mapCardToAccountId', () => {
  it('maps Ueno-branded card text to the Ueno account', () => {
    expect(mapCardToAccountId('UENO GPAY ••2601')).toBe(
      '74fa6687-bbf7-45d2-aa71-f06bca3b2013'
    );
  });

  it('maps Amex-branded card text to the Amex account', () => {
    expect(mapCardToAccountId('Amex Gold ••2269')).toBe(
      'd47f5223-a988-46f5-9bc5-beefc4c7fefd'
    );
  });

  it('maps CLASICA card text to the Mastercard-Conti account', () => {
    expect(mapCardToAccountId('MASTERCARD CLASICA ••8394')).toBe(
      '952d06b3-f915-4cf1-b4c2-952fb131f2be'
    );
  });

  it('maps GNB card text to the MasterCard-GNB account', () => {
    expect(mapCardToAccountId('GNB GOOGLE ••6536')).toBe(
      '43d84b14-b3be-44a9-be37-7ec1ae4661f2'
    );
  });

  it('returns null for unrecognized card text', () => {
    expect(mapCardToAccountId('Some Other Bank ••1234')).toBeNull();
  });
});
```

- [ ] **Step 6: Run to verify failure**

```bash
npx jest __tests__/accountMapping.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 7: Implement `mapCardToAccountId`**

Create `mobile/financespy-app/src/capture/accountMapping.ts`:

```typescript
const CARD_TO_ACCOUNT_ID: Record<string, string> = {
  Ueno: '74fa6687-bbf7-45d2-aa71-f06bca3b2013',
  Amex: 'd47f5223-a988-46f5-9bc5-beefc4c7fefd',
  CLASICA: '952d06b3-f915-4cf1-b4c2-952fb131f2be',
  GNB: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
};

export function mapCardToAccountId(cardText: string): string | null {
  for (const [substring, accountId] of Object.entries(CARD_TO_ACCOUNT_ID)) {
    if (cardText.toLowerCase().includes(substring.toLowerCase())) {
      return accountId;
    }
  }
  return null;
}
```

- [ ] **Step 8: Run to verify pass**

```bash
npx jest __tests__/accountMapping.test.ts
```

Expected: 5 passing tests.

- [ ] **Step 9: Commit**

```bash
git add mobile/financespy-app/src/capture mobile/financespy-app/__tests__/extractPurchase.test.ts mobile/financespy-app/__tests__/accountMapping.test.ts
git commit -m "feat: add purchase extraction and card-to-account mapping logic"
```

---

## Task 4: Secure token storage wrapper

**Files:**
- Create: `mobile/financespy-app/src/storage/secureStorage.ts`
- Test: `mobile/financespy-app/__tests__/secureStorage.test.ts`
- Modify: `mobile/financespy-app/package.json` (add `react-native-keychain` dependency)

**Interfaces:**
- Produces:
  - `saveWebhookToken(token: string): Promise<void>`
  - `getWebhookToken(): Promise<string | null>`
  - `saveOAuthTokens(tokens: { accessToken: string; refreshToken: string }): Promise<void>`
  - `getOAuthTokens(): Promise<{ accessToken: string; refreshToken: string } | null>`
  - `clearOAuthTokens(): Promise<void>`
- Consumes: `react-native-keychain`'s `setGenericPassword`/`getGenericPassword`/`resetGenericPassword`, scoped by a `service` string per credential type.

- [ ] **Step 1: Install the dependency**

```bash
cd mobile/financespy-app
npm install react-native-keychain
npx pod-install 2>/dev/null || true  # no-op on this Android-only phase, harmless if it fails
```

- [ ] **Step 2: Write the failing test**

Create `mobile/financespy-app/__tests__/secureStorage.test.ts`:

```typescript
import * as Keychain from 'react-native-keychain';
import {
  saveWebhookToken,
  getWebhookToken,
  saveOAuthTokens,
  getOAuthTokens,
  clearOAuthTokens,
} from '../src/storage/secureStorage';

jest.mock('react-native-keychain', () => ({
  setGenericPassword: jest.fn().mockResolvedValue(true),
  getGenericPassword: jest.fn(),
  resetGenericPassword: jest.fn().mockResolvedValue(true),
}));

describe('secureStorage', () => {
  afterEach(() => jest.clearAllMocks());

  it('saves the webhook token under its own keychain service', async () => {
    await saveWebhookToken('abc123');
    expect(Keychain.setGenericPassword).toHaveBeenCalledWith(
      'webhook-token',
      'abc123',
      { service: 'financespy.webhookToken' }
    );
  });

  it('retrieves a saved webhook token', async () => {
    (Keychain.getGenericPassword as jest.Mock).mockResolvedValue({
      username: 'webhook-token',
      password: 'abc123',
    });
    const token = await getWebhookToken();
    expect(token).toBe('abc123');
  });

  it('returns null when no webhook token is stored', async () => {
    (Keychain.getGenericPassword as jest.Mock).mockResolvedValue(false);
    const token = await getWebhookToken();
    expect(token).toBeNull();
  });

  it('saves and retrieves OAuth tokens as JSON under their own service', async () => {
    await saveOAuthTokens({ accessToken: 'at', refreshToken: 'rt' });
    expect(Keychain.setGenericPassword).toHaveBeenCalledWith(
      'oauth-tokens',
      JSON.stringify({ accessToken: 'at', refreshToken: 'rt' }),
      { service: 'financespy.oauthTokens' }
    );

    (Keychain.getGenericPassword as jest.Mock).mockResolvedValue({
      username: 'oauth-tokens',
      password: JSON.stringify({ accessToken: 'at', refreshToken: 'rt' }),
    });
    const tokens = await getOAuthTokens();
    expect(tokens).toEqual({ accessToken: 'at', refreshToken: 'rt' });
  });

  it('clears OAuth tokens', async () => {
    await clearOAuthTokens();
    expect(Keychain.resetGenericPassword).toHaveBeenCalledWith({
      service: 'financespy.oauthTokens',
    });
  });
});
```

- [ ] **Step 3: Run to verify failure**

```bash
npx jest __tests__/secureStorage.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 4: Implement `secureStorage`**

Create `mobile/financespy-app/src/storage/secureStorage.ts`:

```typescript
import * as Keychain from 'react-native-keychain';

const WEBHOOK_TOKEN_SERVICE = 'financespy.webhookToken';
const OAUTH_TOKENS_SERVICE = 'financespy.oauthTokens';

export async function saveWebhookToken(token: string): Promise<void> {
  await Keychain.setGenericPassword('webhook-token', token, {
    service: WEBHOOK_TOKEN_SERVICE,
  });
}

export async function getWebhookToken(): Promise<string | null> {
  const result = await Keychain.getGenericPassword({ service: WEBHOOK_TOKEN_SERVICE });
  return result ? result.password : null;
}

export interface OAuthTokens {
  accessToken: string;
  refreshToken: string;
}

export async function saveOAuthTokens(tokens: OAuthTokens): Promise<void> {
  await Keychain.setGenericPassword('oauth-tokens', JSON.stringify(tokens), {
    service: OAUTH_TOKENS_SERVICE,
  });
}

export async function getOAuthTokens(): Promise<OAuthTokens | null> {
  const result = await Keychain.getGenericPassword({ service: OAUTH_TOKENS_SERVICE });
  return result ? (JSON.parse(result.password) as OAuthTokens) : null;
}

export async function clearOAuthTokens(): Promise<void> {
  await Keychain.resetGenericPassword({ service: OAUTH_TOKENS_SERVICE });
}
```

Note: `getGenericPassword` in real `react-native-keychain` resolves to `false` (not `null`) when nothing is stored — the test above and implementation both account for this.

- [ ] **Step 5: Run to verify pass**

```bash
npx jest __tests__/secureStorage.test.ts
```

Expected: 5 passing tests.

- [ ] **Step 6: Commit**

```bash
git add mobile/financespy-app/src/storage mobile/financespy-app/__tests__/secureStorage.test.ts mobile/financespy-app/package.json mobile/financespy-app/package-lock.json
git commit -m "feat: add Keystore-backed secure storage for webhook and OAuth tokens"
```

---

## Task 5: Webhook client and pending-capture queue

**Files:**
- Create: `mobile/financespy-app/src/capture/webhookClient.ts`
- Create: `mobile/financespy-app/src/capture/pendingQueue.ts`
- Test: `mobile/financespy-app/__tests__/webhookClient.test.ts`
- Test: `mobile/financespy-app/__tests__/pendingQueue.test.ts`
- Modify: `mobile/financespy-app/package.json` (add `@react-native-async-storage/async-storage`)

**Interfaces:**
- Consumes: `getWebhookToken()` from Task 4.
- Produces:
  - `postPurchaseToWebhook(payload: { accountId: string; amount: string; merchant: string; item: string; rawText: string }): Promise<'created' | 'duplicate' | { error: string }>` — from `webhookClient.ts`.
  - `addPendingCapture(entry: PendingCapture): Promise<void>`, `getPendingCaptures(): Promise<PendingCapture[]>`, `removePendingCapture(id: string): Promise<void>` — from `pendingQueue.ts`, where `PendingCapture = { id: string; capturedAt: string; rawText: string; accountId: string; amount: string; merchant: string; item: string }`.

Pending-queue data is not sensitive (no tokens, just unsent transaction text) — `AsyncStorage` is appropriate here, unlike Task 4's tokens.

- [ ] **Step 1: Write the failing test for `webhookClient`**

Create `mobile/financespy-app/__tests__/webhookClient.test.ts`:

```typescript
import { postPurchaseToWebhook } from '../src/capture/webhookClient';
import { getWebhookToken } from '../src/storage/secureStorage';

jest.mock('../src/storage/secureStorage', () => ({
  getWebhookToken: jest.fn(),
}));

const mockFetch = jest.fn();
global.fetch = mockFetch as unknown as typeof fetch;

describe('postPurchaseToWebhook', () => {
  const payload = {
    accountId: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
    amount: '112,000',
    merchant: 'GNB GOOGLE ••6536',
    item: 'Google Wallet',
    rawText: 'PYG112,000 con GNB GOOGLE ••6536',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    (getWebhookToken as jest.Mock).mockResolvedValue('secret-token');
  });

  it('posts to the webhook with the Bearer token and returns "created" on 201', async () => {
    mockFetch.mockResolvedValue({ status: 201, json: async () => ({ received: true, duplicate: false }) });

    const result = await postPurchaseToWebhook(payload);

    expect(result).toBe('created');
    expect(mockFetch).toHaveBeenCalledWith(
      'https://finance.cd-co.com.py/webhooks/android_purchase',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer secret-token',
          'Content-Type': 'application/json',
        }),
      })
    );
  });

  it('returns "duplicate" when the server reports a duplicate', async () => {
    mockFetch.mockResolvedValue({ status: 200, json: async () => ({ received: true, duplicate: true }) });
    const result = await postPurchaseToWebhook(payload);
    expect(result).toBe('duplicate');
  });

  it('returns an error object with the server message on failure', async () => {
    mockFetch.mockResolvedValue({ status: 422, json: async () => ({ error: 'amount is required and must be numeric' }) });
    const result = await postPurchaseToWebhook(payload);
    expect(result).toEqual({ error: 'amount is required and must be numeric' });
  });

  it('returns an error object when no webhook token is stored', async () => {
    (getWebhookToken as jest.Mock).mockResolvedValue(null);
    const result = await postPurchaseToWebhook(payload);
    expect(result).toEqual({ error: 'No webhook token configured' });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('returns an error object on network failure', async () => {
    mockFetch.mockRejectedValue(new Error('Network request failed'));
    const result = await postPurchaseToWebhook(payload);
    expect(result).toEqual({ error: 'Network request failed' });
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
npx jest __tests__/webhookClient.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement `webhookClient`**

Create `mobile/financespy-app/src/capture/webhookClient.ts`:

```typescript
import { getWebhookToken } from '../storage/secureStorage';

const WEBHOOK_URL = 'https://finance.cd-co.com.py/webhooks/android_purchase';

export interface PurchasePayload {
  accountId: string;
  amount: string;
  merchant: string;
  item: string;
  rawText: string;
}

export type WebhookResult = 'created' | 'duplicate' | { error: string };

export async function postPurchaseToWebhook(payload: PurchasePayload): Promise<WebhookResult> {
  const token = await getWebhookToken();
  if (!token) {
    return { error: 'No webhook token configured' };
  }

  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        account_id: payload.accountId,
        amount: payload.amount,
        merchant: payload.merchant,
        item: payload.item,
        raw_text: payload.rawText,
      }),
    });

    const body = await response.json();

    if (response.status === 201 || response.status === 200) {
      return body.duplicate ? 'duplicate' : 'created';
    }

    return { error: body.error ?? `Unexpected status ${response.status}` };
  } catch (err) {
    return { error: err instanceof Error ? err.message : 'Unknown network error' };
  }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
npx jest __tests__/webhookClient.test.ts
```

Expected: 5 passing tests.

- [ ] **Step 5: Install AsyncStorage and write the failing test for `pendingQueue`**

```bash
npm install @react-native-async-storage/async-storage
```

Create `mobile/financespy-app/__tests__/pendingQueue.test.ts`:

```typescript
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  addPendingCapture,
  getPendingCaptures,
  removePendingCapture,
  PendingCapture,
} from '../src/capture/pendingQueue';

jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock')
);

const sampleCapture: PendingCapture = {
  id: 'capture-1',
  capturedAt: '2026-08-10T10:00:00.000Z',
  rawText: 'PYG112,000 con GNB GOOGLE ••6536',
  accountId: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
  amount: '112,000',
  merchant: 'GNB GOOGLE ••6536',
  item: 'Google Wallet',
};

describe('pendingQueue', () => {
  beforeEach(async () => {
    await AsyncStorage.clear();
  });

  it('starts empty', async () => {
    expect(await getPendingCaptures()).toEqual([]);
  });

  it('adds a pending capture and retrieves it', async () => {
    await addPendingCapture(sampleCapture);
    expect(await getPendingCaptures()).toEqual([sampleCapture]);
  });

  it('accumulates multiple pending captures', async () => {
    await addPendingCapture(sampleCapture);
    await addPendingCapture({ ...sampleCapture, id: 'capture-2' });
    const all = await getPendingCaptures();
    expect(all).toHaveLength(2);
  });

  it('removes a pending capture by id', async () => {
    await addPendingCapture(sampleCapture);
    await addPendingCapture({ ...sampleCapture, id: 'capture-2' });
    await removePendingCapture('capture-1');
    const remaining = await getPendingCaptures();
    expect(remaining).toEqual([{ ...sampleCapture, id: 'capture-2' }]);
  });
});
```

- [ ] **Step 6: Run to verify failure**

```bash
npx jest __tests__/pendingQueue.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 7: Implement `pendingQueue`**

Create `mobile/financespy-app/src/capture/pendingQueue.ts`:

```typescript
import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY = 'financespy.pendingCaptures';

export interface PendingCapture {
  id: string;
  capturedAt: string;
  rawText: string;
  accountId: string;
  amount: string;
  merchant: string;
  item: string;
}

async function readAll(): Promise<PendingCapture[]> {
  const raw = await AsyncStorage.getItem(STORAGE_KEY);
  return raw ? (JSON.parse(raw) as PendingCapture[]) : [];
}

async function writeAll(captures: PendingCapture[]): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(captures));
}

export async function addPendingCapture(entry: PendingCapture): Promise<void> {
  const current = await readAll();
  await writeAll([...current, entry]);
}

export async function getPendingCaptures(): Promise<PendingCapture[]> {
  return readAll();
}

export async function removePendingCapture(id: string): Promise<void> {
  const current = await readAll();
  await writeAll(current.filter((c) => c.id !== id));
}
```

- [ ] **Step 8: Run to verify pass**

```bash
npx jest __tests__/pendingQueue.test.ts
```

Expected: 4 passing tests.

- [ ] **Step 9: Commit**

```bash
git add mobile/financespy-app/src/capture mobile/financespy-app/__tests__/webhookClient.test.ts mobile/financespy-app/__tests__/pendingQueue.test.ts mobile/financespy-app/package.json mobile/financespy-app/package-lock.json
git commit -m "feat: add webhook client and pending-capture queue for failed sends"
```

---

## Task 6: Capture pipeline — wire native events to extraction, mapping, webhook, and local notifications

**Files:**
- Create: `mobile/financespy-app/src/capture/captureController.ts`
- Test: `mobile/financespy-app/__tests__/captureController.test.ts`
- Modify: `mobile/financespy-app/App.tsx` (register the event listener on app start)
- Modify: `mobile/financespy-app/package.json` (add `@notifee/react-native` for local notifications — chosen over the deprecated `react-native-push-notification` for its actively maintained local-notification API)

**Interfaces:**
- Consumes:
  - `extractPurchase` (Task 3), `mapCardToAccountId` (Task 3)
  - `postPurchaseToWebhook` (Task 5), `addPendingCapture` (Task 5)
  - A native event `"WalletNotificationReceived"` with payload `{ packageName, title, text }` (Task 2)
- Produces: `handleWalletNotification(event: { packageName: string; title: string; text: string }): Promise<void>` — the single entry point Task 8's debug button also calls directly, so both real and simulated notifications go through identical logic.

- [ ] **Step 1: Install the local-notification library**

```bash
cd mobile/financespy-app
npm install @notifee/react-native
```

- [ ] **Step 2: Write the failing test**

Create `mobile/financespy-app/__tests__/captureController.test.ts`:

```typescript
import notifee from '@notifee/react-native';
import { handleWalletNotification } from '../src/capture/captureController';
import { postPurchaseToWebhook } from '../src/capture/webhookClient';
import { addPendingCapture } from '../src/capture/pendingQueue';

jest.mock('@notifee/react-native', () => ({
  displayNotification: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../src/capture/webhookClient');
jest.mock('../src/capture/pendingQueue');

const realNotification = {
  packageName: 'com.google.android.apps.walletnfcrel',
  title: '#A EUSTAQUI-PLAZA MADE',
  text: 'PYG112,000 con GNB GOOGLE ••6536',
};

describe('handleWalletNotification', () => {
  beforeEach(() => jest.clearAllMocks());

  it('posts to the webhook and shows a success notification when extraction and mapping succeed', async () => {
    (postPurchaseToWebhook as jest.Mock).mockResolvedValue('created');

    await handleWalletNotification(realNotification);

    expect(postPurchaseToWebhook).toHaveBeenCalledWith({
      accountId: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
      amount: '112,000',
      merchant: 'GNB GOOGLE ••6536',
      item: '#A EUSTAQUI-PLAZA MADE',
      rawText: 'PYG112,000 con GNB GOOGLE ••6536',
    });
    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({
        title: expect.stringContaining('registrado'),
      })
    );
  });

  it('treats a duplicate response as success, no error notification', async () => {
    (postPurchaseToWebhook as jest.Mock).mockResolvedValue('duplicate');

    await handleWalletNotification(realNotification);

    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({ title: expect.stringContaining('ya estaba registrad') })
    );
  });

  it('shows an unrecognized-card notification and never calls the webhook when the card does not match', async () => {
    await handleWalletNotification({
      ...realNotification,
      text: 'PYG50,000 con Banco Desconocido ••9999',
    });

    expect(postPurchaseToWebhook).not.toHaveBeenCalled();
    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({ title: expect.stringContaining('no reconocida') })
    );
  });

  it('does nothing when the notification text does not match the expected purchase format', async () => {
    await handleWalletNotification({ ...realNotification, text: 'Unrelated text' });

    expect(postPurchaseToWebhook).not.toHaveBeenCalled();
    expect(notifee.displayNotification).not.toHaveBeenCalled();
  });

  it('queues a pending capture and shows an error notification when the webhook call fails', async () => {
    (postPurchaseToWebhook as jest.Mock).mockResolvedValue({ error: 'Network request failed' });

    await handleWalletNotification(realNotification);

    expect(addPendingCapture).toHaveBeenCalledWith(
      expect.objectContaining({
        rawText: 'PYG112,000 con GNB GOOGLE ••6536',
        accountId: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
      })
    );
    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({ title: expect.stringContaining('pudo registrar') })
    );
  });
});
```

- [ ] **Step 3: Run to verify failure**

```bash
npx jest __tests__/captureController.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 4: Implement `captureController`**

Create `mobile/financespy-app/src/capture/captureController.ts`:

```typescript
import notifee from '@notifee/react-native';
import { extractPurchase } from './extractPurchase';
import { mapCardToAccountId } from './accountMapping';
import { postPurchaseToWebhook } from './webhookClient';
import { addPendingCapture } from './pendingQueue';

export interface WalletNotificationEvent {
  packageName: string;
  title: string;
  text: string;
}

export async function handleWalletNotification(event: WalletNotificationEvent): Promise<void> {
  const extracted = extractPurchase(event.text);
  if (!extracted) return;

  const { amount, cardText } = extracted;
  const accountId = mapCardToAccountId(cardText);

  if (!accountId) {
    await notifee.displayNotification({
      title: `Tarjeta no reconocida: ${cardText}`,
      body: 'No se registró ningún gasto automáticamente.',
    });
    return;
  }

  const result = await postPurchaseToWebhook({
    accountId,
    amount,
    merchant: cardText,
    item: event.title,
    rawText: event.text,
  });

  if (result === 'created') {
    await notifee.displayNotification({
      title: `₲${amount} registrado`,
      body: `Cuenta: ${cardText}`,
    });
    return;
  }

  if (result === 'duplicate') {
    await notifee.displayNotification({
      title: 'Esta compra ya estaba registrada',
      body: `₲${amount} — ${cardText}`,
    });
    return;
  }

  await addPendingCapture({
    id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
    capturedAt: new Date().toISOString(),
    rawText: event.text,
    accountId,
    amount,
    merchant: cardText,
    item: event.title,
  });

  await notifee.displayNotification({
    title: 'No se pudo registrar el gasto automáticamente',
    body: `${result.error} — guardado para reintentar desde la app.`,
  });
}
```

- [ ] **Step 5: Run to verify pass**

```bash
npx jest __tests__/captureController.test.ts
```

Expected: 5 passing tests.

- [ ] **Step 6: Wire the native event listener in `App.tsx`**

Open `mobile/financespy-app/App.tsx` and add, inside the root component (using a `useEffect` that runs once on mount):

```typescript
import { useEffect } from 'react';
import { DeviceEventEmitter } from 'react-native';
import { handleWalletNotification } from './src/capture/captureController';

// Inside the App component, before the return statement:
useEffect(() => {
  const subscription = DeviceEventEmitter.addListener(
    'WalletNotificationReceived',
    handleWalletNotification
  );
  return () => subscription.remove();
}, []);
```

(This edit is additive to whatever `App.tsx` already contains from the Task 1 scaffold — do not remove the existing template content, just add this import and effect.)

- [ ] **Step 7: Commit**

```bash
git add mobile/financespy-app/src/capture/captureController.ts mobile/financespy-app/__tests__/captureController.test.ts mobile/financespy-app/App.tsx mobile/financespy-app/package.json mobile/financespy-app/package-lock.json
git commit -m "feat: wire native Wallet notifications through extraction, mapping, and webhook pipeline"
```

---

## Task 7: Backend — rename the OAuth application away from the upstream brand name

**Files:**
- Modify: `~/code/financespy/db/seeds/oauth_applications.rb`
- Modify: `~/code/financespy/app/models/mobile_device.rb`
- Test: existing tests referencing `"Sure Mobile"` — search and update

**Interfaces:**
- Produces: a `Doorkeeper::Application` named `"FinancePY Mobile"` with `redirect_uri: "financespy://oauth/callback"`, replacing the upstream-branded one. Task 8's `react-native-app-auth` config in the RN app must use this exact new redirect URI.

This task is in the **`cd-co-erp` Rails repo** (`~/code/financespy`), not the RN app — it's a backend prerequisite for Task 8's OAuth flow.

- [ ] **Step 1: Find every reference to the old app name and redirect scheme**

```bash
cd ~/code/financespy
grep -rn "Sure Mobile\|sureapp://" app/ db/ test/ 2>/dev/null
```

Expected output includes at least `db/seeds/oauth_applications.rb` and `app/models/mobile_device.rb` (both already read earlier in this session) — update every match found, not just these two if more turn up.

- [ ] **Step 2: Update `mobile_device.rb`**

In `app/models/mobile_device.rb`, change:

```ruby
CALLBACK_URL = "sureapp://oauth/callback"
```

to:

```ruby
CALLBACK_URL = "financespy://oauth/callback"
```

And change every `Doorkeeper::Application.find_or_create_by(name: "Sure Mobile")` / `find_by!(name: "Sure Mobile")` in that file to `"FinancePY Mobile"`.

- [ ] **Step 3: Update `db/seeds/oauth_applications.rb`**

Change `Doorkeeper::Application.find_or_create_by(name: "Sure Mobile")` to `find_or_create_by(name: "FinancePY Mobile")`, and its `redirect_uri` value to `"financespy://oauth/callback"`.

- [ ] **Step 4: Update any test fixtures/expectations referencing the old name**

For each file the Step 1 grep found under `test/`, update the string literals to match. (Exact files depend on the grep output — this plan cannot enumerate them without re-running the search live, per the Global Constraint against placeholders; the implementer must act on the real Step 1 output here rather than skip this because no file list was pre-supplied.)

- [ ] **Step 5: Re-seed the OAuth application locally and run the full test suite**

```bash
RAILS_ENV=test bin/rails db:seed:replant  # or the project's existing seed-refresh command if db:seed:replant isn't set up — check bin/rails db:seed --help output first
bin/rails test
```

Expected: all tests pass (matching the 3710-run, 0-failure baseline already established this session — see prior commits `5b1daba`/`f20fa8d` in the same repo for the working local test setup: rbenv 3.4.7, Postgres 16, Redis, `RAILS_ENV=test`, `POSTGRES_USER=$(whoami)`).

- [ ] **Step 6: Commit and push (this repo already has an established push cadence this session — confirm with Fabrizio per his usual approval-before-push preference rather than assuming)**

```bash
git add app/models/mobile_device.rb db/seeds/oauth_applications.rb
git commit -m "fix: rename mobile OAuth app and redirect scheme away from upstream brand name"
```

Do not push without Fabrizio's explicit go-ahead, consistent with how every other change this session was handled.

---

## Task 8: OAuth login flow (Doorkeeper, Authorization Code + PKCE)

**Files:**
- Create: `mobile/financespy-app/src/auth/authConfig.ts`
- Create: `mobile/financespy-app/src/auth/AuthContext.tsx`
- Test: `mobile/financespy-app/__tests__/authConfig.test.ts`
- Modify: `mobile/financespy-app/android/app/src/main/AndroidManifest.xml` (register the `financespy://` redirect scheme)
- Modify: `mobile/financespy-app/package.json` (add `react-native-app-auth`)

**Interfaces:**
- Consumes: `saveOAuthTokens`, `getOAuthTokens`, `clearOAuthTokens` (Task 4).
- Produces:
  - `AUTH_CONFIG` (from `authConfig.ts`): the `react-native-app-auth` config object.
  - `AuthProvider` / `useAuth()` (from `AuthContext.tsx`), exposing `{ isAuthenticated: boolean; login(): Promise<void>; logout(): Promise<void>; getValidAccessToken(): Promise<string | null> }` — Task 9's transaction list consumes `getValidAccessToken()`.

- [ ] **Step 1: Install the dependency**

```bash
cd mobile/financespy-app
npm install react-native-app-auth
```

- [ ] **Step 2: Register the redirect URI scheme in the manifest**

Add inside the main `<activity>` tag in `mobile/financespy-app/android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="financespy" />
</intent-filter>
```

- [ ] **Step 3: Write the failing test for the auth config shape**

Create `mobile/financespy-app/__tests__/authConfig.test.ts`:

```typescript
import { AUTH_CONFIG } from '../src/auth/authConfig';

describe('AUTH_CONFIG', () => {
  it('points at the FinancePY OAuth endpoints with PKCE and the renamed redirect scheme', () => {
    expect(AUTH_CONFIG).toEqual({
      issuer: 'https://finance.cd-co.com.py',
      serviceConfiguration: {
        authorizationEndpoint: 'https://finance.cd-co.com.py/oauth/authorize',
        tokenEndpoint: 'https://finance.cd-co.com.py/oauth/token',
      },
      clientId: 'financespy-mobile-app',
      redirectUrl: 'financespy://oauth/callback',
      scopes: ['read_write'],
      usePKCE: true,
    });
  });
});
```

- [ ] **Step 4: Run to verify failure**

```bash
npx jest __tests__/authConfig.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 5: Implement `authConfig`**

Create `mobile/financespy-app/src/auth/authConfig.ts`:

```typescript
import { AuthConfiguration } from 'react-native-app-auth';

export const AUTH_CONFIG: AuthConfiguration = {
  issuer: 'https://finance.cd-co.com.py',
  serviceConfiguration: {
    authorizationEndpoint: 'https://finance.cd-co.com.py/oauth/authorize',
    tokenEndpoint: 'https://finance.cd-co.com.py/oauth/token',
  },
  clientId: 'financespy-mobile-app',
  redirectUrl: 'financespy://oauth/callback',
  scopes: ['read_write'],
  usePKCE: true,
};
```

Note: `clientId` here (`financespy-mobile-app`) is a placeholder value that must be replaced with the real `uid` Doorkeeper generated for the `"FinancePY Mobile"` application created in Task 7 — retrieve it with `Doorkeeper::Application.find_by(name: "FinancePY Mobile").uid` in a Rails console against the same environment this app will authenticate against, and hardcode the real value here before this is usable end-to-end. This is not a "TBD" left for later — it is a concrete, mechanical value substitution documented so the implementer doesn't skip it silently.

- [ ] **Step 6: Run to verify pass**

```bash
npx jest __tests__/authConfig.test.ts
```

Expected: 1 passing test (after substituting the real `clientId` per Step 5's note, if that changes the expected value in Step 3's test — update the test to match the real `uid` before considering this task done).

- [ ] **Step 7: Implement the auth context**

Create `mobile/financespy-app/src/auth/AuthContext.tsx`:

```typescript
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { authorize, refresh } from 'react-native-app-auth';
import { AUTH_CONFIG } from './authConfig';
import { saveOAuthTokens, getOAuthTokens, clearOAuthTokens } from '../storage/secureStorage';

interface AuthContextValue {
  isAuthenticated: boolean;
  login: () => Promise<void>;
  logout: () => Promise<void>;
  getValidAccessToken: () => Promise<string | null>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    getOAuthTokens().then((tokens) => setIsAuthenticated(tokens !== null));
  }, []);

  async function login() {
    const result = await authorize(AUTH_CONFIG);
    await saveOAuthTokens({
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    });
    setIsAuthenticated(true);
  }

  async function logout() {
    await clearOAuthTokens();
    setIsAuthenticated(false);
  }

  async function getValidAccessToken(): Promise<string | null> {
    const tokens = await getOAuthTokens();
    if (!tokens) return null;

    try {
      const refreshed = await refresh(AUTH_CONFIG, { refreshToken: tokens.refreshToken });
      await saveOAuthTokens({
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? tokens.refreshToken,
      });
      return refreshed.accessToken;
    } catch {
      await clearOAuthTokens();
      setIsAuthenticated(false);
      return null;
    }
  }

  return (
    <AuthContext.Provider value={{ isAuthenticated, login, logout, getValidAccessToken }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}
```

Note: this always refreshes on `getValidAccessToken()` rather than trying to cache-and-check expiry client-side — simpler and avoids clock-skew bugs, at the cost of one extra network round-trip per screen load. Acceptable for a low-frequency, single-screen MVP; revisit only if this becomes a real latency problem.

- [ ] **Step 8: Manual on-device verification**

Wrap the app root in `<AuthProvider>` in `App.tsx`, add a temporary login button calling `useAuth().login()`, build and run on-device, and confirm the full OAuth redirect round-trip works against the real `finance.cd-co.com.py` server after Task 7's backend change is deployed. Record verification in the commit message — no automated test can exercise the real browser redirect.

- [ ] **Step 9: Commit**

```bash
git add mobile/financespy-app/src/auth mobile/financespy-app/__tests__/authConfig.test.ts mobile/financespy-app/android/app/src/main/AndroidManifest.xml mobile/financespy-app/package.json mobile/financespy-app/package-lock.json
git commit -m "feat: add OAuth2 PKCE login flow against Doorkeeper"
```

---

## Task 9: Recent-transactions screen

**Files:**
- Create: `mobile/financespy-app/src/api/transactionsApi.ts`
- Create: `mobile/financespy-app/src/screens/TransactionsScreen.tsx`
- Test: `mobile/financespy-app/__tests__/transactionsApi.test.ts`
- Modify: `mobile/financespy-app/App.tsx` (render `TransactionsScreen` when authenticated, login screen otherwise)

**Interfaces:**
- Consumes: `useAuth().getValidAccessToken()` (Task 8).
- Produces: `fetchRecentTransactions(accessToken: string): Promise<Transaction[]>` where `Transaction = { id: string; date: string; amount: string; name: string; accountName: string }`, from `transactionsApi.ts`.

- [ ] **Step 1: Write the failing test**

Create `mobile/financespy-app/__tests__/transactionsApi.test.ts`:

```typescript
import { fetchRecentTransactions } from '../src/api/transactionsApi';

const mockFetch = jest.fn();
global.fetch = mockFetch as unknown as typeof fetch;

describe('fetchRecentTransactions', () => {
  beforeEach(() => jest.clearAllMocks());

  it('fetches and maps the 20 most recent transactions', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        transactions: [
          {
            id: 't1',
            date: '2026-08-10',
            amount: '-112000.0',
            name: 'GNB GOOGLE ••6536',
            account: { name: 'MasterCard - GNB' },
          },
        ],
      }),
    });

    const result = await fetchRecentTransactions('access-token-123');

    expect(mockFetch).toHaveBeenCalledWith(
      'https://finance.cd-co.com.py/api/v1/transactions?per_page=20',
      { headers: { Authorization: 'Bearer access-token-123' } }
    );
    expect(result).toEqual([
      { id: 't1', date: '2026-08-10', amount: '-112000.0', name: 'GNB GOOGLE ••6536', accountName: 'MasterCard - GNB' },
    ]);
  });

  it('throws when the response is not ok', async () => {
    mockFetch.mockResolvedValue({ ok: false, status: 401, json: async () => ({ error: 'unauthorized' }) });
    await expect(fetchRecentTransactions('bad-token')).rejects.toThrow('unauthorized');
  });
});
```

- [ ] **Step 2: Run to verify failure**

```bash
npx jest __tests__/transactionsApi.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement `transactionsApi`**

Create `mobile/financespy-app/src/api/transactionsApi.ts`:

```typescript
export interface Transaction {
  id: string;
  date: string;
  amount: string;
  name: string;
  accountName: string;
}

export async function fetchRecentTransactions(accessToken: string): Promise<Transaction[]> {
  const response = await fetch('https://finance.cd-co.com.py/api/v1/transactions?per_page=20', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const body = await response.json();

  if (!response.ok) {
    throw new Error(body.error ?? `Unexpected status ${response.status}`);
  }

  return body.transactions.map((t: any) => ({
    id: t.id,
    date: t.date,
    amount: t.amount,
    name: t.name,
    accountName: t.account.name,
  }));
}
```

Note: the exact response shape (`{ transactions: [...] }` with `account: { name }` nested) must be confirmed against the real `api/v1/transactions#index` jbuilder view before this is trusted — re-check `app/views/api/v1/transactions/index.json.jbuilder` in the Rails repo during implementation and adjust the mapping in this function (and the test's mock shape) if it differs from what's assumed here.

- [ ] **Step 4: Run to verify pass**

```bash
npx jest __tests__/transactionsApi.test.ts
```

Expected: 2 passing tests.

- [ ] **Step 5: Build the screen component**

Create `mobile/financespy-app/src/screens/TransactionsScreen.tsx`:

```typescript
import React, { useEffect, useState } from 'react';
import { View, Text, FlatList, ActivityIndicator, StyleSheet } from 'react-native';
import { useAuth } from '../auth/AuthContext';
import { fetchRecentTransactions, Transaction } from '../api/transactionsApi';

export function TransactionsScreen() {
  const { getValidAccessToken } = useAuth();
  const [transactions, setTransactions] = useState<Transaction[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const token = await getValidAccessToken();
      if (!token) {
        setError('Sesión vencida. Iniciá sesión de nuevo.');
        return;
      }
      try {
        const result = await fetchRecentTransactions(token);
        setTransactions(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error desconocido');
      }
    })();
  }, [getValidAccessToken]);

  if (error) return <View style={styles.container}><Text>{error}</Text></View>;
  if (!transactions) return <View style={styles.container}><ActivityIndicator /></View>;

  return (
    <FlatList
      data={transactions}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => (
        <View style={styles.row}>
          <Text>{item.date}</Text>
          <Text>{item.name} — {item.accountName}</Text>
          <Text>₲{item.amount}</Text>
        </View>
      )}
      ListEmptyComponent={<Text style={styles.empty}>Sin transacciones recientes.</Text>}
    />
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  row: { padding: 12, borderBottomWidth: 1, borderBottomColor: '#eee' },
  empty: { textAlign: 'center', marginTop: 32 },
});
```

- [ ] **Step 6: Wire it into `App.tsx`**

Update `mobile/financespy-app/App.tsx` to render `TransactionsScreen` when `useAuth().isAuthenticated` is true, and a simple login button (calling `useAuth().login()`) otherwise — replacing the temporary debug login button added in Task 8 Step 8.

- [ ] **Step 7: Manual on-device verification**

Build and run on-device, log in, and confirm the list renders real transactions from the account. Record verification in the commit message.

- [ ] **Step 8: Commit**

```bash
git add mobile/financespy-app/src/api mobile/financespy-app/src/screens mobile/financespy-app/__tests__/transactionsApi.test.ts mobile/financespy-app/App.tsx
git commit -m "feat: add recent-transactions screen"
```

---

## Task 10: Permission-status banner and debug "Simular notificación" action

**Files:**
- Create: `mobile/financespy-app/src/components/NotificationPermissionBanner.tsx`
- Create: `mobile/financespy-app/src/screens/DebugScreen.tsx`
- Test: `mobile/financespy-app/__tests__/NotificationPermissionBanner.test.tsx`
- Modify: `mobile/financespy-app/App.tsx`
- Modify: `mobile/financespy-app/package.json` (add `@testing-library/react-native` dev dependency)

**Interfaces:**
- Consumes: `NativeModules.NotificationListener.isPermissionGranted()` / `openNotificationAccessSettings()` (Task 2), `handleWalletNotification` (Task 6).

- [ ] **Step 1: Install the RN Testing Library**

```bash
cd mobile/financespy-app
npm install --save-dev @testing-library/react-native
```

- [ ] **Step 2: Write the failing test**

Create `mobile/financespy-app/__tests__/NotificationPermissionBanner.test.tsx`:

```typescript
import React from 'react';
import { render, waitFor, fireEvent } from '@testing-library/react-native';
import { NativeModules } from 'react-native';
import { NotificationPermissionBanner } from '../src/components/NotificationPermissionBanner';

jest.mock('react-native', () => ({
  ...jest.requireActual('react-native'),
  NativeModules: {
    NotificationListener: {
      isPermissionGranted: jest.fn(),
      openNotificationAccessSettings: jest.fn(),
    },
  },
}));

describe('NotificationPermissionBanner', () => {
  it('renders nothing when permission is already granted', async () => {
    (NativeModules.NotificationListener.isPermissionGranted as jest.Mock).mockResolvedValue(true);
    const { queryByText } = render(<NotificationPermissionBanner />);
    await waitFor(() => expect(queryByText(/Activar acceso/)).toBeNull());
  });

  it('shows a call-to-action when permission is not granted, and opens settings on tap', async () => {
    (NativeModules.NotificationListener.isPermissionGranted as jest.Mock).mockResolvedValue(false);
    const { findByText } = render(<NotificationPermissionBanner />);
    const button = await findByText(/Activar acceso/);
    fireEvent.press(button);
    expect(NativeModules.NotificationListener.openNotificationAccessSettings).toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: Run to verify failure**

```bash
npx jest __tests__/NotificationPermissionBanner.test.tsx
```

Expected: FAIL — module not found.

- [ ] **Step 4: Implement the banner**

Create `mobile/financespy-app/src/components/NotificationPermissionBanner.tsx`:

```typescript
import React, { useEffect, useState } from 'react';
import { View, Text, Pressable, StyleSheet, NativeModules } from 'react-native';

const { NotificationListener } = NativeModules;

export function NotificationPermissionBanner() {
  const [granted, setGranted] = useState<boolean | null>(null);

  useEffect(() => {
    NotificationListener.isPermissionGranted().then(setGranted);
  }, []);

  if (granted !== false) return null;

  return (
    <View style={styles.banner}>
      <Text style={styles.text}>
        La captura automática de gastos de Google Wallet está desactivada.
      </Text>
      <Pressable
        style={styles.button}
        onPress={() => NotificationListener.openNotificationAccessSettings()}
      >
        <Text style={styles.buttonText}>Activar acceso a notificaciones</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  banner: { backgroundColor: '#fff3cd', padding: 12 },
  text: { marginBottom: 8 },
  button: { alignSelf: 'flex-start' },
  buttonText: { color: '#0066cc', fontWeight: 'bold' },
});
```

- [ ] **Step 5: Run to verify pass**

```bash
npx jest __tests__/NotificationPermissionBanner.test.tsx
```

Expected: 2 passing tests.

- [ ] **Step 6: Build the debug screen with the "Simular notificación" action**

Create `mobile/financespy-app/src/screens/DebugScreen.tsx`:

```typescript
import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { handleWalletNotification } from '../capture/captureController';

const SAMPLE_EVENT = {
  packageName: 'com.google.android.apps.walletnfcrel',
  title: '#A EUSTAQUI-PLAZA MADE',
  text: 'PYG112,000 con GNB GOOGLE ••6536',
};

export function DebugScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Diagnóstico</Text>
      <Pressable style={styles.button} onPress={() => handleWalletNotification(SAMPLE_EVENT)}>
        <Text style={styles.buttonText}>Simular notificación de Wallet</Text>
      </Pressable>
      <Text style={styles.hint}>
        Dispara el pipeline completo (extracción → mapeo → webhook) con datos de prueba,
        sin esperar una compra real.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  title: { fontSize: 18, fontWeight: 'bold', marginBottom: 12 },
  button: { backgroundColor: '#0066cc', padding: 12, borderRadius: 6, marginBottom: 8 },
  buttonText: { color: '#fff', textAlign: 'center' },
  hint: { color: '#666', fontSize: 12 },
});
```

- [ ] **Step 7: Wire both into `App.tsx`**

Add `<NotificationPermissionBanner />` above the main content, and add a simple way to reach `DebugScreen` (a button or a second tab — a full navigation library is out of scope for this MVP; a plain conditional render toggled by a button is sufficient).

- [ ] **Step 8: Manual on-device verification**

Build and run, confirm the banner appears/disappears correctly as the permission is toggled in system settings, and confirm "Simular notificación" produces the same local notification and webhook POST as a real captured purchase would. Record verification in the commit message.

- [ ] **Step 9: Commit**

```bash
git add mobile/financespy-app/src/components mobile/financespy-app/src/screens/DebugScreen.tsx mobile/financespy-app/__tests__/NotificationPermissionBanner.test.tsx mobile/financespy-app/App.tsx mobile/financespy-app/package.json mobile/financespy-app/package-lock.json
git commit -m "feat: add notification-permission banner and debug simulate-notification action"
```

---

## Task 11: Release signing and sideload distribution

**Files:**
- Create: `mobile/financespy-app/android/app/financespy-app.keystore` (generated, not hand-written — see step 1; store the actual passwords in `.local-secrets/`, not in this file's name or in git)
- Modify: `mobile/financespy-app/android/gradle.properties` (signing config references, values pulled from environment/local properties, not committed in plaintext)
- Modify: `mobile/financespy-app/android/app/build.gradle` (release signing config)
- Create: `~/.local-secrets/financespy-app-keystore-notes.md` (outside git entirely — passwords, alias, install instructions)

**Interfaces:**
- Produces: a signed release APK at `mobile/financespy-app/android/app/build/outputs/apk/release/app-release.apk`, installable via `adb install`.

- [ ] **Step 1: Generate a new keystore (distinct from `financespy-twa`'s)**

```bash
cd mobile/financespy-app/android/app
keytool -genkeypair -v -keystore financespy-app.keystore -alias financespy-app \
  -keyalg RSA -keysize 2048 -validity 10000
```

When prompted, choose strong passwords and record them immediately in `~/.local-secrets/financespy-app-keystore-notes.md` (create this file now, outside the git repo, following the same pattern already used for the VM's `.env`/compose secrets per this project's existing convention). Do not commit `financespy-app.keystore` or its passwords to git.

- [ ] **Step 2: Add a `.gitignore` entry for the keystore**

Add to `mobile/financespy-app/android/app/.gitignore` (create the file if it doesn't exist):

```
financespy-app.keystore
```

- [ ] **Step 3: Reference the keystore from Gradle without hardcoding the passwords in a committed file**

In `mobile/financespy-app/android/gradle.properties`, add (these three lines only — do not put actual password values in this committed file; instead read them from environment variables set locally, e.g. in your shell profile, when running a release build):

```properties
FINANCESPY_RELEASE_STORE_FILE=financespy-app.keystore
FINANCESPY_RELEASE_KEY_ALIAS=financespy-app
```

Then in `mobile/financespy-app/android/app/build.gradle`, inside the `android { }` block, add:

```groovy
signingConfigs {
    release {
        storeFile file(FINANCESPY_RELEASE_STORE_FILE)
        storePassword System.getenv("FINANCESPY_KEYSTORE_PASSWORD")
        keyAlias FINANCESPY_RELEASE_KEY_ALIAS
        keyPassword System.getenv("FINANCESPY_KEY_PASSWORD")
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
        // (keep whatever minifyEnabled/proguard settings the RN template already generated here)
    }
}
```

- [ ] **Step 4: Build the signed release APK**

```bash
export FINANCESPY_KEYSTORE_PASSWORD='<the password you recorded in step 1>'
export FINANCESPY_KEY_PASSWORD='<the password you recorded in step 1>'
cd mobile/financespy-app/android
./gradlew assembleRelease
```

Expected: `BUILD SUCCESSFUL`, and `app/build/outputs/apk/release/app-release.apk` exists.

- [ ] **Step 5: Sideload and verify**

```bash
adb install -r app/build/outputs/apk/release/app-release.apk
```

Expected: installs successfully, app icon "FinancePY" (or whatever `app_name` the Task 1 scaffold set) appears on the device.

- [ ] **Step 6: Commit the non-secret parts**

```bash
cd ../../..  # back to repo root
git add mobile/financespy-app/android/gradle.properties mobile/financespy-app/android/app/build.gradle mobile/financespy-app/android/app/.gitignore
git commit -m "feat: add signed release build configuration"
```

Do not `git add` the `.keystore` file itself — confirm `git status` shows it as untracked/ignored before committing.

---

## Self-review notes

- **Spec coverage:** all three components (native module, extraction/mapping/webhook/queue, auth/transactions) are covered by Tasks 2–6, 8–9; error handling (permission banner, pending queue, duplicate handling) by Tasks 6 and 10; testing approach (Jest for JS, manual for native, debug simulate button) by Tasks 2, 3, 5, 6, 10; distribution by Task 11; the backend Doorkeeper rename by Task 7. iOS is explicitly out of scope per the spec and this plan builds nothing for it.
- **Type consistency:** `PendingCapture`, `WalletNotificationEvent`, `Transaction`, `OAuthTokens`, and `WebhookResult` are each defined once (Tasks 5, 6, 9, 4, 5 respectively) and reused by name in every later task that consumes them — no renamed duplicates.
- **Known follow-ups deliberately left for a future plan, not this one:** navigation library (if the app grows past two screens), any UI polish/branding, Play Store distribution, iOS build setup, moving the card-mapping table server-side.
