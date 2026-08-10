import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY = 'financespy.pendingCaptures';

export interface PendingCapture {
  id: string;
  capturedAt: string;
  rawText: string;
  accountId: string;
  amount: string;
  merchant: string;
  item: string;
}

async function readAll(): Promise<PendingCapture[]> {
  const raw = await AsyncStorage.getItem(STORAGE_KEY);
  return raw ? (JSON.parse(raw) as PendingCapture[]) : [];
}

async function writeAll(captures: PendingCapture[]): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(captures));
}

export async function addPendingCapture(entry: PendingCapture): Promise<void> {
  const current = await readAll();
  await writeAll([...current, entry]);
}

export async function getPendingCaptures(): Promise<PendingCapture[]> {
  return readAll();
}

export async function removePendingCapture(id: string): Promise<void> {
  const current = await readAll();
  await writeAll(current.filter((c) => c.id !== id));
}
