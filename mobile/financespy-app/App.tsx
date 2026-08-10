/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { useEffect } from 'react';
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
import { handleWalletNotification } from './src/capture/captureController';
import { AuthProvider, useAuth } from './src/auth/AuthContext';
import { TransactionsScreen } from './src/screens/TransactionsScreen';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  useEffect(() => {
    const subscription = DeviceEventEmitter.addListener(
      'WalletNotificationReceived',
      handleWalletNotification
    );
    return () => subscription.remove();
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

  return (
    <View style={styles.container}>
      {isAuthenticated ? (
        <TransactionsScreen />
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
