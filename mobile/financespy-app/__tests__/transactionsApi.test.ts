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
