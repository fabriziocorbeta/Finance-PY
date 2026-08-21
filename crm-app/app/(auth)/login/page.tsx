'use client';
import { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import toast from 'react-hot-toast';

export default function LoginPage() {
  const router = useRouter();
  const next = useSearchParams().get('next') ?? '/dashboard';
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) { toast.error(error.message); return; }
    router.push(next);
    router.refresh();
  }

  async function onMagicLink() {
    if (!email) { toast.error('Ingresa tu email'); return; }
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: `${location.origin}/auth/callback?next=${encodeURIComponent(next)}` },
    });
    setLoading(false);
    if (error) toast.error(error.message);
    else toast.success('Revisa tu email');
  }

  return (
    <div className="min-h-dvh flex items-center justify-center bg-bg px-4">
      <div className="w-full max-w-md">
        <div className="flex items-center gap-3 mb-8 justify-center">
          <div className="w-10 h-10 rounded-xl bg-brand-gradient flex items-center justify-center text-white font-bold">N</div>
          <span className="text-xl font-bold text-text1">Nexus CRM</span>
        </div>

        <form onSubmit={onSubmit} className="bg-surface border border-border rounded-card shadow-card p-6 space-y-4">
          <h1 className="text-lg font-semibold text-text1">Inicia sesión</h1>

          <label className="block">
            <span className="text-xs font-medium text-text2 mb-1.5 block">Email</span>
            <input
              type="email" required value={email} onChange={e => setEmail(e.target.value)}
              autoComplete="email"
              className="w-full h-11 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm"
              placeholder="tu@empresa.com"
            />
          </label>

          <label className="block">
            <span className="text-xs font-medium text-text2 mb-1.5 block">Contraseña</span>
            <input
              type="password" required value={password} onChange={e => setPassword(e.target.value)}
              autoComplete="current-password"
              className="w-full h-11 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm"
            />
          </label>

          <button
            type="submit" disabled={loading}
            className="w-full h-11 rounded-lg bg-brand-gradient text-white font-medium shadow-primary disabled:opacity-60"
          >
            {loading ? 'Entrando…' : 'Entrar'}
          </button>

          <div className="flex items-center gap-3 text-xs text-text3">
            <span className="flex-1 h-px bg-border" /> o <span className="flex-1 h-px bg-border" />
          </div>

          <button
            type="button" onClick={onMagicLink} disabled={loading}
            className="w-full h-11 rounded-lg border border-border bg-surface hover:bg-surface2 text-sm font-medium text-text1"
          >
            Enviar magic link
          </button>
        </form>

        <p className="text-xs text-text3 text-center mt-4">
          Fase 1 — CRM Núcleo. WhatsApp + Meta llegan en Fase 2/3.
        </p>
      </div>
    </div>
  );
}
