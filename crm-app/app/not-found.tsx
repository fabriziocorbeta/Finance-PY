import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="min-h-dvh flex flex-col items-center justify-center bg-bg gap-3 text-center px-4">
      <p className="text-5xl font-bold text-text3 tabular">404</p>
      <p className="text-text2">Página no encontrada</p>
      <Link href="/dashboard" className="mt-2 h-9 px-4 rounded-lg bg-brand-gradient text-white text-sm font-medium flex items-center shadow-primary">
        Volver al dashboard
      </Link>
    </div>
  );
}
