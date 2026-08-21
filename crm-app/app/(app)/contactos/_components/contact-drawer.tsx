'use client';
import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Plus, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { createContact } from '../actions';

export function NewContactButton() {
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  async function onSubmit(formData: FormData) {
    startTransition(async () => {
      const res = await createContact(formData);
      if (res?.error) { toast.error(res.error); return; }
      toast.success('Contacto creado');
      setOpen(false);
      router.refresh();
    });
  }

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="h-9 px-3 rounded-lg bg-brand-gradient text-white text-sm font-medium flex items-center gap-1.5 shadow-primary"
      >
        <Plus size={14} /> Nuevo contacto
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex" role="dialog" aria-modal="true" aria-label="Nuevo contacto">
          <div className="flex-1 bg-slate-900/40 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <aside className="w-full max-w-md bg-surface border-l border-border h-dvh overflow-y-auto animate-in slide-in-from-right">
            <div className="px-5 py-4 border-b border-border flex items-center justify-between sticky top-0 bg-surface z-10">
              <h2 className="font-semibold text-text1">Nuevo contacto</h2>
              <button onClick={() => setOpen(false)} className="p-1.5 rounded hover:bg-surface2 text-text2" aria-label="Cerrar">
                <X size={16} />
              </button>
            </div>

            <form action={onSubmit} className="p-5 space-y-4">
              <Field label="Nombre completo *" name="full_name" required />
              <Field label="Email" name="email" type="email" />
              <div className="grid grid-cols-2 gap-3">
                <Field label="Teléfono" name="phone" />
                <Field label="WhatsApp" name="whatsapp" hint="ej: 595981234567" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Instagram" name="instagram" hint="@usuario" />
                <Field label="Empresa" name="company" />
              </div>
              <Field label="Cargo" name="position" />

              <div className="grid grid-cols-2 gap-3">
                <SelectField label="Estado" name="status" defaultValue="lead" options={[
                  ['lead','Lead'], ['prospect','Prospecto'], ['customer','Cliente'], ['inactive','Inactivo']
                ]} />
                <SelectField label="Fuente" name="source" options={[
                  ['','—'], ['whatsapp','WhatsApp'], ['instagram','Instagram'], ['facebook','Facebook'],
                  ['website','Website'], ['referral','Referido'], ['manual','Manual'], ['other','Otro']
                ]} />
              </div>

              <label className="block">
                <span className="text-xs font-medium text-text2 mb-1.5 block">Notas</span>
                <textarea
                  name="notes" rows={3}
                  className="w-full px-3 py-2 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm resize-y"
                />
              </label>

              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setOpen(false)}
                  className="flex-1 h-10 rounded-lg border border-border bg-surface text-text1 text-sm font-medium hover:bg-surface2">
                  Cancelar
                </button>
                <button type="submit" disabled={pending}
                  className="flex-1 h-10 rounded-lg bg-brand-gradient text-white text-sm font-medium shadow-primary disabled:opacity-60">
                  {pending ? 'Guardando…' : 'Crear contacto'}
                </button>
              </div>
            </form>
          </aside>
        </div>
      )}
    </>
  );
}

function Field({ label, name, type='text', required, hint }: {
  label: string; name: string; type?: string; required?: boolean; hint?: string;
}) {
  return (
    <label className="block">
      <span className="text-xs font-medium text-text2 mb-1.5 block">{label}</span>
      <input
        name={name} type={type} required={required}
        className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm"
      />
      {hint && <span className="text-[11px] text-text3 mt-1 block">{hint}</span>}
    </label>
  );
}

function SelectField({ label, name, defaultValue, options }: {
  label: string; name: string; defaultValue?: string; options: [string, string][];
}) {
  return (
    <label className="block">
      <span className="text-xs font-medium text-text2 mb-1.5 block">{label}</span>
      <select
        name={name} defaultValue={defaultValue}
        className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm"
      >
        {options.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
      </select>
    </label>
  );
}
