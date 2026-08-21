'use client';
import { useEffect } from 'react';

export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => { console.error(error); }, [error]);
  return (
    <div className="min-h-[60vh] flex flex-col items-center justify-center gap-3 text-center">
      <p className="text-lg font-semibold text-text1">Algo salió mal</p>
      <p className="text-sm text-text3 max-w-md">{error.message || 'Error inesperado. Reintenta.'}</p>
      <button onClick={reset} className="mt-2 h-9 px-4 rounded-lg bg-brand-gradient text-white text-sm font-medium shadow-primary">
        Reintentar
      </button>
    </div>
  );
}
