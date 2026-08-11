import { AUTH_CONFIG } from '../src/auth/authConfig';

describe('AUTH_CONFIG', () => {
  it('points at the FinancePY OAuth endpoints with PKCE and the renamed redirect scheme', () => {
    expect(AUTH_CONFIG).toEqual({
      issuer: 'https://finance.cd-co.com.py',
      serviceConfiguration: {
        authorizationEndpoint: 'https://finance.cd-co.com.py/oauth/authorize',
        tokenEndpoint: 'https://finance.cd-co.com.py/oauth/token',
      },
      clientId: 'Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM',
      redirectUrl: 'financespy://oauth/callback',
      scopes: ['read_write'],
      usePKCE: true,
    });
  });
});
