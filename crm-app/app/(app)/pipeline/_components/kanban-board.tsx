'use client';
import { useState } from 'react';
import { DndContext, useDraggable, useDroppable, DragEndEvent, DragOverlay, PointerSensor, useSensor, useSensors } from '@dnd-kit/core';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import { moveDeal } from '../actions';

type Stage = { id: string; name: string; color: string };
type Deal = { id: string; title: string; value_cents: number; currency: string; stage_id: string; contact_name: string | null };

export function KanbanBoard({ stages, deals: initialDeals }: { stages: Stage[]; deals: Deal[] }) {
  const [deals, setDeals] = useState(initialDeals);
  const [activeId, setActiveId] = useState<string | null>(null);
  const router = useRouter();
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 5 } }));

  async function onDragEnd(e: DragEndEvent) {
    setActiveId(null);
    const dealId = e.active.id as string;
    const overId = e.over?.id as string | undefined;
    if (!overId) return;
    const newStageId = overId.startsWith('stage-') ? overId.slice(6) : overId;
    const deal = deals.find(d => d.id === dealId);
    if (!deal || deal.stage_id === newStageId) return;

    // Optimistic
    setDeals(prev => prev.map(d => d.id === dealId ? { ...d, stage_id: newStageId } : d));
    const res = await moveDeal(dealId, newStageId, 0);
    if (res?.error) {
      toast.error(res.error);
      setDeals(initialDeals);
    } else {
      router.refresh();
    }
  }

  const byStage = new Map<string, Deal[]>();
  deals.forEach(d => {
    const arr = byStage.get(d.stage_id) ?? [];
    arr.push(d); byStage.set(d.stage_id, arr);
  });

  const activeDeal = activeId ? deals.find(d => d.id === activeId) : null;

  return (
    <DndContext sensors={sensors} onDragStart={(e)=>setActiveId(e.active.id as string)} onDragEnd={onDragEnd}>
      <div className="grid gap-3" style={{ gridTemplateColumns: `repeat(${stages.length}, minmax(220px, 1fr))` }}>
        {stages.map(stage => (
          <StageColumn key={stage.id} stage={stage} deals={byStage.get(stage.id) ?? []} />
        ))}
      </div>
      <DragOverlay>
        {activeDeal && <DealCard deal={activeDeal} dragging />}
      </DragOverlay>
    </DndContext>
  );
}

function StageColumn({ stage, deals }: { stage: Stage; deals: Deal[] }) {
  const { setNodeRef, isOver } = useDroppable({ id: `stage-${stage.id}` });
  const total = deals.reduce((s, d) => s + d.value_cents, 0);
  return (
    <div ref={setNodeRef}
      className={`bg-surface2 rounded-card p-3 min-h-[420px] transition ${isOver ? 'ring-2 ring-primary ring-offset-1 ring-offset-bg' : ''}`}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full" style={{ background: stage.color }} />
          <span className="text-[13px] font-semibold text-text1">{stage.name}</span>
        </div>
        <span className="text-[10px] bg-surface border border-border px-1.5 py-0.5 rounded-full text-text2 font-semibold">{deals.length}</span>
      </div>
      <p className="text-[11px] text-text3 mb-3 tabular">₲ {(total / 100).toLocaleString('es-PY')}</p>
      <div className="space-y-2">
        {deals.map(d => <DealCard key={d.id} deal={d} />)}
        {deals.length === 0 && <p className="text-[11px] text-text3 text-center py-6">Suelta aquí</p>}
      </div>
    </div>
  );
}

function DealCard({ deal, dragging }: { deal: Deal; dragging?: boolean }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({ id: deal.id });
  const style = transform ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)` } : undefined;
  return (
    <div ref={setNodeRef} {...listeners} {...attributes} style={style}
      className={`bg-surface border border-border rounded-lg p-3 cursor-grab active:cursor-grabbing hover:shadow-card ${isDragging ? 'opacity-30' : ''} ${dragging ? 'shadow-primary rotate-1' : ''}`}>
      <p className="text-[13px] font-medium text-text1 mb-1 truncate">{deal.title}</p>
      <p className="text-[11px] text-text3 mb-2 truncate">{deal.contact_name ?? 'Sin contacto'}</p>
      <p className="text-[12px] font-semibold text-primary tabular">{deal.currency} {(deal.value_cents / 100).toLocaleString('es-PY')}</p>
    </div>
  );
}
