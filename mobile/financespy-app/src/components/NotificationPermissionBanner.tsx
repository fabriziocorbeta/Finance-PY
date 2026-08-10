import React, { useEffect, useState } from 'react';
import { View, Text, Pressable, StyleSheet, NativeModules } from 'react-native';

export function NotificationPermissionBanner() {
  const [granted, setGranted] = useState<boolean | null>(null);

  useEffect(() => {
    NativeModules.NotificationListener.isPermissionGranted().then(setGranted);
  }, []);

  if (granted !== false) return null;

  return (
    <View style={styles.banner}>
      <Text style={styles.text}>
        La captura automática de gastos de Google Wallet está desactivada.
      </Text>
      <Pressable
        style={styles.button}
        onPress={() => NativeModules.NotificationListener.openNotificationAccessSettings()}
      >
        <Text style={styles.buttonText}>Activar acceso a notificaciones</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  banner: { backgroundColor: '#fff3cd', padding: 12 },
  text: { marginBottom: 8 },
  button: { alignSelf: 'flex-start' },
  buttonText: { color: '#0066cc', fontWeight: 'bold' },
});
