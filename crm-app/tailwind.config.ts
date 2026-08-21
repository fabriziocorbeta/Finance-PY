import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg:        'rgb(var(--bg) / <alpha-value>)',
        surface:   'rgb(var(--surface) / <alpha-value>)',
        surface2:  'rgb(var(--surface-2) / <alpha-value>)',
        border:    'rgb(var(--border) / <alpha-value>)',
        text1:     'rgb(var(--text-1) / <alpha-value>)',
        text2:     'rgb(var(--text-2) / <alpha-value>)',
        text3:     'rgb(var(--text-3) / <alpha-value>)',
        primary:   '#4F46E5',
        secondary: '#7C3AED',
        success:   '#10B981',
        warning:   '#D97706',
        danger:    '#DC2626',
        whatsapp:  '#25D366',
        instagram: '#E1306C',
        facebook:  '#1877F2',
      },
      fontFamily: { sans: ['var(--font-dm-sans)', 'system-ui', 'sans-serif'] },
      boxShadow: {
        card:    '0 1px 3px rgba(15,23,42,.04), 0 4px 14px rgba(79,70,229,.06)',
        primary: '0 8px 24px rgba(79,70,229,.18)',
      },
      borderRadius: { card: '12px' },
      backgroundImage: { 'brand-gradient': 'linear-gradient(135deg,#4F46E5,#7C3AED)' },
    },
  },
  plugins: [],
};
export default config;
