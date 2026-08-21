# Backend Security Architecture for CD & Co CRM

## 1. Current Database Handling Analysis

### Supabase Implementation
The CRM uses Supabase as its backend, which provides:
- PostgreSQL database with Row Level Security (RLS)
- Authentication service (Supabase Auth)
- Edge Functions for serverless logic
- Real-time subscriptions
- Storage for files

### Current Schema Overview
From the initialization script (`init_database.sql`) and migrations:

**Tables:**
1. `users` - Extended user profile data linked to Supabase auth.users
2. `subscriptions` - Subscription plans and billing information
3. `leads` - Customer/prospect information with funnel tracking
4. `interacciones_log` - Message/interaction log for omnichannel communication

**Relationships:**
- Each user has one subscription (one-to-one)
- Each user can have many leads (one-to-many)
- Each lead can have many interactions (one-to-many)

### Current Security Measures
1. **Row Level Security (RLS)** enabled on all tables
2. **Policies** restricting access based on user ownership:
   - Users can only see/update their own data
   - Leads access filtered by user_id
   - Interactions access filtered through lead ownership
3. **Role-based access**:
   - `anon` - Limited to SELECT operations only
   - `authenticated` - Limited to SELECT operations only
   - `service_role` - Bypasses RLS (used for backend operations)
4. **Privileges** properly revoked:
   - No INSERT/UPDATE/DELETE for anon or authenticated roles on core tables
5. **Indexes** for performance on frequently queried columns

## 2. Database Schema Proposal

### Enhanced Schema for Multi-tenant Security

The current schema already implements good security foundations. However, we can enhance it for better clarity and future scalability:

#### Key Improvements:
1. **Explicit Tenant ID** - While user_id provides isolation, adding explicit tenant concepts can help with future team features
2. **Audit Fields** - Enhanced tracking for compliance
3. **Encryption at Rest** - For sensitive fields
4. **Improved RLS Policies** - More granular control

### Proposed Enhanced Schema

```sql
-- Enhanced Leads Table with additional security fields
CREATE TABLE IF NOT EXISTS public.leads_enhanced (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    -- Encrypted fields for sensitive data
    wa_id_encrypted TEXT, -- WhatsApp ID (encrypted)
    ig_handle_encrypted TEXT, -- Instagram handle (encrypted)
    nombre_completo TEXT NOT NULL,
    estado_embudo TEXT NOT NULL DEFAULT 'nuevo' CHECK (estado_embudo IN ('nuevo', 'contactado', 'calificado', 'propuesta', 'negociacion', 'cerrado_ganado', 'cerrado_perdido')),
    valor_estimado DECIMAL(10,2), -- Estimated value in local currency
    fuente TEXT CHECK (fuente IN ('whatsapp', 'instagram', 'facebook', 'web', 'referido', 'otro')),
    ultima_interaccion TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Audit fields
    created_by UUID REFERENCES public.users(id),
    updated_by UUID REFERENCES public.users(id)
);

-- Enhanced Interactions Table
CREATE TABLE IF NOT EXISTS public.interacciones_log_enhanced (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lead_id UUID NOT NULL REFERENCES public.leads_enhanced(id) ON DELETE CASCADE,
    canal TEXT NOT NULL CHECK (canal IN ('whatsapp', 'instagram')),
    tipo TEXT NOT NULL,
    contenido TEXT,
    direccion TEXT CHECK (direccion IN ('entrante', 'saliente')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Audit fields
    created_by UUID REFERENCES public.users(id)
);
```

### Encryption Strategy for Sensitive Fields

For fields containing personally identifiable information (PII) like WhatsApp IDs and Instagram handles:

1. **Client-side Encryption**: Encrypt sensitive data before sending to backend
2. **Backend Encryption**: Use Supabase Edge Functions or database pgcrypto extension
3. **Key Management**: Store encryption keys securely (not in frontend)

Example using pgcrypto:
```sql
-- Enable pgcrypto extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypting data
INSERT INTO leads_enhanced (wa_id_encrypted)
VALUES (pgp_sym_encrypt('+1234567890', current_setting('app.encryption_key')));

-- Decrypting data
SELECT pgp_sym_decrypt(wa_id_encrypted, current_setting('app.encryption_key')) as wa_id
FROM leads_enhanced;
```

## 3. Row Level Security (RLS) Policy Recommendations

### Current Policies Analysis
The current RLS policies in `init_database.sql` are well-designed but can be enhanced:

**Strengths:**
- Users restricted to their own data
- Proper use of `auth.uid()` for authentication
- Plan-based access controls structured (though currently same for all plans)

**Improvements:**
1. **More Granular Permissions**: Different actions for different roles
2. **Team/Organization Features**: Allow sharing within teams for Pro/Enterprise
3. **Audit Logging**: Track who accessed what data
4. **Time-based Restrictions**: Limit access based on subscription status

### Enhanced RLS Policies

```sql
-- Enhanced Leads Policy with Team Support
CREATE POLICY "leads_enhanced_select_team" ON public.leads_enhanced
FOR SELECT USING (
    -- User can always see their own leads
    user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    OR 
    -- For Pro/Enterprise plans, allow team access
    (
        SELECT s.plan 
        FROM public.subscriptions s 
        WHERE s.user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()) 
        AND s.status = 'active'
        LIMIT 1
    ) IN ('pro', 'enterprise')
    AND
    -- Team-based access (to be implemented with teams table)
    EXISTS (
        SELECT 1 FROM team_members tm
        WHERE tm.team_id IN (
            SELECT team_id FROM team_members 
            WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
        )
        AND tm.user_id = leads_enhanced.user_id
    )
);

-- Insert Policy
CREATE POLICY "leads_enhanced_insert_own" ON public.leads_enhanced
FOR INSERT WITH CHECK (
    user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
);

-- Update Policy (owners and team admins)
CREATE POLICY "leads_enhanced_update_team" ON public.leads_enhanced
FOR UPDATE USING (
    -- Owner can update
    user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
    OR
    -- Team admin can update team members' leads
    (
        SELECT s.plan 
        FROM public.subscriptions s 
        WHERE s.user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid()) 
        AND s.status = 'active'
        LIMIT 1
    ) IN ('pro', 'enterprise')
    AND
    EXISTS (
        SELECT 1 FROM team_members tm
        WHERE tm.team_id IN (
            SELECT team_id FROM team_members 
            WHERE user_id = (SELECT id FROM public.users WHERE auth_user_id = auth.uid())
            AND tm.role = 'admin'
        )
        AND tm.user_id = leads_enhanced.user_id
    )
);
```

## 4. Frontend Security Review

### Current Implementation Analysis
From reviewing `cd-co-dashboard/src/components/CommandCenter.tsx`:

**Security Strengths:**
1. **Environment Variables**: Supabase URL and anon key stored in `.env` (not hardcoded)
2. **No Hardcoded Credentials**: No visible passwords, tokens, or keys in frontend code
3. **Proper Client Initialization**: Using `import.meta.env.VITE_*` variables
4. **Limited Exposure**: Only anon key exposed (appropriate for client-side)

**Areas for Improvement:**
1. **Environment Variable Validation**: Missing validation for required env vars
2. **Error Message Security**: Error messages might reveal too much information
3. **Data Handling**: Ensure decrypted data isn't logged or exposed unnecessarily

### Specific Findings
- Line 9-12: Supabase client correctly initialized with environment variables
- Line 344: Error message: "No se pudo conectar con Supabase. Verifica tu conexión o las credenciales." - Appropriate, doesn't leak specifics
- No hardcoded API keys, passwords, or tokens found in frontend code

### Recommendations for Frontend
1. **Add Environment Validation**:
```typescript
if (!import.meta.env.VITE_SUPABASE_URL || !import.meta.env.VITE_SUPABASE_ANON_KEY) {
    throw new Error('Missing Supabase environment variables');
}
```

2. **Enhance Error Handling**: Generic error messages for users, detailed logging internally
3. **Implement Encryption Handling**: If implementing field encryption, ensure proper decryption in frontend
4. **Add Request Interceptors**: For logging and security monitoring

## 5. Hardcoded Credentials Assessment

### Search Results
After thorough searching of the codebase:
- **No hardcoded passwords, tokens, or API keys found** in frontend code
- Supabase credentials properly stored in environment variables (`cd-co-dashboard/.env`)
- No sensitive data exposed in JavaScript/TypeScript files
- Configuration files appear to be properly secured

### Files Checked
- Frontend: `cd-co-dashboard/src/` directory (all .ts, .tsx, .js, .jsx files)
- Backend: Supabase migrations and initialization scripts
- Configuration: `.env` files
- No hardcoded credentials detected in any location

## 6. Security Recommendations

### Immediate Actions (Short-term)
1. **Environment Variable Validation**: Add validation in frontend startup
2. **Enhance Error Handling**: Ensure error messages don't leak system details
3. **Regular Dependency Updates**: Keep npm packages updated
4. **Environment Variable Audit**: Double-check all `.env` files are in `.gitignore`

### Medium-term Improvements
1. **Implement Field Encryption**: For sensitive PII like contact information
2. **Enhanced RLS Policies**: Implement team-based access for Pro/Enterprise plans
3. **Audit Logging**: Create audit trail for sensitive data access
4. **API Rate Limiting**: Implement rate limiting on Edge Functions
5. **Regular Security Scans**: Automated dependency vulnerability scanning

### Long-term Strategic
1. **SOC 2 Compliance Preparation**: Document controls and procedures
2. **Penetration Testing**: Regular third-party security assessments
3. **Advanced Threat Detection**: Implement anomaly detection for unusual access patterns
4. **Data Loss Prevention (DLP)**: Prevent accidental exposure of sensitive data

## 7. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [ ] Add environment variable validation to frontend
- [ ] Enhance error handling in frontend components
- [ ] Verify all environment variables are properly configured
- [ ] Document current security architecture

### Phase 2: Encryption & Enhanced RLS (Weeks 3-4)
- [ ] Implement pgcrypto extension in Supabase
- [ ] Create encryption/decryption helper functions
- [ ] Migrate sensitive fields to encrypted storage
- [ ] Update RLS policies for team-based access

### Phase 3: Monitoring & Auditing (Weeks 5-6)
- [ ] Implement audit logging for data access
- [ ] Add request/response logging for API monitoring
- [ ] Create security dashboard for monitoring access patterns
- [ ] Implement alerts for suspicious activities

### Phase 4: Compliance & Advanced Features (Ongoing)
- [ ] Regular security assessments and penetration testing
- [ ] Compliance documentation (GDPR, CCPA considerations)
- [ ] Advanced threat detection and prevention
- [ ] Ongoing security training and awareness

## 8. Conclusion

The current CRM backend architecture demonstrates strong security fundamentals:
- Proper use of Supabase RLS for data isolation
- No hardcoded credentials in frontend code
- Appropriate privilege separation between anon, authenticated, and service_role
- Well-structured database schema with proper relationships

**Key Security Strengths:**
1. Row Level Security properly implemented on all tables
2. Client-side only exposes anon key (appropriate for Supabase)
3. No evidence of hardcoded credentials in codebase
4. Proper database schema with referential integrity
5. Environment-based configuration for different deployment stages

**Recommended Enhancements:**
1. Implement field-level encryption for sensitive PII
2. Enhance RLS policies to support team features for higher-tier plans
3. Add comprehensive audit logging and monitoring
4. Strengthen error handling and validation

The foundation is solid, and with the recommended enhancements, the CRM can achieve enterprise-grade security suitable for handling sensitive luxury watch sales data.