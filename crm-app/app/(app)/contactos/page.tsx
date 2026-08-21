import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import type { Contact } from '@/types/database';
import { NewContactButton } from './_components/contact-drawer';
import { ImportCsvButton } from './_components/import-csv';

export default async function ContactosPage() {
  const supabase = await createClient();
  const { data: contacts } = await supabase
    .from('contacts')
    .select('id, full_name, email, phone, whatsapp, instagram, company, status, source, updated_at')
    .order('updated_at', { ascending: false })
    .limit(100);

  return (
    <>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-text1">Contactos</h1>
          <p className="text-sm text-text3">{contacts?.length ?? 0} contactos</p>
        </div>
        <div className="flex gap-2">
          <ImportCsvButton />
          <NewContactButton />
        </div>
      </div>

      <div className="bg-surface border border-border rounded-card shadow-card overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-surface2 text-[11px] uppercase tracking-wider text-text3">
            <tr>
              <th className="text-left px-4 py-3 font-semibold">Contacto</th>
              <th className="text-left px-4 py-3 font-semibold">Empresa</th>
              <th className="text-left px-4 py-3 font-semibold">Canal</th>
              <th className="text-left px-4 py-3 font-semibold">Estado</th>
              <th className="text-left px-4 py-3 font-semibold">Fuente</th>
              <th className="text-right px-4 py-3 font-semibold">Actualizado</th>
            </tr>
          </thead>
          <tbody>
            {(contacts ?? []).length === 0 && (
              <tr><td colSpan={6} className="px-4 py-12 text-center text-text3">
                Sin contactos aún. Click <strong>Nuevo contacto</strong> para empezar.
              </td></tr>
            )}
            {(contacts ?? []).map((c) => (
              <tr key={c.id} className="border-t border-border hover:bg-surface2 group">
                <td className="px-4 py-3">
                  <Link href={`/contactos/${c.id}`} className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-full bg-brand-gradient text-white text-[11px] font-semibold flex items-center justify-center">
                      {c.full_name.split(' ').map(s=>s[0]).slice(0,2).join('').toUpperCase()}
                    </div>
                    <div>
                      <p className="font-medium text-text1 group-hover:text-primary">{c.full_name}</p>
                      <p className="text-[11px] text-text3">{c.email ?? c.phone ?? '—'}</p>
                    </div>
                  </Link>
                </td>
                <td className="px-4 py-3 text-text2">{c.company ?? '—'}</td>
                <td className="px-4 py-3">{channelBadge(c)}</td>
                <td className="px-4 py-3">{statusBadge(c.status as Contact['status'])}</td>
                <td className="px-4 py-3 text-text3 capitalize">{c.source ?? '—'}</td>
                <td className="px-4 py-3 text-right text-text3 text-xs">
                  {new Date(c.updated_at).toLocaleDateString('es-PY')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

function statusBadge(s: Contact['status']) {
  const map = {
    lead:     ['bg-slate-100 text-slate-700', 'Lead'],
    prospect: ['bg-indigo-50 text-indigo-700', 'Prospecto'],
    customer: ['bg-emerald-50 text-emerald-700', 'Cliente'],
    inactive: ['bg-rose-50 text-rose-700', 'Inactivo'],
  } as const;
  const [cls, label] = map[s];
  return <span className={`inline-flex px-2 py-0.5 rounded-full text-[11px] font-medium ${cls}`}>{label}</span>;
}

function channelBadge(c: { whatsapp: string | null; instagram: string | null; phone: string | null }) {
  if (c.whatsapp) return <span className="text-[11px] font-medium text-whatsapp">WhatsApp</span>;
  if (c.instagram) return <span className="text-[11px] font-medium text-instagram">Instagram</span>;
  if (c.phone) return <span className="text-[11px] text-text2">Teléfono</span>;
  return <span className="text-[11px] text-text3">—</span>;
}
