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
