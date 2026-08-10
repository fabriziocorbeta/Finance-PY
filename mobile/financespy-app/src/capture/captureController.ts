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
