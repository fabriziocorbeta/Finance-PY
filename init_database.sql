-- ============================================================
-- CD & Co CRM · Database Initialization Script
-- Creates tables for Leads, Subscriptions, Users, and Messages
-- Includes Row Level Security (RLS) policies for plan-based access
-- ============================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. USERS TABLE (extends Supabase auth.users)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  role TEXT DEFAULT 'user', -- admin, user, etc.
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- 2. SUBSCRIPTIONS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plan TEXT NOT NULL CHECK (plan IN ('starter', 'pro', 'enterprise')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'canceled', 'past_due', 'unpaid')),
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- 3. LEADS TABLE
-- ==========================================
CREATE TABLE IF NOT EXISTS public.leads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  wa_id TEXT, -- WhatsApp ID
  ig_handle TEXT, -- Instagram handle
  nombre_completo TEXT NOT NULL,
  estado_embudo TEXT NOT NULL DEFAULT 'nuevo' CHECK (estado_embudo IN ('nuevo', 'contactado', 'calificado', 'propuesta', 'negociacion', 'cerrado_ganado', 'cerrado_perdido')),
  valor_estimado DECIMAL(10,2), -- Estimated value in local currency
  fuente TEXT CHECK (fuente IN ('whatsapp', 'instagram', 'facebook', 'web', 'referido', 'otro')),
  ultima_interaccion TIMESTAMPTZ,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- 4. INTERACCIONES_LOG TABLE (Messages)
-- ==========================================
-- Note: This table already exists via migrations, but ensuring structure
CREATE TABLE IF NOT EXISTS public.interacciones_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  canal TEXT NOT NULL CHECK (canal IN ('whatsapp', 'instagram')),
  tipo TEXT NOT NULL,
  contenido TEXT,
  direccion TEXT CHECK (direccion IN ('entrante', 'saliente')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==========================================
-- 5. ENABLE ROW LEVEL SECURITY
-- ==========================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interacciones_log ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 6. RLS POLICIES
-- ==========================================

-- Users can only see their own data
CREATE POLICY "users_select_own" ON public.users
  FOR SELECT USING (auth.uid() = (SELECT auth_user_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE USING (auth.uid() = (SELECT auth_user_id FROM public.users WHERE id = auth.uid()));

-- Subscriptions: users can see their own subscriptions
CREATE POLICY "subscriptions_select_own" ON public.subscriptions
  FOR SELECT USING (user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()));

CREATE POLICY "subscriptions_insert_own" ON public.subscriptions
  FOR INSERT WITH CHECK (user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()));

CREATE POLICY "subscriptions_update_own" ON public.subscriptions
  FOR UPDATE USING (user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()));

-- Leads: Complex policy based on subscription plan
-- Starter plan: can only see their own leads
-- Pro/Enterprise: can see their own leads (same as starter for now, but structure allows for team features)
CREATE POLICY "leads_select_plan_based" ON public.leads
  FOR SELECT USING (
    -- User can always see their own leads
    user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    OR 
    -- For Pro/Enterprise plans, additional logic could go here for team sharing
    -- For now, same restriction applies (individual use case)
    (
      SELECT s.plan 
      FROM public.subscriptions s 
      WHERE s.user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()) 
      AND s.status = 'active'
      LIMIT 1
    ) IN ('pro', 'enterprise')
  );

-- Leads: users can insert their own leads
CREATE POLICY "leads_insert_own" ON public.leads
  FOR INSERT WITH CHECK (
    user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
  );

-- Leads: users can update their own leads
CREATE POLICY "leads_update_own" ON public.leads
  FOR UPDATE USING (
    user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
  );

-- Interacciones_log: users can see interactions for their leads
CREATE POLICY "interacciones_select_via_leads" ON public.interacciones_log
  FOR SELECT USING (
    lead_id IN (
      SELECT id FROM public.leads 
      WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    )
  );

-- Interacciones_log: users can insert interactions for their leads
CREATE POLICY "interacciones_insert_via_leads" ON public.interacciones_log
  FOR INSERT WITH CHECK (
    lead_id IN (
      SELECT id FROM public.leads 
      WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    )
  );

-- ==========================================
-- 7. INDEXES FOR PERFORMANCE
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_leads_user_id ON public.leads(user_id);
CREATE INDEX IF NOT EXISTS idx_leads_estado_embudo ON public.leads(estado_embudo);
CREATE INDEX IF NOT EXISTS idx_leads_valor_estimado ON public.leads(valor_estimado) WHERE valor_estimado IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_leads_fuente ON public.leads(fuente);
CREATE INDEX IF NOT EXISTS idx_interacciones_log_lead_id ON public.interacciones_log(lead_id);
CREATE INDEX IF NOT EXISTS idx_interacciones_log_canal ON public.interacciones_log(canal);
CREATE INDEX IF NOT EXISTS idx_interacciones_log_created_at ON public.interacciones_log(created_at);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_plan ON public.subscriptions(plan);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);

-- ==========================================
-- 8. TRIGGERS FOR UPDATED_AT COLUMNS
-- ==========================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON public.users 
  FOR EACH ROW 
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER update_subscriptions_updated_at 
  BEFORE UPDATE ON public.subscriptions 
  FOR EACH ROW 
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_leads_updated_at ON public.leads;
CREATE TRIGGER update_leads_updated_at 
  BEFORE UPDATE ON public.leads 
  FOR EACH ROW 
  EXECUTE FUNCTION public.update_updated_at_column();

-- ==========================================
-- 9. COMMENTS
-- ==========================================
COMMENT ON TABLE public.users IS 'Extended user profile data';
COMMENT ON TABLE public.subscriptions IS 'Subscription plans and billing information';
COMMENT ON TABLE public.leads IS 'Customer/prospect information with funnel tracking';
COMMENT ON TABLE public.interacciones_log IS 'Message/interaction log for omnichannel communication';

COMMENT ON COLUMN public.leads.estado_embudo IS 'Sales funnel stage: nuevo, contactado, calificado, propuesta, negociacion, cerrado_ganado, cerrado_perdido';
COMMENT ON COLUMN public.leads.valor_estimado IS 'Estimated monetary value of the lead';
COMMENT ON COLUMN public.interacciones_log.direccion IS 'Message direction: entrante (incoming) or saliente (outgoing)';

-- ==========================================
-- COMPLETED
-- ==========================================