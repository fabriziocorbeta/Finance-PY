import * as Keychain from 'react-native-keychain';
import {
  saveWebhookToken,
  getWebhookToken,
  saveOAuthTokens,
  getOAuthTokens,
  clearOAuthTokens,
} from '../src/storage/secureStorage';

jest.mock('react-native-keychain', () => ({
  setGenericPassword: jest.fn().mockResolvedValue(true),
  getGenericPassword: jest.fn(),
  resetGenericPassword: jest.fn().mockResolvedValue(true),
}));

describe('secureStorage', () => {
  afterEach(() => jest.clearAllMocks());

  it('saves the webhook token under its own keychain service', async () => {
    await saveWebhookToken('abc123');
    expect(Keychain.setGenericPassword).toHaveBeenCalledWith(
      'webhook-token',
      'abc123',
      { service: 'financespy.webhookToken' }
    );
  });

  it('retrieves a saved webhook token', async () => {
    (Keychain.getGenericPassword as jest.Mock).mockResolvedValue({
      username: 'webhook-token',
      password: 'abc123',
    });
    const token = await getWebhookToken();
    expect(token).toBe('abc123');
  });

  it('returns null when no webhook token is stored', async () => {
    (Keychain.getGenericPassword as jest.Mock).mockResolvedValue(false);
    const token = await getWebhookToken();
    expect(token).toBeNull();
  });

  it('saves and retrieves OAuth tokens as JSON under their own service', async () => {
    await saveOAuthTokens({ accessToken: 'at', refreshToken: 'rt' });
    expect(Keychain.setGenericPassword).toHaveBeenCalledWith(
      'oauth-tokens',
      JSON.stringify({ accessToken: 'at', refreshToken: 'rt' }),
      { service: 'financespy.oauthTokens' }
    );

    (Keychain.getGenericPassword as jest.Mock).mockResolvedValue({
      username: 'oauth-tokens',
      password: JSON.stringify({ accessToken: 'at', refreshToken: 'rt' }),
    });
    const tokens = await getOAuthTokens();
    expect(tokens).toEqual({ accessToken: 'at', refreshToken: 'rt' });
  });

  it('clears OAuth tokens', async () => {
    await clearOAuthTokens();
    expect(Keychain.resetGenericPassword).toHaveBeenCalledWith({
      service: 'financespy.oauthTokens',
    });
  });
});
