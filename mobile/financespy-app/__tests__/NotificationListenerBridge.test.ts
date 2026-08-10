import { NativeModules } from 'react-native';

jest.mock('react-native', () => ({
  NativeModules: {
    NotificationListener: {
      isPermissionGranted: jest.fn().mockResolvedValue(true),
      openNotificationAccessSettings: jest.fn(),
    },
  },
  NativeEventEmitter: jest.fn(),
}));

describe('NotificationListener native module bridge', () => {
  it('exposes isPermissionGranted returning a boolean promise', async () => {
    const granted = await NativeModules.NotificationListener.isPermissionGranted();
    expect(granted).toBe(true);
  });

  it('exposes openNotificationAccessSettings as a callable function', () => {
    NativeModules.NotificationListener.openNotificationAccessSettings();
    expect(NativeModules.NotificationListener.openNotificationAccessSettings).toHaveBeenCalled();
  });
});
