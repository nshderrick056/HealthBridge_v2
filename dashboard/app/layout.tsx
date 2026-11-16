import type { Metadata } from 'next';
import localFont from 'next/font/local';
import type { ReactNode } from 'react';
import './globals.css';

// The same Outfit files the app bundles (OFL, app/fonts/Outfit-LICENSE.txt); no request to Google.
const outfit = localFont({
  src: [
    { path: './fonts/Outfit-Regular.ttf', weight: '400' },
    { path: './fonts/Outfit-Medium.ttf', weight: '500' },
    { path: './fonts/Outfit-SemiBold.ttf', weight: '600' },
    { path: './fonts/Outfit-Bold.ttf', weight: '700' },
  ],
  variable: '--font-outfit',
  display: 'swap',
});

export const metadata: Metadata = {
  title: { default: 'HealthBridge supervisor', template: '%s · HealthBridge' },
  description: 'Urgent alert inbox for health centre supervisors',
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={outfit.variable}>
      <body className="min-h-screen font-sans antialiased">{children}</body>
    </html>
  );
}
