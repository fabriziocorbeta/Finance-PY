import notifee from '@notifee/react-native';
import { handleWalletNotification } from '../src/capture/captureController';
import { postPurchaseToWebhook } from '../src/capture/webhookClient';
import { addPendingCapture } from '../src/capture/pendingQueue';

jest.mock('@notifee/react-native', () => ({
  displayNotification: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../src/capture/webhookClient');
jest.mock('../src/capture/pendingQueue');

const realNotification = {
  packageName: 'com.google.android.apps.walletnfcrel',
  title: '#A EUSTAQUI-PLAZA MADE',
  text: 'PYG112,000 con GNB GOOGLE ••6536',
};

describe('handleWalletNotification', () => {
  beforeEach(() => jest.clearAllMocks());

  it('posts to the webhook and shows a success notification when extraction and mapping succeed', async () => {
    (postPurchaseToWebhook as jest.Mock).mockResolvedValue('created');

    await handleWalletNotification(realNotification);

    expect(postPurchaseToWebhook).toHaveBeenCalledWith({
      accountId: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
      amount: '112,000',
      merchant: 'GNB GOOGLE ••6536',
      item: '#A EUSTAQUI-PLAZA MADE',
      rawText: 'PYG112,000 con GNB GOOGLE ••6536',
    });
    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({
        title: expect.stringContaining('registrado'),
      })
    );
  });

  it('treats a duplicate response as success, no error notification', async () => {
    (postPurchaseToWebhook as jest.Mock).mockResolvedValue('duplicate');

    await handleWalletNotification(realNotification);

    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({ title: expect.stringContaining('ya estaba registrad') })
    );
  });

  it('shows an unrecognized-card notification and never calls the webhook when the card does not match', async () => {
    await handleWalletNotification({
      ...realNotification,
      text: 'PYG50,000 con Banco Desconocido ••9999',
    });

    expect(postPurchaseToWebhook).not.toHaveBeenCalled();
    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({ title: expect.stringContaining('no reconocida') })
    );
  });

  it('does nothing when the notification text does not match the expected purchase format', async () => {
    await handleWalletNotification({ ...realNotification, text: 'Unrelated text' });

    expect(postPurchaseToWebhook).not.toHaveBeenCalled();
    expect(notifee.displayNotification).not.toHaveBeenCalled();
  });

  it('queues a pending capture and shows an error notification when the webhook call fails', async () => {
    (postPurchaseToWebhook as jest.Mock).mockResolvedValue({ error: 'Network request failed' });

    await handleWalletNotification(realNotification);

    expect(addPendingCapture).toHaveBeenCalledWith(
      expect.objectContaining({
        rawText: 'PYG112,000 con GNB GOOGLE ••6536',
        accountId: '43d84b14-b3be-44a9-be37-7ec1ae4661f2',
      })
    );
    expect(notifee.displayNotification).toHaveBeenCalledWith(
      expect.objectContaining({ title: expect.stringContaining('pudo registrar') })
    );
  });
});
