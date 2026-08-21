// Tipos de dominio Fase 1. Regenerar desde Supabase CLI cuando schema cambie:
// pnpm dlx supabase gen types typescript --project-id YOUR_ID > types/supabase.ts

export type ContactStatus = 'lead' | 'prospect' | 'customer' | 'inactive';
export type ContactSource =
  | 'whatsapp' | 'instagram' | 'facebook'
  | 'website'  | 'referral'  | 'manual' | 'import' | 'other';
export type DealStatus = 'open' | 'won' | 'lost';
export type UserRole = 'owner' | 'admin' | 'member';
export type ActivityKind =
  | 'note' | 'call' | 'email' | 'meeting'
  | 'task' | 'message' | 'status_change' | 'deal_moved';

export interface Organization { id: string; name: string; slug: string; created_at: string; }
export interface Profile {
  id: string; org_id: string; full_name: string | null;
  avatar_url: string | null; role: UserRole; created_at: string;
}
export interface Contact {
  id: string; org_id: string; full_name: string;
  email: string | null; phone: string | null; whatsapp: string | null;
  instagram: string | null; facebook_id: string | null;
  company: string | null; position: string | null;
  source: ContactSource | null; status: ContactStatus;
  notes: string | null; owner_id: string | null;
  created_at: string; updated_at: string;
}
export interface Tag { id: string; org_id: string; name: string; color: string; }
export interface Pipeline { id: string; org_id: string; name: string; is_default: boolean; created_at: string; }
export interface Stage {
  id: string; pipeline_id: string; name: string; position: number;
  color: string; is_won: boolean; is_lost: boolean; created_at: string;
}
export interface Deal {
  id: string; org_id: string; contact_id: string; pipeline_id: string; stage_id: string;
  title: string; value_cents: number; currency: string; probability: number;
  expected_close: string | null; owner_id: string | null;
  position: number; status: DealStatus;
  created_at: string; updated_at: string; closed_at: string | null;
}
export interface Activity {
  id: string; org_id: string;
  contact_id: string | null; deal_id: string | null; user_id: string | null;
  kind: ActivityKind; title: string | null; body: string | null;
  due_at: string | null; completed_at: string | null;
  metadata: Record<string, unknown>; created_at: string;
}
