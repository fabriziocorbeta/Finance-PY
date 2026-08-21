import { type VercelConfig } from '@vercel/config/v1';

// Next.js auto-detectado por Vercel. Config explícita para claridad + futuro
// (F4: cron sync métricas sociales; F2: webhooks WhatsApp/Meta).
export const config: VercelConfig = {
  framework: 'nextjs',
  buildCommand: 'next build',
  // F4 placeholder — activar cuando exista /api/cron/sync-metrics
  // crons: [{ path: '/api/cron/sync-metrics', schedule: '0 6 * * *' }],
};
