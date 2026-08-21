'use client';
import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Pencil, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { updateContact } from '../../actions';
import type { Contact } from '@/types/database';

export function EditContactButton({ contact }: { contact: Contact }) {
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  function onSubmit(formData: FormData) {
    startTransition(async () => {
      const res = await updateContact(contact.id, formData);
      if (res?.error) { toast.error(res.error); return; }
      toast.success('Contacto actualizado');
      setOpen(false);
      router.refresh();
    });
  }

  return (
    <>
      <button onClick={() => setOpen(true)}
        className="h-8 px-3 rounded-lg border border-border bg-surface text-text1 text-sm font-medium flex items-center gap-1.5 hover:bg-surface2">
        <Pencil size={13} /> Editar
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex" role="dialog" aria-modal="true" aria-label="Editar contacto">
          <div className="flex-1 bg-slate-900/40 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <aside className="w-full max-w-md bg-surface border-l border-border h-dvh overflow-y-auto">
            <div className="px-5 py-4 border-b border-border flex items-center justify-between sticky top-0 bg-surface z-10">
              <h2 className="font-semibold text-text1">Editar contacto</h2>
              <button onClick={() => setOpen(false)} className="p-1.5 rounded hover:bg-surface2 text-text2" aria-label="Cerrar"><X size={16} /></button>
            </div>
            <form action={onSubmit} className="p-5 space-y-4">
              <F label="Nombre completo *" name="full_name" defaultValue={contact.full_name} required />
              <F label="Email" name="email" type="email" defaultValue={contact.email ?? ''} />
              <div className="grid grid-cols-2 gap-3">
                <F label="Teléfono" name="phone" defaultValue={contact.phone ?? ''} />
                <F label="WhatsApp" name="whatsapp" defaultValue={contact.whatsapp ?? ''} />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <F label="Instagram" name="instagram" defaultValue={contact.instagram ?? ''} />
                <F label="Empresa" name="company" defaultValue={contact.company ?? ''} />
              </div>
              <F label="Cargo" name="position" defaultValue={contact.position ?? ''} />
              <div className="grid grid-cols-2 gap-3">
                <S label="Estado" name="status" defaultValue={contact.status} options={[
                  ['lead','Lead'],['prospect','Prospecto'],['customer','Cliente'],['inactive','Inactivo']]} />
                <S label="Fuente" name="source" defaultValue={contact.source ?? ''} options={[
                  ['','—'],['whatsapp','WhatsApp'],['instagram','Instagram'],['facebook','Facebook'],
                  ['website','Website'],['referral','Referido'],['manual','Manual'],['other','Otro']]} />
              </div>
              <label className="block">
                <span className="text-xs font-medium text-text2 mb-1.5 block">Notas</span>
                <textarea name="notes" rows={3} defaultValue={contact.notes ?? ''}
                  className="w-full px-3 py-2 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm resize-y" />
              </label>
              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => setOpen(false)}
                  className="flex-1 h-10 rounded-lg border border-border bg-surface text-text1 text-sm font-medium hover:bg-surface2">Cancelar</button>
                <button type="submit" disabled={pending}
                  className="flex-1 h-10 rounded-lg bg-brand-gradient text-white text-sm font-medium shadow-primary disabled:opacity-60">
                  {pending ? 'Guardando…' : 'Guardar'}
                </button>
              </div>
            </form>
          </aside>
        </div>
      )}
    </>
  );
}

function F({ label, name, type='text', required, defaultValue }: {
  label: string; name: string; type?: string; required?: boolean; defaultValue?: string;
}) {
  return (
    <label className="block">
      <span className="text-xs font-medium text-text2 mb-1.5 block">{label}</span>
      <input name={name} type={type} required={required} defaultValue={defaultValue}
        className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm" />
    </label>
  );
}

function S({ label, name, defaultValue, options }: {
  label: string; name: string; defaultValue?: string; options: [string,string][];
}) {
  return (
    <label className="block">
      <span className="text-xs font-medium text-text2 mb-1.5 block">{label}</span>
      <select name={name} defaultValue={defaultValue}
        className="w-full h-10 px-3 rounded-lg bg-surface2 border border-border focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none text-sm">
        {options.map(([v,l]) => <option key={v} value={v}>{l}</option>)}
      </select>
    </label>
  );
}
