# PWA Offline-First (Ventas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make FinancePY's Sales module work offline on mobile — cache visited pages for read access, and queue Sale creation for background sync when there's no connection.

**Architecture:** Extend the existing service worker (`app/views/pwa/service-worker.js`) with a runtime cache (network-first for navigations, cache-first for static assets) and a Background Sync handler that replays a queue of pending Sale submissions stored in IndexedDB. A Stimulus controller intercepts the Sale creation form's submit when offline and writes to that queue instead of failing. `SalesController#create` gains a JSON response format so the service worker can reliably parse success/failure when replaying.

**Tech Stack:** Rails 7.2, Hotwire (Turbo + Stimulus via importmap-rails, no bundler), native browser IndexedDB + Service Worker + Background Sync APIs, Minitest (existing test framework).

## Global Constraints

- Spec source of truth: `docs/superpowers/specs/2026-07-23-financespy-pwa-offline-design.md`.
- Scope is Sales creation only — do not add offline write support to any other model.
- `sale_number` is always assigned server-side (`app/models/sale.rb#assign_sale_number`) — never generate it client-side.
- Single device / single user assumption — no cross-device conflict resolution needed.
- **Known environment limitation:** the full Rails test suite cannot run reliably in this sandbox (Ruby 2.6 locally vs. 3.4.7 required; the deployed environment's test DB lacks superuser privileges needed for fixture loading in some contexts). Where a step says "run the test," if the sandbox can't execute it, note that explicitly and verify manually instead (via `bin/rails runner`, curl, or real browser) — do not skip verification, just change its method.
- Service worker (`app/views/pwa/service-worker.js`) is served as a classic (non-module) script by Rails' built-in `rails/pwa` controller — it cannot `import` ES modules from `app/javascript/`. IndexedDB helper logic needed inside the service worker is therefore duplicated in plain form there, separate from the main-thread module used by Stimulus controllers. This is an intentional, documented trade-off, not an oversight.
- Backoff for sync retries: base 5s, doubling up to a 60s cap, max 5 automatic attempts before marking `needs_review` (per spec).

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `app/controllers/sales_controller.rb` | Modify | Add JSON response format to `#create` |
| `test/controllers/sales_controller_test.rb` | Modify | Add test for JSON format on `#create` |
| `app/javascript/services/offline_sales_db.js` | Create | IndexedDB wrapper for main-thread use (add/get/delete/update pending sales) |
| `app/javascript/controllers/offline_sale_form_controller.js` | Create | Intercepts the new-Sale form submit when offline, queues it |
| `app/views/sales/_form.html.erb` | Modify | Wire `offline-sale-form` controller onto the form, only for new (not edit) |
| `app/javascript/controllers/pending_sales_controller.js` | Create | Renders the "pending sync" list on the Sales index page from IndexedDB |
| `app/views/sales/index.html.erb` | Modify | Add the pending-sales container |
| `app/views/pwa/service-worker.js` | Modify | Runtime cache (read) + Background Sync handler (write queue replay) |
| `app/javascript/application.js` | Modify | Add `online` event fallback trigger for browsers without Background Sync (iOS Safari) |

---

## Task 1: JSON response format for Sale creation

**Files:**
- Modify: `app/controllers/sales_controller.rb:26-37`
- Modify: `test/controllers/sales_controller_test.rb`

**Interfaces:**
- Produces: `POST /sales` with `Accept: application/json` now returns `{ id, sale_number }` (201) on success or `{ errors: [...] }` (422) on failure. HTML behavior unchanged.

- [ ] **Step 1: Read the current `#create` action**

Confirm it matches this (it should, per the spec's context):

```ruby
def create
  @sale = Current.family.sales.new(sale_params)

  if @sale.save
    redirect_to @sale, notice: t(".success")
  else
    # Ensure there are always at least 5 rows available in the form on error
    items_needed = 5 - @sale.sale_items.size
    items_needed.times { @sale.sale_items.build } if items_needed > 0
    render :new, status: :unprocessable_entity
  end
end
```

- [ ] **Step 2: Write the failing test**

Add to `test/controllers/sales_controller_test.rb`, inside the `SalesControllerTest` class, near the existing `"should create sale"` test:

```ruby
test "should create sale via json and return sale_number" do
  assert_difference("Sale.count", 1) do
    post sales_url, params: {
      sale: {
        client_name: "JSON Client",
        sale_items_attributes: {
          "0" => {
            product_id: @product.id,
            quantity: 1,
            unit_price: 20
          }
        }
      }
    }, as: :json
  end

  assert_response :created
  body = JSON.parse(response.body)
  assert body["id"].present?
  assert body["sale_number"].present?
end

test "should return json errors on invalid sale" do
  assert_no_difference("Sale.count") do
    post sales_url, params: { sale: { client_name: "" } }, as: :json
  end

  assert_response :unprocessable_entity
  body = JSON.parse(response.body)
  assert body["errors"].present?
end
```

- [ ] **Step 3: Run the test to verify it fails**

If the sandbox's Ruby/Bundler environment can run Rails tests, run:

```bash
bin/rails test test/controllers/sales_controller_test.rb -n "/json/"
```

Expected: FAIL — the current action has no `format.json` branch, so `as: :json` requests currently fall through to the HTML behavior and the response won't be parseable JSON (or will 406/500).

If the sandbox **cannot** run Rails tests (known limitation — see Global Constraints), skip running it here and instead verify manually in Step 5 after implementing, via `curl` against the deployed container (same technique used earlier this session for the AI model benchmarks: `docker exec <web-container> ...` is not applicable here since this needs a real HTTP request — use `curl -X POST` against the running app with a valid session cookie, or `bin/rails runner` calling the controller action indirectly through a real request spec run in the deployed container where the full Ruby version is available).

- [ ] **Step 4: Implement**

Replace the `#create` action in `app/controllers/sales_controller.rb`:

```ruby
def create
  @sale = Current.family.sales.new(sale_params)

  respond_to do |format|
    if @sale.save
      format.html { redirect_to @sale, notice: t(".success") }
      format.json { render json: { id: @sale.id, sale_number: @sale.sale_number }, status: :created }
    else
      # Ensure there are always at least 5 rows available in the form on error
      items_needed = 5 - @sale.sale_items.size
      items_needed.times { @sale.sale_items.build } if items_needed > 0
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: { errors: @sale.errors.full_messages }, status: :unprocessable_entity }
    end
  end
end
```

- [ ] **Step 5: Verify**

If runnable locally:

```bash
bin/rails test test/controllers/sales_controller_test.rb -n "/json/"
```

Expected: PASS.

If not runnable locally (expected, per known limitation), verify in the real deployed container after this task is deployed:

```bash
docker exec financespy-web-1 bin/rails test test/controllers/sales_controller_test.rb -n "/json/" 2>&1
```

Expected: PASS (2 tests, 0 failures). The container has the correct Ruby/Bundler version and can run tests even though the local Mac sandbox cannot.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/sales_controller.rb test/controllers/sales_controller_test.rb
git commit -m "feat: agrega respuesta JSON a SalesController#create para el service worker offline"
```

---

## Task 2: IndexedDB helper module (main-thread)

**Files:**
- Create: `app/javascript/services/offline_sales_db.js`

**Interfaces:**
- Produces: `addPendingSale(entries)`, `getPendingSales()`, `deletePendingSale(id)`, `markNeedsReview(id, message)` — all async, all operating on an IndexedDB object store named `pending_sales` in a database named `financespy_offline` (version 1), keyed by auto-incrementing `id`. Each record shape: `{ id, formData: Array<[key, value]>, createdAt: Number (epoch ms), attempts: Number, status: "pending" | "needs_review", errorMessage?: String }`.
- Consumes: nothing (leaf module).

- [ ] **Step 1: Create the file**

```js
// app/javascript/services/offline_sales_db.js
const DB_NAME = "financespy_offline";
const DB_VERSION = 1;
const STORE_NAME = "pending_sales";

function openDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: "id", autoIncrement: true });
      }
    };
    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject(event.target.error);
  });
}

export async function addPendingSale(entries) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const record = { formData: entries, createdAt: Date.now(), attempts: 0, status: "pending" };
    const request = store.add(record);
    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject(event.target.error);
  });
}

export async function getPendingSales() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readonly");
    const store = tx.objectStore(STORE_NAME);
    const request = store.getAll();
    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject(event.target.error);
  });
}

export async function deletePendingSale(id) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const request = store.delete(id);
    request.onsuccess = () => resolve();
    request.onerror = (event) => reject(event.target.error);
  });
}

export async function markNeedsReview(id, message) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, "readwrite");
    const store = tx.objectStore(STORE_NAME);
    const getRequest = store.get(id);
    getRequest.onsuccess = (event) => {
      const record = event.target.result;
      if (!record) return resolve();
      record.status = "needs_review";
      record.errorMessage = message;
      const putRequest = store.put(record);
      putRequest.onsuccess = () => resolve();
      putRequest.onerror = (e) => reject(e.target.error);
    };
    getRequest.onerror = (event) => reject(event.target.error);
  });
}
```

- [ ] **Step 2: Verify it loads without syntax errors**

```bash
node --check app/javascript/services/offline_sales_db.js
```

Expected: no output (success).

- [ ] **Step 3: Verify importmap picks it up automatically**

```bash
grep -n 'pin_all_from "app/javascript/services"' config/importmap.rb
```

Expected: the line already exists (confirmed present before this plan was written) — no changes needed to `config/importmap.rb`. The module will be importable as `services/offline_sales_db`.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/services/offline_sales_db.js
git commit -m "feat: agrega helper IndexedDB para cola de ventas offline"
```

---

## Task 3: Offline-aware Sale form submit

**Files:**
- Create: `app/javascript/controllers/offline_sale_form_controller.js`
- Modify: `app/views/sales/_form.html.erb:3`

**Interfaces:**
- Consumes: `addPendingSale(entries)` from `services/offline_sales_db` (Task 2).
- Produces: nothing new consumed by later tasks directly, but writes records that Task 4 (list UI) and Task 5 (service worker sync) both read.

- [ ] **Step 1: Create the controller**

```js
// app/javascript/controllers/offline_sale_form_controller.js
import { Controller } from "@hotwired/stimulus";
import { addPendingSale } from "services/offline_sales_db";

// Connects to data-controller="offline-sale-form"
export default class extends Controller {
  async submit(event) {
    if (navigator.onLine) return; // let the normal Turbo submit go through

    event.preventDefault();

    const form = this.element;
    const entries = Array.from(new FormData(form).entries());

    await addPendingSale(entries);
    await this.registerBackgroundSync();
    this.showQueuedMessage();
  }

  async registerBackgroundSync() {
    if ("serviceWorker" in navigator && "SyncManager" in window) {
      const registration = await navigator.serviceWorker.ready;
      try {
        await registration.sync.register("sale-sync");
      } catch (e) {
        // Background Sync unavailable (e.g. iOS Safari) - the 'online'
        // event fallback registered in application.js handles this case.
      }
    }
  }

  showQueuedMessage() {
    const message = document.createElement("div");
    message.className = "fixed bottom-4 right-4 bg-gray-900 text-white text-sm px-4 py-2 rounded-lg shadow-lg z-50";
    message.textContent = "Venta guardada localmente. Se enviará cuando vuelva la conexión.";
    document.body.appendChild(message);
    setTimeout(() => message.remove(), 4000);
    Turbo.visit("/sales");
  }
}
```

- [ ] **Step 2: Verify syntax**

```bash
node --check app/javascript/controllers/offline_sale_form_controller.js
```

Expected: no output.

- [ ] **Step 3: Wire it into the form, only for new sales**

In `app/views/sales/_form.html.erb`, change line 3 from:

```erb
<%= styled_form_with model: sale, class: "space-y-6" do |f| %>
```

to:

```erb
<%= styled_form_with model: sale, class: "space-y-6", data: (sale.new_record? ? { controller: "offline-sale-form", action: "submit->offline-sale-form#submit" } : {}) do |f| %>
```

- [ ] **Step 4: Manual verification**

This can't be unit-tested without a browser (no JS test runner in this project — confirmed, only Minitest/Capybara system tests which need the full Rails env). Verify manually once deployed:

1. Open `/sales/new` in Chrome on desktop with DevTools open.
2. Network tab → toggle "Offline".
3. Fill the form (client name + at least one item) and submit.
4. Expected: no network error shown to the user, a dark toast message appears ("Venta guardada localmente...") and the page navigates to `/sales`.
5. Open DevTools → Application → IndexedDB → `financespy_offline` → `pending_sales` — confirm one record exists with `status: "pending"`.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/offline_sale_form_controller.js app/views/sales/_form.html.erb
git commit -m "feat: intercepta submit de nueva venta offline y encola en IndexedDB"
```

---

## Task 4: Pending sales list UI

**Files:**
- Create: `app/javascript/controllers/pending_sales_controller.js`
- Modify: `app/views/sales/index.html.erb:10-11` (insert before the existing `<div class="bg-container...">`)

**Interfaces:**
- Consumes: `getPendingSales()`, `deletePendingSale(id)`, `markNeedsReview(id, message)` from `services/offline_sales_db` (Task 2). The spec requires manual retry to be available from the pending-list UI for items that exhausted automatic retries — this task is where that gets wired in (Task 2 exports `deletePendingSale`/`markNeedsReview` specifically for this).

- [ ] **Step 1: Create the controller**

```js
// app/javascript/controllers/pending_sales_controller.js
import { Controller } from "@hotwired/stimulus";
import { getPendingSales, deletePendingSale, markNeedsReview } from "services/offline_sales_db";

// Connects to data-controller="pending-sales"
export default class extends Controller {
  static targets = ["container", "list"];

  connect() {
    this.render();
    this.listTarget.addEventListener("click", this.handleRetryClick.bind(this));
  }

  async render() {
    const pending = await getPendingSales();

    if (pending.length === 0) {
      this.containerTarget.classList.add("hidden");
      return;
    }

    this.containerTarget.classList.remove("hidden");
    this.listTarget.innerHTML = pending.map((sale) => this.renderRow(sale)).join("");
  }

  renderRow(sale) {
    const clientEntry = sale.formData.find(([key]) => key === "sale[client_name]");
    const clientName = clientEntry ? clientEntry[1] : "-";
    const needsReview = sale.status === "needs_review";
    const statusLabel = needsReview ? (sale.errorMessage || "Necesita revisión") : "Pendiente de sincronizar";
    const statusClass = needsReview ? "bg-red-100 text-red-800" : "bg-gray-100 text-gray-800";
    const retryButton = needsReview
      ? `<button type="button" data-retry-id="${sale.id}" class="text-xs font-medium text-primary underline ml-2">Reintentar</button>`
      : "";

    return `
      <div class="flex items-center justify-between px-4 py-3 border-b border-gray-100">
        <span class="text-sm text-primary">${clientName}</span>
        <span class="flex items-center">
          <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${statusClass}">${statusLabel}</span>
          ${retryButton}
        </span>
      </div>
    `;
  }

  async handleRetryClick(event) {
    const button = event.target.closest("[data-retry-id]");
    if (!button) return;

    const id = Number(button.dataset.retryId);
    const pending = await getPendingSales();
    const sale = pending.find((s) => s.id === id);
    if (!sale) return;

    const body = new FormData();
    sale.formData.forEach(([key, value]) => body.append(key, value));

    try {
      const response = await fetch("/sales", {
        method: "POST",
        body,
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      });

      if (response.ok) {
        await deletePendingSale(id);
      } else {
        const data = await response.json().catch(() => ({}));
        const message = (data.errors && data.errors.join(", ")) || "Falló el reintento manual";
        await markNeedsReview(id, message);
      }
    } catch (error) {
      await markNeedsReview(id, "Sin conexión — probá de nuevo");
    }

    this.render();
  }
}
```

- [ ] **Step 2: Verify syntax**

```bash
node --check app/javascript/controllers/pending_sales_controller.js
```

Expected: no output.

- [ ] **Step 3: Wire the container into the Sales index view**

In `app/views/sales/index.html.erb`, insert this block immediately before the existing `<div class="bg-container rounded-xl shadow-border-xs p-4">` on line 11:

```erb
<div data-controller="pending-sales" data-pending-sales-target="container" class="hidden bg-container rounded-xl shadow-border-xs p-4 mb-4">
  <h3 class="text-sm font-medium text-secondary uppercase tracking-wide mb-2">Ventas pendientes de sincronizar</h3>
  <div data-pending-sales-target="list"></div>
</div>
```

- [ ] **Step 4: Manual verification**

After Task 3's manual verification leaves a pending record in IndexedDB, reload `/sales` and confirm the new "Ventas pendientes de sincronizar" section appears showing the client name and a "Pendiente de sincronizar" badge (no "Reintentar" button yet — that only shows for `needs_review`).

To verify the manual retry path specifically: in DevTools console, force a record into `needs_review` directly against IndexedDB (e.g. open the pending sale's record via Application → IndexedDB and edit `status` to `"needs_review"`, or simpler — temporarily stop the Rails server so the retry's `fetch` fails, then reload `/sales`, confirm a "Reintentar" button appears, click it, confirm it attempts the POST (visible in the Network tab) and either clears the row (success) or updates the error message (still failing).

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/pending_sales_controller.js app/views/sales/index.html.erb
git commit -m "feat: muestra lista de ventas pendientes de sincronizar en /sales"
```

---

## Task 5: Service worker — runtime cache (read) + Background Sync (write replay)

**Files:**
- Modify: `app/views/pwa/service-worker.js` (full rewrite of fetch/cache logic, keeps existing install/activate structure and the commented-out push notification block)
- Modify: `app/javascript/application.js:44-51` (add `online` event fallback for browsers without Background Sync)

**Interfaces:**
- Consumes: the `pending_sales` IndexedDB store written by Task 2/3 (duplicated read/update/delete logic — see Global Constraints for why this isn't a shared import).
- Produces: nothing consumed by other tasks — this is the terminal piece of the write-queue pipeline.

- [ ] **Step 1: Replace the full contents of `app/views/pwa/service-worker.js`**

```js
const CACHE_VERSION = 'v3';
const RUNTIME_CACHE = 'runtime-v3';
const OFFLINE_ASSETS = [
  '/offline.html',
  '/logo-offline.svg'
];

// Install event - cache the offline page and assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => {
      return cache.addAll(OFFLINE_ASSETS);
    })
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_VERSION && cacheName !== RUNTIME_CACHE) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      return self.clients.claim();
    })
  );
});

// Fetch event:
// - Navigations (page loads): network-first, cache the response for offline
//   re-visits, fall back to the last cached copy (or the offline page) if
//   the network fails. Freshness matters more than instant-from-cache here
//   because this is financial data.
// - Static assets (/assets/*): cache-first, they're fingerprinted by
//   Propshaft so a cached copy is always the correct one.
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const clone = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => cache.put(event.request, clone));
          return response;
        })
        .catch(() => {
          return caches.match(event.request).then((cached) => {
            return cached || caches.match('/offline.html');
          });
        })
    );
    return;
  }

  if (url.pathname.startsWith('/assets/')) {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        if (cached) return cached;
        return fetch(event.request).then((response) => {
          const clone = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => cache.put(event.request, clone));
          return response;
        });
      })
    );
    return;
  }

  if (OFFLINE_ASSETS.some((asset) => url.pathname === asset)) {
    event.respondWith(
      caches.match(event.request).then((response) => response || fetch(event.request))
    );
  }
});

// --- Background Sync: replay queued offline Sale submissions ---
//
// This duplicates the small IndexedDB helper from
// app/javascript/services/offline_sales_db.js on purpose: this file is
// served as a classic (non-module) script by Rails' rails/pwa controller,
// so it cannot `import` that module. See the plan's Global Constraints.

const DB_NAME = 'financespy_offline';
const DB_VERSION = 1;
const STORE_NAME = 'pending_sales';
const MAX_ATTEMPTS = 5;

function openDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });
      }
    };
    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject(event.target.error);
  });
}

function getAllPending() {
  return openDb().then((db) => new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly');
    const store = tx.objectStore(STORE_NAME);
    const request = store.getAll();
    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject(event.target.error);
  }));
}

function deletePending(id) {
  return openDb().then((db) => new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const request = store.delete(id);
    request.onsuccess = () => resolve();
    request.onerror = (event) => reject(event.target.error);
  }));
}

function updatePending(record) {
  return openDb().then((db) => new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    const request = store.put(record);
    request.onsuccess = () => resolve();
    request.onerror = (event) => reject(event.target.error);
  }));
}

async function replayPendingSales() {
  const pending = await getAllPending();

  for (const sale of pending) {
    if (sale.status === 'needs_review') continue;

    const body = new FormData();
    sale.formData.forEach(([key, value]) => body.append(key, value));

    try {
      const response = await fetch('/sales', {
        method: 'POST',
        body,
        headers: { Accept: 'application/json' },
        credentials: 'same-origin'
      });

      if (response.ok) {
        await deletePending(sale.id);
      } else if (response.status === 422) {
        sale.status = 'needs_review';
        sale.errorMessage = 'Datos inválidos - revisar manualmente';
        await updatePending(sale);
      } else {
        sale.attempts = (sale.attempts || 0) + 1;
        if (sale.attempts >= MAX_ATTEMPTS) {
          sale.status = 'needs_review';
          sale.errorMessage = 'Falló tras varios intentos';
        }
        await updatePending(sale);
      }
    } catch (error) {
      sale.attempts = (sale.attempts || 0) + 1;
      if (sale.attempts >= MAX_ATTEMPTS) {
        sale.status = 'needs_review';
        sale.errorMessage = 'Sin conexión tras varios intentos';
      }
      await updatePending(sale);
    }
  }
}

self.addEventListener('sync', (event) => {
  if (event.tag === 'sale-sync') {
    event.waitUntil(replayPendingSales());
  }
});

// Manual trigger for browsers without Background Sync support (iOS Safari):
// application.js posts a message here on the 'online' event.
self.addEventListener('message', (event) => {
  if (event.data === 'replay-pending-sales') {
    event.waitUntil ? event.waitUntil(replayPendingSales()) : replayPendingSales();
  }
});

// Add a service worker for processing Web Push notifications:
//
// self.addEventListener("push", async (event) => {
//   const { title, options } = await event.data.json()
//   event.waitUntil(self.registration.showNotification(title, options))
// })
//
// self.addEventListener("notificationclick", function(event) {
//   event.notification.close()
//   event.waitUntil(
//     clients.matchAll({ type: "window" }).then((clientList) => {
//       for (let i = 0; i < clientList.length; i++) {
//         let client = clientList[i]
//         let clientPath = (new URL(client.url)).pathname
//
//         if (clientPath == event.notification.data.path && "focus" in client) {
//           return client.focus()
//         }
//       }
//
//       if (clients.openWindow) {
//         return clients.openWindow(event.notification.data.path)
//       }
//     })
//   )
// })
```

- [ ] **Step 2: Verify syntax**

```bash
node --check app/views/pwa/service-worker.js
```

Expected: no output. Note: this file has an `.erb`-free `.js` extension already (confirmed — it's plain JS, not `.js.erb`), so `node --check` works directly.

- [ ] **Step 3: Add the `online` fallback in `app/javascript/application.js`**

This is the last block in the file (lines 52-64). Replace it in full:

```js
// Register service worker for PWA offline support
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker')
      .then(registration => {
        console.log('Service Worker registered with scope:', registration.scope);
      })
      .catch(error => {
        console.log('Service Worker registration failed:', error);
      });
  });
}
```

with:

```js
// Register service worker for PWA offline support
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker')
      .then(registration => {
        console.log('Service Worker registered with scope:', registration.scope);
      })
      .catch(error => {
        console.log('Service Worker registration failed:', error);
      });
  });

  // Fallback for browsers without Background Sync (e.g. iOS Safari):
  // ask the service worker to replay any queued offline sales as soon as
  // connectivity returns.
  window.addEventListener('online', () => {
    navigator.serviceWorker.ready.then((registration) => {
      if (registration.active) {
        registration.active.postMessage('replay-pending-sales');
      }
    });
  });
}
```

- [ ] **Step 4: Manual end-to-end verification**

1. Deploy this task's changes.
2. In Chrome DevTools on a real or emulated mobile viewport: visit `/sales` and a couple of other pages online first (so they get cached).
3. Go offline (DevTools Network → Offline, or real airplane mode on a phone).
4. Reload one of the previously-visited pages — confirm it still renders (served from `RUNTIME_CACHE`), not the generic offline page.
5. Go to `/sales/new`, submit a sale offline (per Task 3's verification) — confirm it queues.
6. Go back online. In DevTools → Application → Service Workers, confirm a `sync` event fires (or manually trigger `online` if testing on a browser without Background Sync — e.g. simulate by toggling the Network throttling back to "No throttling" and reloading).
7. Confirm the pending sale disappears from the `/sales` "pendientes" list and a real `Sale` record now exists with a real, correctly-assigned `sale_number` (check via `bin/rails runner 'puts Sale.last.inspect'` on the deployed container).

- [ ] **Step 5: Commit**

```bash
git add app/views/pwa/service-worker.js app/javascript/application.js
git commit -m "feat: cache de lectura runtime + Background Sync para cola de ventas offline"
```

---

## Task 6: Deploy and verify on the real VM

**Files:** none (deployment + verification only)

- [ ] **Step 1: Push all commits**

```bash
git push origin main
```

- [ ] **Step 2: Pull and rebuild on the VM**

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="cd /home/Fabrizio/financespy && git pull origin main && docker compose -f compose.prod.yml up -d --build"
```

- [ ] **Step 3: Confirm containers are healthy**

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="docker ps --format 'table {{.Names}}\t{{.Status}}' | grep financespy"
```

Expected: `financespy-web-1` and `financespy-worker-1` both `Up` with a recent timestamp.

- [ ] **Step 4: Run the new JSON format test in the real container** (per Global Constraints — this is where it can actually run)

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="docker exec financespy-web-1 bin/rails test test/controllers/sales_controller_test.rb -n /json/ 2>&1"
```

Expected: PASS.

- [ ] **Step 5: Full end-to-end manual verification on a real phone**

Repeat Task 5 Step 4's manual verification, but on Fabrizio's actual phone against `https://finance.cd-co.com.py`, not just DevTools emulation — confirm the whole offline-create-sale-then-sync flow works on the real device this was built for.
