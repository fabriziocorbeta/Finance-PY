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
