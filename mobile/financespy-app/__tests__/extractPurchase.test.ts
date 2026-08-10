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
