import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import { KanbanBoard } from './_components/kanban-board';
import { NewDealButton } from './_components/new-deal-button';

export default async function PipelinePage() {
  const supabase = await createClient();

  const { data: pipeline } = await supabase
    .from('pipelines').select('id, name').eq('is_default', true).single();

  if (!pipeline) {
    return (
      <div className="bg-surface border border-border rounded-card p-12 text-center">
        <p className="text-text2 mb-3">No hay pipeline configurado.</p>
        <p className="text-sm text-text3">El trigger de signup debería haber creado uno automáticamente. Si no, ejecuta en SQL:</p>
        <code className="block mt-3 text-xs bg-surface2 px-3 py-2 rounded">select seed_default_pipeline(current_org_id())</code>
      </div>
    );
  }

  const [{ data: stagesRaw }, { data: dealsRaw }, { data: contacts }] = await Promise.all([
    supabase.from('stages').select('id, name, position, color').eq('pipeline_id', pipeline.id).order('position'),
    supabase.from('deals')
      .select('id, title, value_cents, currency, stage_id, contacts(full_name)')
      .eq('pipeline_id', pipeline.id).eq('status', 'open'),
    supabase.from('contacts').select('id, full_name').order('full_name').limit(200),
  ]);

  const stages = stagesRaw ?? [];
  const deals = (dealsRaw ?? []).map(d => ({
    id: d.id, title: d.title, value_cents: d.value_cents, currency: d.currency, stage_id: d.stage_id,
    contact_name: (d.contacts as { full_name: string } | null)?.full_name ?? null,
  }));

  return (
    <>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold text-text1">Pipeline · {pipeline.name}</h1>
          <p className="text-sm text-text3">{deals.length} deals activos · arrastra para mover</p>
        </div>
        {contacts && contacts.length > 0 ? (
          <NewDealButton pipelineId={pipeline.id} stages={stages.map(s => ({id: s.id, name: s.name}))} contacts={contacts} />
        ) : (
          <Link href="/contactos" className="h-9 px-3 rounded-lg border border-border bg-surface text-sm font-medium text-text1 hover:bg-surface2 flex items-center">
            Crea un contacto primero
          </Link>
        )}
      </div>

      <KanbanBoard stages={stages} deals={deals} />
    </>
  );
}
