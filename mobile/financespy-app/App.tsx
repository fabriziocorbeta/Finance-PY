/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { useEffect, useState } from 'react';
import type { EmitterSubscription } from 'react-native';
import {
  Button,
  DeviceEventEmitter,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import notifee from '@notifee/react-native';
import { handleWalletNotification, WALLET_CAPTURE_CHANNEL_ID } from './src/capture/captureController';
import { AuthProvider, useAuth } from './src/auth/AuthContext';
import { TransactionsScreen } from './src/screens/TransactionsScreen';
import { DebugScreen } from './src/screens/DebugScreen';
import { NotificationPermissionBanner } from './src/components/NotificationPermissionBanner';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  useEffect(() => {
    let subscription: EmitterSubscription | undefined;

    (async () => {
      await notifee.createChannel({ id: WALLET_CAPTURE_CHANNEL_ID, name: 'Captura de gastos' });
      await notifee.requestPermission();
      subscription = DeviceEventEmitter.addListener(
        'WalletNotificationReceived',
        handleWalletNotification
      );
    })();

    return () => subscription?.remove();
  }, []);

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AuthProvider>
        <AppContent />
      </AuthProvider>
    </SafeAreaProvider>
  );
}

function AppContent() {
  const { isAuthenticated, login } = useAuth();
  const [showDebug, setShowDebug] = useState(false);

  return (
    <View style={styles.container}>
      <NotificationPermissionBanner />
      {isAuthenticated ? (
        <>
          {showDebug ? <DebugScreen /> : <TransactionsScreen />}
          <Button
            title={showDebug ? 'Volver a transacciones' : 'Diagnóstico'}
            onPress={() => setShowDebug((prev) => !prev)}
          />
        </>
      ) : (
        <View style={styles.loginContainer}>
          <Text style={styles.title}>FinancePY</Text>
          <Button title="Iniciar sesión" onPress={login} />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  loginContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 16,
  },
});

export default App;
