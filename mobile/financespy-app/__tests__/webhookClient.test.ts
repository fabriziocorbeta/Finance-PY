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
