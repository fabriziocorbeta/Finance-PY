import type { NextConfig } from 'next';

const config: NextConfig = {
  experimental: { typedRoutes: true },
  images: { remotePatterns: [{ protocol: 'https', hostname: '**.supabase.co' }] },
};

export default config;
