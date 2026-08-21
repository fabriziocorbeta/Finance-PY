import { createClient } from '@/lib/supabase/server';

export default async function DashboardPage() {
  const supabase = await createClient();
  const [{ count: contactsCount }, { count: dealsCount }, { data: openDealsValue }] = await Promise.all([
    supabase.from('contacts').select('id', { count: 'exact', head: true }),
    supabase.from('deals').select('id', { count: 'exact', head: true }),
    supabase.from('deals').select('value_cents').eq('status', 'open'),
  ]);

  const pipelineValue = (openDealsValue ?? []).reduce((s, d) => s + (d.value_cents ?? 0), 0);

  return (
    <>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-text1">Dashboard</h1>
          <p className="text-sm text-text3">Resumen general · Fase 1</p>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-4 mb-6">
        <KPI label="Contactos" value={contactsCount ?? 0} accent="primary" />
        <KPI label="Deals activos" value={dealsCount ?? 0} accent="secondary" />
        <KPI label="Valor pipeline" value={`₲ ${(pipelineValue / 100).toLocaleString('es-PY')}`} accent="success" />
        <KPI label="Tasa cierre" value="—" accent="warning" hint="disponible tras 30 días de datos" />
      </div>

      <div className="bg-surface border border-border rounded-card shadow-card p-6">
        <h2 className="text-sm font-semibold text-text1 mb-2">Próximos pasos Fase 1</h2>
        <ul className="text-sm text-text2 space-y-1.5 list-disc list-inside">
          <li>Cargar contactos (manual o import CSV)</li>
          <li>Crear deals y moverlos en el pipeline</li>
          <li>Registrar actividades (notas, llamadas, reuniones)</li>
          <li>Invitar al equipo desde Ajustes</li>
        </ul>
        <p className="text-xs text-text3 mt-4">Mensajería WhatsApp/Meta llega en Fase 2. Iniciar verificación Meta Business YA.</p>
      </div>
    </>
  );
}

function KPI({ label, value, accent, hint }: { label: string; value: number | string; accent: 'primary'|'secondary'|'success'|'warning'; hint?: string }) {
  const accentMap = { primary: 'bg-primary', secondary: 'bg-secondary', success: 'bg-success', warning: 'bg-warning' };
  return (
    <div className="bg-surface border border-border rounded-card shadow-card p-4 relative overflow-hidden">
      <div className={`absolute top-0 left-0 right-0 h-1 ${accentMap[accent]}`} />
      <p className="text-xs text-text2 font-medium mb-1">{label}</p>
      <p className="text-2xl font-bold text-text1 tabular">{value}</p>
      {hint && <p className="text-[11px] text-text3 mt-1">{hint}</p>}
    </div>
  );
}
