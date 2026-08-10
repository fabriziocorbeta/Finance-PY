const PURCHASE_PATTERN = /PYG([\d,]+) con (.+)/;

export function extractPurchase(
  notificationText: string
): { amount: string; cardText: string } | null {
  const match = notificationText.match(PURCHASE_PATTERN);
  if (!match) return null;

  const [, amount, cardText] = match;
  return { amount, cardText: cardText.trim() };
}
