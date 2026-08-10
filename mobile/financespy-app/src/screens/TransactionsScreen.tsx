import React, { useEffect, useState } from 'react';
import { View, Text, FlatList, ActivityIndicator, StyleSheet } from 'react-native';
import { useAuth } from '../auth/AuthContext';
import { fetchRecentTransactions, Transaction } from '../api/transactionsApi';

export function TransactionsScreen() {
  const { getValidAccessToken } = useAuth();
  const [transactions, setTransactions] = useState<Transaction[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const token = await getValidAccessToken();
      if (!token) {
        setError('Sesión vencida. Iniciá sesión de nuevo.');
        return;
      }
      try {
        const result = await fetchRecentTransactions(token);
        setTransactions(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error desconocido');
      }
    })();
  }, [getValidAccessToken]);

  if (error) return <View style={styles.container}><Text>{error}</Text></View>;
  if (!transactions) return <View style={styles.container}><ActivityIndicator /></View>;

  return (
    <FlatList
      data={transactions}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => (
        <View style={styles.row}>
          <Text>{item.date}</Text>
          <Text>{item.name} — {item.accountName}</Text>
          <Text>₲{item.amount}</Text>
        </View>
      )}
      ListEmptyComponent={<Text style={styles.empty}>Sin transacciones recientes.</Text>}
    />
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  row: { padding: 12, borderBottomWidth: 1, borderBottomColor: '#eee' },
  empty: { textAlign: 'center', marginTop: 32 },
});
