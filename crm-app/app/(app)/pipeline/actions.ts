'use server';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';

const DealSchema = z.object({
  title: z.string().min(1),
  contact_id: z.string().uuid(),
  pipeline_id: z.string().uuid(),
  stage_id: z.string().uuid(),
  value_pyg: z.coerce.number().min(0).default(0),
  currency: z.string().default('PYG'),
});

export async function createDeal(formData: FormData) {
  const parsed = DealSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { data: profile } = await supabase.from('profiles').select('org_id').single();
  if (!profile) return { error: 'Sin organización' };

  const { title, contact_id, pipeline_id, stage_id, value_pyg, currency } = parsed.data;
  const { error } = await supabase.from('deals').insert({
    org_id: profile.org_id,
    title, contact_id, pipeline_id, stage_id,
    value_cents: Math.round(value_pyg * 100),
    currency,
  });
  if (error) return { error: error.message };

  revalidatePath('/pipeline');
  return { ok: true };
}

export async function moveDeal(dealId: string, newStageId: string, newPosition: number) {
  const supabase = await createClient();

  const { data: stage } = await supabase
    .from('stages').select('is_won, is_lost').eq('id', newStageId).single();

  const update: Record<string, unknown> = { stage_id: newStageId, position: newPosition };
  if (stage?.is_won) { update.status = 'won'; update.closed_at = new Date().toISOString(); }
  else if (stage?.is_lost) { update.status = 'lost'; update.closed_at = new Date().toISOString(); }
  else { update.status = 'open'; update.closed_at = null; }

  const { error } = await supabase.from('deals').update(update).eq('id', dealId);
  if (error) return { error: error.message };

  revalidatePath('/pipeline');
  return { ok: true };
}
