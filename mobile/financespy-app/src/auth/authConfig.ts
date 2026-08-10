import { AuthConfiguration } from 'react-native-app-auth';

export const AUTH_CONFIG: AuthConfiguration = {
  issuer: 'https://finance.cd-co.com.py',
  serviceConfiguration: {
    authorizationEndpoint: 'https://finance.cd-co.com.py/oauth/authorize',
    tokenEndpoint: 'https://finance.cd-co.com.py/oauth/token',
  },
  clientId: 'financespy-mobile-app',
  redirectUrl: 'financespy://oauth/callback',
  scopes: ['read_write'],
  usePKCE: true,
};

// Note: `clientId` here (`financespy-mobile-app`) is a placeholder value that must be replaced
// with the real `uid` Doorkeeper generated for the `"FinancePY Mobile"` application created in
// Task 7 — retrieve it with `Doorkeeper::Application.find_by(name: "FinancePY Mobile").uid` in a
// Rails console against the same environment this app will authenticate against, and hardcode the
// real value here before this is usable end-to-end. This is not a "TBD" left for later — it is a
// concrete, mechanical value substitution documented so the implementer doesn't skip it silently.
