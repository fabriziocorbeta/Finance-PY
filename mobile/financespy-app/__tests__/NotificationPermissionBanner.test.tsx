import React from 'react';
import { render, waitFor, fireEvent } from '@testing-library/react-native';
import { NativeModules } from 'react-native';
import { NotificationPermissionBanner } from '../src/components/NotificationPermissionBanner';

// NOTE: react-native 0.86's real module eagerly requires NativeDevMenu at
// import time, which throws under jest.requireActual('react-native') (no
// native TurboModule host available in the test env). Rather than mock the
// entire react-native module (brittle against RN's own internals), we patch
// NativeModules.NotificationListener directly — the only surface this
// component touches.
NativeModules.NotificationListener = {
  isPermissionGranted: jest.fn(),
  openNotificationAccessSettings: jest.fn(),
};

describe('NotificationPermissionBanner', () => {
  it('renders nothing when permission is already granted', async () => {
    (NativeModules.NotificationListener.isPermissionGranted as jest.Mock).mockResolvedValue(true);
    const { queryByText } = await render(<NotificationPermissionBanner />);
    await waitFor(() => expect(queryByText(/Activar acceso/)).toBeNull());
  });

  it('shows a call-to-action when permission is not granted, and opens settings on tap', async () => {
    (NativeModules.NotificationListener.isPermissionGranted as jest.Mock).mockResolvedValue(false);
    const { findByText } = await render(<NotificationPermissionBanner />);
    const button = await findByText(/Activar acceso/);
    fireEvent.press(button);
    expect(NativeModules.NotificationListener.openNotificationAccessSettings).toHaveBeenCalled();
  });
});
