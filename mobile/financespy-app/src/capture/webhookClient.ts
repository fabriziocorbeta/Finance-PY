import { getWebhookToken } from '../storage/secureStorage';

const WEBHOOK_URL = 'https://finance.cd-co.com.py/webhooks/android_purchase';

export interface PurchasePayload {
  accountId: string;
  amount: string;
  merchant: string;
  item: string;
  rawText: string;
  capturedAt: string;
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
        timestamp: payload.capturedAt,
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
