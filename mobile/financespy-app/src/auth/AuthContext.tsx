import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { authorize, refresh } from 'react-native-app-auth';
import { AUTH_CONFIG } from './authConfig';
import { saveOAuthTokens, getOAuthTokens, clearOAuthTokens } from '../storage/secureStorage';

interface AuthContextValue {
  isAuthenticated: boolean;
  login: () => Promise<void>;
  logout: () => Promise<void>;
  getValidAccessToken: () => Promise<string | null>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    getOAuthTokens().then((tokens) => setIsAuthenticated(tokens !== null));
  }, []);

  async function login() {
    const result = await authorize(AUTH_CONFIG);
    await saveOAuthTokens({
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    });
    setIsAuthenticated(true);
  }

  async function logout() {
    await clearOAuthTokens();
    setIsAuthenticated(false);
  }

  async function getValidAccessToken(): Promise<string | null> {
    const tokens = await getOAuthTokens();
    if (!tokens) return null;

    try {
      const refreshed = await refresh(AUTH_CONFIG, { refreshToken: tokens.refreshToken });
      await saveOAuthTokens({
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? tokens.refreshToken,
      });
      return refreshed.accessToken;
    } catch {
      await clearOAuthTokens();
      setIsAuthenticated(false);
      return null;
    }
  }

  return (
    <AuthContext.Provider value={{ isAuthenticated, login, logout, getValidAccessToken }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}

// Note: this always refreshes on `getValidAccessToken()` rather than trying to cache-and-check
// expiry client-side — simpler and avoids clock-skew bugs, at the cost of one extra network
// round-trip per screen load. Acceptable for a low-frequency, single-screen MVP; revisit only if
// this becomes a real latency problem.
