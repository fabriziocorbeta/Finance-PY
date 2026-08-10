import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  addPendingCapture,
  getPendingCaptures,
  removePendingCapture,
  PendingCapture,
} from '../src/capture/pendingQueue';

jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock')
);

const sampleCapture: PendingCapture = {
  id: 'capture-1',
  capturedAt: '2026-08-10T10:00:00.000Z',
  rawText: 'PYG112,000 con GNB GOOGLE ••6536',
  accountId: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
  amount: '112,000',
  merchant: 'GNB GOOGLE ••6536',
  item: 'Google Wallet',
};

describe('pendingQueue', () => {
  beforeEach(async () => {
    await AsyncStorage.clear();
  });

  it('starts empty', async () => {
    expect(await getPendingCaptures()).toEqual([]);
  });

  it('adds a pending capture and retrieves it', async () => {
    await addPendingCapture(sampleCapture);
    expect(await getPendingCaptures()).toEqual([sampleCapture]);
  });

  it('accumulates multiple pending captures', async () => {
    await addPendingCapture(sampleCapture);
    await addPendingCapture({ ...sampleCapture, id: 'capture-2' });
    const all = await getPendingCaptures();
    expect(all).toHaveLength(2);
  });

  it('removes a pending capture by id', async () => {
    await addPendingCapture(sampleCapture);
    await addPendingCapture({ ...sampleCapture, id: 'capture-2' });
    await removePendingCapture('capture-1');
    const remaining = await getPendingCaptures();
    expect(remaining).toEqual([{ ...sampleCapture, id: 'capture-2' }]);
  });
});
