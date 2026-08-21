'use client';
import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Plus, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { createDeal } from '../actions';

type Stage = { id: string; name: string };
type Contact = { id: string; full_name: string };

export function NewDealButton({ pipelineId, stages, contacts }: {
  pipelineId: string; stages: Stage[]; contacts: Contact[];
}) {
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  async function onSubmit(formData: FormData) {
    formData.set('pipeline_id', pipelineId);
    startTransition(async () => {
      const res = await createDeal(formData);
      if (res?.error) { toast.error(res.error); return; }
      toast.success('Deal creado');
      setOpen(false);
      router.refresh();
    });
  }

  return (
    <>
      <button onClick={() => setOpen(true)}
        className="h-9 px-3 rounded-lg bg-brand-gradient text-white text-sm font-medium flex items-center gap-1.5 shadow-primary">
        <Plus size={14} /> Nuevo deal
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4" role="dialog" aria-modal="true">
          <div className="bg-surface rounded-card shadow-card border border-border w-full max-w-md">
            <div className="px-5 py-4 border-b border-border flex items-center justify-between">
              <h2 className="font-semibold text-text1">Nuevo deal</h2>
              <button onClick={() => setOpen(false)} className="p-1.5 rounded hover:bg-surface2 text-text2" aria-label="Cerrar">
                <X size={16} />
              </button>
            </div>
            <form action={onSubmit} className="p-5 space-y-4">
              <label className="block">
                <span className="text-xs font-medium text-text2 mb-1.5 block">Título *</span>
                <input name="title" required
                  className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm" />
              </label>
              <label className="block">
                <span className="text-xs font-medium text-text2 mb-1.5 block">Contacto *</span>
                <select name="contact_id" required defaultValue=""
                  className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm">
                  <option value="" disabled>Selecciona…</option>
                  {contacts.map(c => <option key={c.id} value={c.id}>{c.full_name}</option>)}
                </select>
              </label>
              <div className="grid grid-cols-2 gap-3">
                <label className="block">
                  <span className="text-xs font-medium text-text2 mb-1.5 block">Stage *</span>
                  <select name="stage_id" required defaultValue={stages[0]?.id}
                    className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm">
                    {stages.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
                  </select>
                </label>
                <label className="block">
                  <span className="text-xs font-medium text-text2 mb-1.5 block">Valor (PYG)</span>
                  <input name="value_pyg" type="number" min="0" step="1000" defaultValue="0"
                    className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm tabular" />
                </label>
              </div>
              <input type="hidden" name="currency" value="PYG" />
              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setOpen(false)}
                  className="flex-1 h-10 rounded-lg border border-border bg-surface text-text1 text-sm font-medium hover:bg-surface2">
                  Cancelar
                </button>
                <button type="submit" disabled={pending}
                  className="flex-1 h-10 rounded-lg bg-brand-gradient text-white text-sm font-medium shadow-primary disabled:opacity-60">
                  {pending ? 'Creando…' : 'Crear deal'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
