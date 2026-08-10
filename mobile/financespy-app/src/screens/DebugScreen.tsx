import React from 'react';
import { View, Text, Pressable, StyleSheet } from 'react-native';
import { handleWalletNotification } from '../capture/captureController';

const SAMPLE_EVENT = {
  packageName: 'com.google.android.apps.walletnfcrel',
  title: '#A EUSTAQUI-PLAZA MADE',
  text: 'PYG112,000 con GNB GOOGLE ••6536',
};

export function DebugScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Diagnóstico</Text>
      <Pressable style={styles.button} onPress={() => handleWalletNotification(SAMPLE_EVENT)}>
        <Text style={styles.buttonText}>Simular notificación de Wallet</Text>
      </Pressable>
      <Text style={styles.hint}>
        Dispara el pipeline completo (extracción → mapeo → webhook) con datos de prueba,
        sin esperar una compra real.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  title: { fontSize: 18, fontWeight: 'bold', marginBottom: 12 },
  button: { backgroundColor: '#0066cc', padding: 12, borderRadius: 6, marginBottom: 8 },
  buttonText: { color: '#fff', textAlign: 'center' },
  hint: { color: '#666', fontSize: 12 },
});
