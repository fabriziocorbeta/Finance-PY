import { AuthConfiguration } from 'react-native-app-auth';

export const AUTH_CONFIG: AuthConfiguration = {
  issuer: 'https://finance.cd-co.com.py',
  serviceConfiguration: {
    authorizationEndpoint: 'https://finance.cd-co.com.py/oauth/authorize',
    tokenEndpoint: 'https://finance.cd-co.com.py/oauth/token',
  },
  clientId: 'Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM',
  redirectUrl: 'financespy://oauth/callback',
  scopes: ['read_write'],
  usePKCE: true,
};

// Real Doorkeeper uid for the "FinancePY Mobile" application, retrieved from production
// (finance.cd-co.com.py, seeded via db/seeds/oauth_applications.rb) on 2026-08-10.
// If this app is ever re-seeded against a different environment (a fresh DB, a different
// deploy), re-fetch with:
//   Doorkeeper::Application.find_by(name: "FinancePY Mobile").uid
