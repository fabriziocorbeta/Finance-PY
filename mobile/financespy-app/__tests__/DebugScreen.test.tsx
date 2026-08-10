import React from 'react';
import { render, fireEvent, waitFor } from '@testing-library/react-native';
import { DebugScreen } from '../src/screens/DebugScreen';
import { saveWebhookToken } from '../src/storage/secureStorage';

jest.mock('../src/storage/secureStorage', () => ({
  saveWebhookToken: jest.fn(),
}));

jest.mock('../src/capture/captureController', () => ({
  handleWalletNotification: jest.fn().mockResolvedValue(undefined),
}));

describe('DebugScreen', () => {
  beforeEach(() => jest.clearAllMocks());

  it('calls saveWebhookToken with the entered value when the save button is pressed', async () => {
    (saveWebhookToken as jest.Mock).mockResolvedValue(undefined);

    const { getByPlaceholderText, getByText } = await render(<DebugScreen />);

    fireEvent.changeText(getByPlaceholderText('Bearer token'), 'my-secret-token');

    await waitFor(() => {
      expect(getByPlaceholderText('Bearer token').props.value).toBe('my-secret-token');
    });

    fireEvent.press(getByText('Guardar token del webhook'));

    await waitFor(() => {
      expect(saveWebhookToken).toHaveBeenCalledWith('my-secret-token');
    });
  });

  it('shows a failure message when saving the token throws', async () => {
    (saveWebhookToken as jest.Mock).mockRejectedValue(new Error('keychain error'));

    const { getByPlaceholderText, getByText, findByText } = await render(<DebugScreen />);

    fireEvent.changeText(getByPlaceholderText('Bearer token'), 'my-secret-token');

    await waitFor(() => {
      expect(getByPlaceholderText('Bearer token').props.value).toBe('my-secret-token');
    });

    fireEvent.press(getByText('Guardar token del webhook'));

    await findByText('No se pudo guardar el token.');
  });
});
