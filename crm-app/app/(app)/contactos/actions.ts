'use server';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';

const ContactSchema = z.object({
  full_name: z.string().min(1, 'Nombre requerido'),
  email:     z.string().email().optional().or(z.literal('')),
  phone:     z.string().optional(),
  whatsapp:  z.string().optional(),
  instagram: z.string().optional(),
  company:   z.string().optional(),
  position:  z.string().optional(),
  source:    z.enum(['whatsapp','instagram','facebook','website','referral','manual','import','other']).optional(),
  status:    z.enum(['lead','prospect','customer','inactive']).default('lead'),
  notes:     z.string().optional(),
});

export async function createContact(formData: FormData) {
  const parsed = ContactSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { data: profile } = await supabase
    .from('profiles').select('org_id').single();
  if (!profile) return { error: 'Sin organización' };

  const { error } = await supabase.from('contacts').insert({
    ...parsed.data,
    org_id: profile.org_id,
    email: parsed.data.email || null,
  });
  if (error) return { error: error.message };

  revalidatePath('/contactos');
  return { ok: true };
}

export async function updateContact(id: string, formData: FormData) {
  const parsed = ContactSchema.partial().safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: parsed.error.issues[0].message };

  const supabase = await createClient();
  const { error } = await supabase.from('contacts').update(parsed.data).eq('id', id);
  if (error) return { error: error.message };

  revalidatePath('/contactos');
  revalidatePath(`/contactos/${id}`);
  return { ok: true };
}

export async function deleteContact(id: string) {
  const supabase = await createClient();
  const { error } = await supabase.from('contacts').delete().eq('id', id);
  if (error) return { error: error.message };
  revalidatePath('/contactos');
  return { ok: true };
}

// CSV mínimo: soporta campos entre comillas con comas internas.
function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [], field = '', inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') inQuotes = false;
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = '';
    } else field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  return rows.filter(r => r.some(x => x.trim() !== ''));
}

const RowSchema = z.object({
  full_name: z.string().min(1),
  email:     z.string().email().optional().or(z.literal('')),
  phone:     z.string().optional(),
  whatsapp:  z.string().optional(),
  company:   z.string().optional(),
  status:    z.enum(['lead','prospect','customer','inactive']).optional(),
  source:    z.enum(['whatsapp','instagram','facebook','website','referral','manual','import','other']).optional(),
});

export async function importContacts(formData: FormData) {
  const csv = String(formData.get('csv') ?? '').trim();
  if (!csv) return { error: 'CSV vacío' };

  const rows = parseCsv(csv);
  if (rows.length < 2) return { error: 'Necesita header + al menos 1 fila' };

  const header = rows[0].map(h => h.trim().toLowerCase());
  const required = 'full_name';
  if (!header.includes(required)) return { error: `Header debe incluir columna "${required}"` };

  const supabase = await createClient();
  const { data: profile } = await supabase.from('profiles').select('org_id').single();
  if (!profile) return { error: 'Sin organización' };

  const inserts: Record<string, unknown>[] = [];
  const errors: string[] = [];

  for (let r = 1; r < rows.length; r++) {
    const obj: Record<string, string> = {};
    header.forEach((h, i) => { obj[h] = (rows[r][i] ?? '').trim(); });
    const parsed = RowSchema.safeParse(obj);
    if (!parsed.success) { errors.push(`Fila ${r + 1}: ${parsed.error.issues[0].message}`); continue; }
    inserts.push({
      org_id: profile.org_id,
      full_name: parsed.data.full_name,
      email: parsed.data.email || null,
      phone: parsed.data.phone || null,
      whatsapp: parsed.data.whatsapp || null,
      company: parsed.data.company || null,
      status: parsed.data.status ?? 'lead',
      source: parsed.data.source ?? 'import',
    });
  }

  if (inserts.length === 0) return { error: `0 filas válidas. ${errors[0] ?? ''}` };

  const { error } = await supabase.from('contacts').insert(inserts);
  if (error) return { error: error.message };

  revalidatePath('/contactos');
  return { ok: true, imported: inserts.length, skipped: errors.length };
}
