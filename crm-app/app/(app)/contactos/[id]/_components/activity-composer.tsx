'use client';
import { useTransition, useRef } from 'react';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import { addActivity } from '../actions';

export function ActivityComposer({ contactId }: { contactId: string }) {
  const [pending, startTransition] = useTransition();
  const router = useRouter();
  const formRef = useRef<HTMLFormElement>(null);

  async function onSubmit(formData: FormData) {
    startTransition(async () => {
      const res = await addActivity(contactId, formData);
      if (res?.error) { toast.error(res.error); return; }
      toast.success('Actividad registrada');
      formRef.current?.reset();
      router.refresh();
    });
  }

  return (
    <form ref={formRef} action={onSubmit} className="bg-surface border border-border rounded-card p-4 space-y-3">
      <div className="flex gap-2">
        <select name="kind" defaultValue="note"
          className="h-9 px-3 rounded-lg bg-surface2 border border-border text-sm focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none">
          <option value="note">Nota</option>
          <option value="call">Llamada</option>
          <option value="email">Email</option>
          <option value="meeting">Reunión</option>
          <option value="task">Tarea</option>
          <option value="message">Mensaje</option>
        </select>
        <input name="title" placeholder="Título (opcional)"
          className="flex-1 h-9 px-3 rounded-lg bg-surface2 border border-border text-sm focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none" />
      </div>
      <textarea name="body" required rows={3} placeholder="Detalle… (requerido)"
        className="w-full px-3 py-2 rounded-lg bg-surface2 border border-border text-sm focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none resize-y" />
      <div className="flex justify-end">
        <button type="submit" disabled={pending}
          className="h-9 px-4 rounded-lg bg-brand-gradient text-white text-sm font-medium shadow-primary disabled:opacity-60">
          {pending ? 'Guardando…' : 'Registrar'}
        </button>
      </div>
    </form>
  );
}
