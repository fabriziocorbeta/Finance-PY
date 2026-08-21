'use server';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';

const ActivitySchema = z.object({
  kind: z.enum(['note','call','email','meeting','task','message']),
  title: z.string().optional(),
  body: z.string().min(1, 'Contenido requerido'),
});

export async function addActivity(contactId: string, formData: FormData) {
  const parsed = ActivitySchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data: profile } = await supabase.from('profiles').select('org_id').single();
  if (!user || !profile) return { error: 'No autenticado' };

  const { error } = await supabase.from('activities').insert({
    org_id: profile.org_id,
    contact_id: contactId,
    user_id: user.id,
    ...parsed.data,
  });
  if (error) return { error: error.message };

  revalidatePath(`/contactos/${contactId}`);
  return { ok: true };
}
