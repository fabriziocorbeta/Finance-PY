import * as Keychain from 'react-native-keychain';

const WEBHOOK_TOKEN_SERVICE = 'financespy.webhookToken';
const OAUTH_TOKENS_SERVICE = 'financespy.oauthTokens';

export async function saveWebhookToken(token: string): Promise<void> {
  await Keychain.setGenericPassword('webhook-token', token, {
    service: WEBHOOK_TOKEN_SERVICE,
  });
}

export async function getWebhookToken(): Promise<string | null> {
  const result = await Keychain.getGenericPassword({ service: WEBHOOK_TOKEN_SERVICE });
  return result ? result.password : null;
}

export interface OAuthTokens {
  accessToken: string;
  refreshToken: string;
}

export async function saveOAuthTokens(tokens: OAuthTokens): Promise<void> {
  await Keychain.setGenericPassword('oauth-tokens', JSON.stringify(tokens), {
    service: OAUTH_TOKENS_SERVICE,
  });
}

export async function getOAuthTokens(): Promise<OAuthTokens | null> {
  const result = await Keychain.getGenericPassword({ service: OAUTH_TOKENS_SERVICE });
  return result ? (JSON.parse(result.password) as OAuthTokens) : null;
}

export async function clearOAuthTokens(): Promise<void> {
  await Keychain.resetGenericPassword({ service: OAUTH_TOKENS_SERVICE });
}
