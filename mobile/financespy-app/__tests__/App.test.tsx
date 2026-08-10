/**
 * @format
 */

import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import App from '../App';

jest.mock('@notifee/react-native', () => ({
  displayNotification: jest.fn().mockResolvedValue(undefined),
  createChannel: jest.fn().mockResolvedValue('wallet-capture'),
  requestPermission: jest.fn().mockResolvedValue(undefined),
}));

test('renders correctly', async () => {
  await ReactTestRenderer.act(() => {
    ReactTestRenderer.create(<App />);
  });
});
