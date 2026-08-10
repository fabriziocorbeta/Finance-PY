import notifee from '@notifee/react-native';
import { extractPurchase } from './extractPurchase';
import { mapCardToAccountId } from './accountMapping';
import { postPurchaseToWebhook } from './webhookClient';
import { addPendingCapture } from './pendingQueue';

export const WALLET_CAPTURE_CHANNEL_ID = 'wallet-capture';

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
  const capturedAt = new Date().toISOString();

  if (!accountId) {
    await notifee.displayNotification({
      title: `Tarjeta no reconocida: ${cardText}`,
      body: 'No se registró ningún gasto automáticamente.',
      android: { channelId: WALLET_CAPTURE_CHANNEL_ID },
    });
    return;
  }

  const result = await postPurchaseToWebhook({
    accountId,
    amount,
    merchant: event.title,
    item: cardText,
    rawText: event.text,
    capturedAt,
  });

  if (result === 'created') {
    await notifee.displayNotification({
      title: `₲${amount} registrado`,
      body: `Cuenta: ${cardText}`,
      android: { channelId: WALLET_CAPTURE_CHANNEL_ID },
    });
    return;
  }

  if (result === 'duplicate') {
    await notifee.displayNotification({
      title: 'Esta compra ya estaba registrada',
      body: `₲${amount} — ${cardText}`,
      android: { channelId: WALLET_CAPTURE_CHANNEL_ID },
    });
    return;
  }

  await addPendingCapture({
    id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
    capturedAt,
    rawText: event.text,
    accountId,
    amount,
    merchant: event.title,
    item: cardText,
  });

  await notifee.displayNotification({
    title: 'No se pudo registrar el gasto automáticamente',
    body: `${result.error} — guardado para reintentar desde la app.`,
    android: { channelId: WALLET_CAPTURE_CHANNEL_ID },
  });
}
