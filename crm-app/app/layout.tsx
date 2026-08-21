import './globals.css';
import type { Metadata } from 'next';
import { DM_Sans } from 'next/font/google';
import { Toaster } from 'react-hot-toast';

const dmSans = DM_Sans({ subsets: ['latin'], variable: '--font-dm-sans', display: 'swap' });

export const metadata: Metadata = {
  title: 'CRM Social Hub',
  description: 'CRM + redes sociales con WhatsApp e Instagram/Facebook',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className={dmSans.variable}>
      <body className="font-sans antialiased">
        {children}
        <Toaster position="top-right" toastOptions={{ duration: 3500 }} />
      </body>
    </html>
  );
}
