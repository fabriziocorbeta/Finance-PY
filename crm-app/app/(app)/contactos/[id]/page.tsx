import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { ArrowLeft, Mail, Phone, MessageCircle, Instagram, Building2 } from 'lucide-react';
import { ActivityComposer } from './_components/activity-composer';

export default async function ContactDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: contact } = await supabase
    .from('contacts').select('*').eq('id', id).single();
  if (!contact) notFound();

  const { data: activities } = await supabase
    .from('activities').select('*').eq('contact_id', id).order('created_at', { ascending: false }).limit(50);

  return (
    <>
      <Link href="/contactos" className="text-sm text-text2 hover:text-primary flex items-center gap-1 mb-4">
        <ArrowLeft size={14} /> Contactos
      </Link>

      <div className="grid grid-cols-[1fr_320px] gap-6">
        <div>
          <div className="bg-surface border border-border rounded-card shadow-card p-6 mb-4">
            <div className="flex items-center gap-4 mb-5">
              <div className="w-14 h-14 rounded-full bg-brand-gradient text-white text-base font-bold flex items-center justify-center">
                {contact.full_name.split(' ').map((s: string)=>s[0]).slice(0,2).join('').toUpperCase()}
              </div>
              <div>
                <h1 className="text-xl font-bold text-text1">{contact.full_name}</h1>
                <p className="text-sm text-text3">{contact.position ?? '—'} {contact.company && `· ${contact.company}`}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 text-sm">
              <InfoRow icon={<Mail size={13} />} label="Email" value={contact.email} />
              <InfoRow icon={<Phone size={13} />} label="Teléfono" value={contact.phone} />
              <InfoRow icon={<MessageCircle size={13} />} label="WhatsApp" value={contact.whatsapp} color="whatsapp" />
              <InfoRow icon={<Instagram size={13} />} label="Instagram" value={contact.instagram} color="instagram" />
              <InfoRow icon={<Building2 size={13} />} label="Empresa" value={contact.company} />
            </div>

            {contact.notes && (
              <div className="mt-5 pt-4 border-t border-border">
                <p className="text-[11px] uppercase tracking-wider text-text3 font-semibold mb-1">Notas</p>
                <p className="text-sm text-text1 whitespace-pre-wrap">{contact.notes}</p>
              </div>
            )}
          </div>

          <h2 className="text-sm font-semibold text-text1 mb-3">Actividad</h2>
          <ActivityComposer contactId={id} />

          <div className="space-y-2 mt-4">
            {(activities ?? []).length === 0 && (
              <p className="text-sm text-text3 text-center py-8 bg-surface border border-dashed border-border rounded-card">
                Sin actividad aún. Registra primera nota arriba.
              </p>
            )}
            {(activities ?? []).map((a) => (
              <div key={a.id} className="bg-surface border border-border rounded-card p-4">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-[11px] uppercase tracking-wider text-text3 font-semibold">{a.kind}</span>
                  <span className="text-[11px] text-text3">{new Date(a.created_at).toLocaleString('es-PY')}</span>
                </div>
                {a.title && <p className="text-sm font-medium text-text1 mb-1">{a.title}</p>}
                {a.body && <p className="text-sm text-text2 whitespace-pre-wrap">{a.body}</p>}
              </div>
            ))}
          </div>
        </div>

        <aside className="space-y-3">
          <SideCard label="Estado" value={statusLabel(contact.status)} />
          <SideCard label="Fuente" value={contact.source ?? '—'} />
          <SideCard label="Creado" value={new Date(contact.created_at).toLocaleDateString('es-PY')} />
        </aside>
      </div>
    </>
  );
}

function InfoRow({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: string | null; color?: 'whatsapp' | 'instagram' }) {
  if (!value) return null;
  const colorCls = color === 'whatsapp' ? 'text-whatsapp' : color === 'instagram' ? 'text-instagram' : 'text-text1';
  return (
    <div className="flex items-start gap-2">
      <span className="text-text3 mt-0.5">{icon}</span>
      <div className="min-w-0">
        <p className="text-[11px] text-text3">{label}</p>
        <p className={`text-sm font-medium truncate ${colorCls}`}>{value}</p>
      </div>
    </div>
  );
}

function SideCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-surface border border-border rounded-card p-4">
      <p className="text-[11px] uppercase tracking-wider text-text3 font-semibold mb-1">{label}</p>
      <p className="text-sm font-medium text-text1 capitalize">{value}</p>
    </div>
  );
}

function statusLabel(s: string) {
  return ({ lead: 'Lead', prospect: 'Prospecto', customer: 'Cliente', inactive: 'Inactivo' } as Record<string,string>)[s] ?? s;
}
