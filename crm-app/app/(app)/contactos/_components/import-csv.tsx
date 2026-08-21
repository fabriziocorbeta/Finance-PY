'use client';
import { useState, useTransition, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Upload, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { importContacts } from '../actions';

const SAMPLE = 'full_name,email,phone,whatsapp,company,status,source\nJuan Pérez,juan@acme.com,021555000,595981111111,Acme SA,lead,referral';

export function ImportCsvButton() {
  const [open, setOpen] = useState(false);
  const [csv, setCsv] = useState('');
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const fileRef = useRef<HTMLInputElement>(null);

  function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => setCsv(String(reader.result ?? ''));
    reader.readAsText(f);
  }

  function submit() {
    const fd = new FormData();
    fd.set('csv', csv);
    startTransition(async () => {
      const res = await importContacts(fd);
      if (res?.error) { toast.error(res.error); return; }
      toast.success(`${res.imported} importados${res.skipped ? `, ${res.skipped} omitidos` : ''}`);
      setOpen(false); setCsv('');
      router.refresh();
    });
  }

  return (
    <>
      <button onClick={() => setOpen(true)}
        className="h-9 px-3 rounded-lg border border-border bg-surface text-sm font-medium text-text1 flex items-center gap-1.5 hover:bg-surface2">
        <Upload size={14} /> Importar CSV
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4" role="dialog" aria-modal="true">
          <div className="bg-surface rounded-card shadow-card border border-border w-full max-w-lg">
            <div className="px-5 py-4 border-b border-border flex items-center justify-between">
              <h2 className="font-semibold text-text1">Importar contactos (CSV)</h2>
              <button onClick={() => setOpen(false)} className="p-1.5 rounded hover:bg-surface2 text-text2" aria-label="Cerrar"><X size={16} /></button>
            </div>
            <div className="p-5 space-y-3">
              <p className="text-xs text-text3">
                Header requerido: <code className="bg-surface2 px-1 rounded">full_name</code>.
                Opcionales: email, phone, whatsapp, company, status, source.
              </p>
              <input ref={fileRef} type="file" accept=".csv,text/csv" onChange={onFile}
                className="block w-full text-sm text-text2 file:mr-3 file:h-9 file:px-3 file:rounded-lg file:border-0 file:bg-surface2 file:text-text1 file:text-sm" />
              <textarea
                value={csv} onChange={e => setCsv(e.target.value)} rows={7}
                placeholder={SAMPLE}
                className="w-full px-3 py-2 rounded-lg bg-surface2 border border-border text-xs font-mono focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none resize-y" />
              <div className="flex gap-2">
                <button onClick={() => setCsv(SAMPLE)} className="text-xs text-primary hover:underline">Usar ejemplo</button>
              </div>
              <div className="flex gap-2 pt-1">
                <button onClick={() => setOpen(false)} className="flex-1 h-10 rounded-lg border border-border bg-surface text-text1 text-sm font-medium hover:bg-surface2">Cancelar</button>
                <button onClick={submit} disabled={pending || !csv.trim()}
                  className="flex-1 h-10 rounded-lg bg-brand-gradient text-white text-sm font-medium shadow-primary disabled:opacity-60">
                  {pending ? 'Importando…' : 'Importar'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
