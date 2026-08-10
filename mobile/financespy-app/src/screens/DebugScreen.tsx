import React, { useState } from 'react';
import { View, Text, Pressable, StyleSheet, TextInput } from 'react-native';
import { handleWalletNotification } from '../capture/captureController';
import { saveWebhookToken } from '../storage/secureStorage';

const SAMPLE_EVENT = {
  packageName: 'com.google.android.apps.walletnfcrel',
  title: '#A EUSTAQUI-PLAZA MADE',
  text: 'PYG112,000 con GNB GOOGLE ••6536',
};

export function DebugScreen() {
  const [tokenInput, setTokenInput] = useState('');
  const [saveMessage, setSaveMessage] = useState<string | null>(null);

  const handleSaveToken = async () => {
    try {
      await saveWebhookToken(tokenInput);
      setSaveMessage('Token guardado correctamente.');
    } catch {
      setSaveMessage('No se pudo guardar el token.');
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Diagnóstico</Text>

      <Text style={styles.label}>Token del webhook</Text>
      <TextInput
        style={styles.input}
        value={tokenInput}
        onChangeText={setTokenInput}
        secureTextEntry
        placeholder="Bearer token"
        autoCapitalize="none"
        autoCorrect={false}
      />
      <Pressable style={styles.button} onPress={handleSaveToken}>
        <Text style={styles.buttonText}>Guardar token del webhook</Text>
      </Pressable>
      {saveMessage ? <Text style={styles.hint}>{saveMessage}</Text> : null}

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
  label: { fontSize: 12, color: '#666', marginBottom: 4 },
  input: {
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 6,
    padding: 8,
    marginBottom: 8,
  },
  button: { backgroundColor: '#0066cc', padding: 12, borderRadius: 6, marginBottom: 8 },
  buttonText: { color: '#fff', textAlign: 'center' },
  hint: { color: '#666', fontSize: 12, marginBottom: 12 },
});
