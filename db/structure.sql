--
-- PostgreSQL database dump
--

\restrict 8aimRRRWXsWO8dKdSQxba6TSES2pSmlHbFNYbyHDuxHL6A4k1fOSf8ITCrKOh6W

-- Dumped from database version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner:
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: account_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.account_status AS ENUM (
    'ok',
    'syncing',
    'error'
);


ALTER TYPE public.account_status OWNER TO postgres;

--
-- Name: goal_pledge_kind; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.goal_pledge_kind AS ENUM (
    'transfer',
    'manual_save'
);


ALTER TYPE public.goal_pledge_kind OWNER TO postgres;

--
-- Name: goal_pledge_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.goal_pledge_status AS ENUM (
    'open',
    'matched',
    'cancelled',
    'expired'
);


ALTER TYPE public.goal_pledge_status OWNER TO postgres;

--
-- Name: current_family_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.current_family_id() RETURNS uuid
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN NULLIF(current_setting('app.current_family_id', true), '')::uuid;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.current_family_id() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_providers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    provider_type character varying NOT NULL,
    provider_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.account_providers OWNER TO postgres;

--
-- Name: account_shares; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account_shares (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    user_id uuid NOT NULL,
    permission character varying DEFAULT 'read_only'::character varying NOT NULL,
    include_in_finances boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_account_shares_permission CHECK (((permission)::text = ANY ((ARRAY['full_control'::character varying, 'read_write'::character varying, 'read_only'::character varying])::text[])))
);


ALTER TABLE public.account_shares OWNER TO postgres;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subtype character varying,
    family_id uuid NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    accountable_type character varying,
    accountable_id uuid,
    balance numeric(19,4),
    currency character varying,
    classification character varying GENERATED ALWAYS AS (
CASE
    WHEN ((accountable_type)::text = ANY ((ARRAY['Loan'::character varying, 'CreditCard'::character varying, 'OtherLiability'::character varying])::text[])) THEN 'liability'::text
    ELSE 'asset'::text
END) STORED,
    import_id uuid,
    plaid_account_id uuid,
    cash_balance numeric(19,4) DEFAULT 0.0,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    status character varying DEFAULT 'active'::character varying,
    simplefin_account_id uuid,
    institution_name character varying,
    institution_domain character varying,
    notes text,
    owner_id uuid
);

ALTER TABLE ONLY public.accounts FORCE ROW LEVEL SECURITY;


ALTER TABLE public.accounts OWNER TO postgres;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.active_storage_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id uuid NOT NULL,
    blob_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.active_storage_attachments OWNER TO postgres;

--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.active_storage_blobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.active_storage_blobs OWNER TO postgres;

--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.active_storage_variant_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blob_id uuid NOT NULL,
    variation_digest character varying NOT NULL
);


ALTER TABLE public.active_storage_variant_records OWNER TO postgres;

--
-- Name: addresses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    addressable_type character varying,
    addressable_id uuid,
    line1 character varying,
    line2 character varying,
    county character varying,
    locality character varying,
    region character varying,
    country character varying,
    postal_code character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.addresses OWNER TO postgres;

--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    user_id uuid NOT NULL,
    scopes json,
    last_used_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    display_key character varying NOT NULL,
    source character varying DEFAULT 'web'::character varying
);


ALTER TABLE public.api_keys OWNER TO postgres;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.ar_internal_metadata OWNER TO postgres;

--
-- Name: archived_exports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.archived_exports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying NOT NULL,
    family_name character varying,
    download_token_digest character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.archived_exports OWNER TO postgres;

--
-- Name: balances; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.balances (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    date date NOT NULL,
    balance numeric(19,4) NOT NULL,
    currency character varying DEFAULT 'USD'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    cash_balance numeric(19,4) DEFAULT 0.0,
    start_cash_balance numeric(19,4) DEFAULT 0.0 NOT NULL,
    start_non_cash_balance numeric(19,4) DEFAULT 0.0 NOT NULL,
    cash_inflows numeric(19,4) DEFAULT 0.0 NOT NULL,
    cash_outflows numeric(19,4) DEFAULT 0.0 NOT NULL,
    non_cash_inflows numeric(19,4) DEFAULT 0.0 NOT NULL,
    non_cash_outflows numeric(19,4) DEFAULT 0.0 NOT NULL,
    net_market_flows numeric(19,4) DEFAULT 0.0 NOT NULL,
    cash_adjustments numeric(19,4) DEFAULT 0.0 NOT NULL,
    non_cash_adjustments numeric(19,4) DEFAULT 0.0 NOT NULL,
    flows_factor integer DEFAULT 1 NOT NULL,
    start_balance numeric(19,4) GENERATED ALWAYS AS ((start_cash_balance + start_non_cash_balance)) STORED,
    end_cash_balance numeric(19,4) GENERATED ALWAYS AS (((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments)) STORED,
    end_non_cash_balance numeric(19,4) GENERATED ALWAYS AS ((((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments)) STORED,
    end_balance numeric(19,4) GENERATED ALWAYS AS ((((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments) + (((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments))) STORED
);


ALTER TABLE public.balances OWNER TO postgres;

--
-- Name: binance_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.binance_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    binance_item_id uuid NOT NULL,
    name character varying,
    account_type character varying,
    currency character varying,
    current_balance numeric(19,4),
    institution_metadata jsonb,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    extra jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.binance_accounts OWNER TO postgres;

--
-- Name: binance_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.binance_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    raw_payload jsonb,
    api_key text,
    api_secret text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.binance_items OWNER TO postgres;

--
-- Name: budget_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.budget_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    budget_id uuid NOT NULL,
    category_id uuid NOT NULL,
    budgeted_spending numeric(19,4) NOT NULL,
    currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.budget_categories FORCE ROW LEVEL SECURITY;


ALTER TABLE public.budget_categories OWNER TO postgres;

--
-- Name: budgets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.budgets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    budgeted_spending numeric(19,4),
    expected_income numeric(19,4),
    currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.budgets FORCE ROW LEVEL SECURITY;


ALTER TABLE public.budgets OWNER TO postgres;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    color character varying DEFAULT '#6172F3'::character varying NOT NULL,
    family_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    parent_id uuid,
    classification_unused character varying DEFAULT 'expense'::character varying NOT NULL,
    lucide_icon character varying DEFAULT 'shapes'::character varying NOT NULL
);

ALTER TABLE ONLY public.categories FORCE ROW LEVEL SECURITY;


ALTER TABLE public.categories OWNER TO postgres;

--
-- Name: chats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chats (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title character varying NOT NULL,
    instructions character varying,
    error jsonb,
    latest_assistant_response_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.chats OWNER TO postgres;

--
-- Name: coinbase_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coinbase_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    coinbase_item_id uuid NOT NULL,
    name character varying,
    account_id character varying,
    currency character varying,
    current_balance numeric(19,4),
    account_status character varying,
    account_type character varying,
    provider character varying,
    institution_metadata jsonb,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.coinbase_accounts OWNER TO postgres;

--
-- Name: coinbase_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coinbase_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    api_key text,
    api_secret text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.coinbase_items OWNER TO postgres;

--
-- Name: coinstats_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coinstats_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    coinstats_item_id uuid NOT NULL,
    name character varying,
    account_id character varying,
    currency character varying,
    current_balance numeric(19,4),
    account_status character varying,
    account_type character varying,
    provider character varying,
    institution_metadata jsonb,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    wallet_address character varying
);


ALTER TABLE public.coinstats_accounts OWNER TO postgres;

--
-- Name: coinstats_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coinstats_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    api_key character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    exchange_portfolio_id character varying,
    exchange_connection_id character varying
);


ALTER TABLE public.coinstats_items OWNER TO postgres;

--
-- Name: credit_cards; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.credit_cards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    available_credit numeric(10,2),
    minimum_payment numeric(10,2),
    apr numeric(10,2),
    expiration_date date,
    annual_fee numeric(10,2),
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.credit_cards OWNER TO postgres;

--
-- Name: cryptos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cryptos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying,
    tax_treatment character varying DEFAULT 'taxable'::character varying NOT NULL
);


ALTER TABLE public.cryptos OWNER TO postgres;

--
-- Name: data_enrichments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.data_enrichments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    enrichable_type character varying NOT NULL,
    enrichable_id uuid NOT NULL,
    source character varying,
    attribute_name character varying,
    value jsonb,
    metadata jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.data_enrichments OWNER TO postgres;

--
-- Name: depositories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.depositories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.depositories OWNER TO postgres;

--
-- Name: enable_banking_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enable_banking_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    enable_banking_item_id uuid NOT NULL,
    name character varying,
    account_id character varying,
    currency character varying,
    current_balance numeric(19,4),
    account_status character varying,
    account_type character varying,
    provider character varying,
    iban character varying,
    uid character varying,
    institution_metadata jsonb,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    product character varying,
    credit_limit numeric(19,4),
    identification_hashes jsonb DEFAULT '[]'::jsonb
);


ALTER TABLE public.enable_banking_accounts OWNER TO postgres;

--
-- Name: enable_banking_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.enable_banking_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date date,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    country_code character varying,
    application_id character varying,
    client_certificate text,
    session_id character varying,
    session_expires_at timestamp(6) without time zone,
    aspsp_name character varying,
    aspsp_id character varying,
    authorization_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    aspsp_required_psu_headers jsonb DEFAULT '[]'::jsonb,
    aspsp_maximum_consent_validity integer,
    aspsp_auth_approach character varying,
    aspsp_psu_types jsonb DEFAULT '[]'::jsonb,
    last_psu_ip character varying,
    psu_type character varying
);


ALTER TABLE public.enable_banking_items OWNER TO postgres;

--
-- Name: entries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    entryable_type character varying,
    entryable_id uuid,
    amount numeric(19,4) NOT NULL,
    currency character varying,
    date date,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    import_id uuid,
    notes text,
    excluded boolean DEFAULT false,
    plaid_id character varying,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    external_id character varying,
    source character varying,
    user_modified boolean DEFAULT false NOT NULL,
    import_locked boolean DEFAULT false NOT NULL,
    parent_entry_id uuid
);

ALTER TABLE ONLY public.entries FORCE ROW LEVEL SECURITY;


ALTER TABLE public.entries OWNER TO postgres;

--
-- Name: eval_datasets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eval_datasets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    description character varying,
    eval_type character varying NOT NULL,
    version character varying DEFAULT '1.0'::character varying NOT NULL,
    sample_count integer DEFAULT 0,
    metadata jsonb DEFAULT '{}'::jsonb,
    active boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.eval_datasets OWNER TO postgres;

--
-- Name: eval_results; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eval_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    eval_run_id uuid NOT NULL,
    eval_sample_id uuid NOT NULL,
    actual_output jsonb NOT NULL,
    correct boolean NOT NULL,
    exact_match boolean DEFAULT false,
    hierarchical_match boolean DEFAULT false,
    null_expected boolean DEFAULT false,
    null_returned boolean DEFAULT false,
    fuzzy_score double precision,
    latency_ms integer,
    prompt_tokens integer,
    completion_tokens integer,
    cost numeric(10,6),
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    alternative_match boolean DEFAULT false
);


ALTER TABLE public.eval_results OWNER TO postgres;

--
-- Name: eval_runs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eval_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    eval_dataset_id uuid NOT NULL,
    name character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    provider character varying NOT NULL,
    model character varying NOT NULL,
    provider_config jsonb DEFAULT '{}'::jsonb,
    metrics jsonb DEFAULT '{}'::jsonb,
    total_prompt_tokens integer DEFAULT 0,
    total_completion_tokens integer DEFAULT 0,
    total_cost numeric(10,6) DEFAULT 0.0,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.eval_runs OWNER TO postgres;

--
-- Name: eval_samples; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eval_samples (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    eval_dataset_id uuid NOT NULL,
    input_data jsonb NOT NULL,
    expected_output jsonb NOT NULL,
    context_data jsonb DEFAULT '{}'::jsonb,
    difficulty character varying DEFAULT 'medium'::character varying,
    tags character varying[] DEFAULT '{}'::character varying[],
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.eval_samples OWNER TO postgres;

--
-- Name: exchange_rate_pairs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.exchange_rate_pairs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    from_currency character varying NOT NULL,
    to_currency character varying NOT NULL,
    first_provider_rate_on date,
    provider_name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.exchange_rate_pairs OWNER TO postgres;

--
-- Name: exchange_rates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.exchange_rates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    from_currency character varying NOT NULL,
    to_currency character varying NOT NULL,
    rate numeric NOT NULL,
    date date NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.exchange_rates OWNER TO postgres;

--
-- Name: families; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.families (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    currency character varying DEFAULT 'USD'::character varying,
    locale character varying DEFAULT 'en'::character varying,
    stripe_customer_id character varying,
    date_format character varying DEFAULT '%m-%d-%Y'::character varying,
    country character varying DEFAULT 'US'::character varying,
    timezone character varying,
    data_enrichment_enabled boolean DEFAULT false,
    early_access boolean DEFAULT false,
    auto_sync_on_login boolean DEFAULT true NOT NULL,
    latest_sync_activity_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    latest_sync_completed_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP,
    recurring_transactions_disabled boolean DEFAULT false NOT NULL,
    month_start_day integer DEFAULT 1 NOT NULL,
    moniker character varying DEFAULT 'Family'::character varying NOT NULL,
    vector_store_id character varying,
    assistant_type character varying DEFAULT 'builtin'::character varying NOT NULL,
    default_account_sharing character varying DEFAULT 'shared'::character varying NOT NULL,
    enabled_currencies character varying[],
    business_mode_enabled boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_families_default_account_sharing CHECK (((default_account_sharing)::text = ANY ((ARRAY['shared'::character varying, 'private'::character varying])::text[]))),
    CONSTRAINT month_start_day_range CHECK (((month_start_day >= 1) AND (month_start_day <= 28)))
);


ALTER TABLE public.families OWNER TO postgres;

--
-- Name: family_documents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.family_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    file_size integer,
    provider_file_id character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.family_documents OWNER TO postgres;

--
-- Name: family_exports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.family_exports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.family_exports OWNER TO postgres;

--
-- Name: family_merchant_associations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.family_merchant_associations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    merchant_id uuid NOT NULL,
    unlinked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.family_merchant_associations OWNER TO postgres;

--
-- Name: fleet_vehicles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fleet_vehicles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    plate character varying NOT NULL,
    brand character varying NOT NULL,
    model character varying NOT NULL,
    year integer,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.fleet_vehicles FORCE ROW LEVEL SECURITY;


ALTER TABLE public.fleet_vehicles OWNER TO postgres;

--
-- Name: fuel_log_lines; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fuel_log_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fuel_log_id uuid NOT NULL,
    fuel_type character varying DEFAULT 'nafta'::character varying NOT NULL,
    liters numeric(10,2) NOT NULL,
    cost numeric(19,4) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    brand character varying
);

ALTER TABLE ONLY public.fuel_log_lines FORCE ROW LEVEL SECURITY;


ALTER TABLE public.fuel_log_lines OWNER TO postgres;

--
-- Name: fuel_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fuel_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    fleet_vehicle_id uuid NOT NULL,
    liters numeric(10,2) NOT NULL,
    cost numeric(19,4) NOT NULL,
    odometer integer,
    logged_at date NOT NULL,
    notes character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    account_id uuid NOT NULL,
    entry_id uuid
);

ALTER TABLE ONLY public.fuel_logs FORCE ROW LEVEL SECURITY;


ALTER TABLE public.fuel_logs OWNER TO postgres;

--
-- Name: goal_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goal_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    goal_id uuid NOT NULL,
    account_id uuid NOT NULL,
    allocated_amount numeric(19,4),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_goal_accounts_allocation_non_negative CHECK (((allocated_amount IS NULL) OR (allocated_amount >= (0)::numeric)))
);


ALTER TABLE public.goal_accounts OWNER TO postgres;

--
-- Name: goal_pledges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goal_pledges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    goal_id uuid NOT NULL,
    account_id uuid NOT NULL,
    amount numeric(19,4) NOT NULL,
    currency character varying NOT NULL,
    kind public.goal_pledge_kind NOT NULL,
    status public.goal_pledge_status DEFAULT 'open'::public.goal_pledge_status NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    matched_transaction_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_goal_pledges_amount_positive CHECK ((amount > (0)::numeric))
);


ALTER TABLE public.goal_pledges OWNER TO postgres;

--
-- Name: goals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.goals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying NOT NULL,
    target_amount numeric(19,4) NOT NULL,
    currency character varying NOT NULL,
    target_date date,
    color character varying,
    icon character varying,
    notes text,
    state character varying DEFAULT 'active'::character varying NOT NULL,
    progress_basis character varying DEFAULT 'balance'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_goals_name_length CHECK ((char_length((name)::text) <= 255)),
    CONSTRAINT chk_goals_progress_basis_enum CHECK (((progress_basis)::text = ANY ((ARRAY['balance'::character varying, 'contributions'::character varying])::text[]))),
    CONSTRAINT chk_goals_state_enum CHECK (((state)::text = ANY ((ARRAY['active'::character varying, 'paused'::character varying, 'completed'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT chk_goals_target_amount_positive CHECK ((target_amount > (0)::numeric))
);

ALTER TABLE ONLY public.goals FORCE ROW LEVEL SECURITY;


ALTER TABLE public.goals OWNER TO postgres;

--
-- Name: holdings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.holdings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    security_id uuid NOT NULL,
    date date NOT NULL,
    qty numeric(24,8) NOT NULL,
    price numeric(19,4) NOT NULL,
    amount numeric(19,4) NOT NULL,
    currency character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    external_id character varying,
    cost_basis numeric(19,4),
    account_provider_id uuid,
    cost_basis_source character varying,
    cost_basis_locked boolean DEFAULT false NOT NULL,
    provider_security_id uuid,
    security_locked boolean DEFAULT false NOT NULL
);


ALTER TABLE public.holdings OWNER TO postgres;

--
-- Name: impersonation_session_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.impersonation_session_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    impersonation_session_id uuid NOT NULL,
    controller character varying,
    action character varying,
    path text,
    method character varying,
    ip_address character varying,
    user_agent text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.impersonation_session_logs OWNER TO postgres;

--
-- Name: impersonation_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.impersonation_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    impersonator_id uuid NOT NULL,
    impersonated_id uuid NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.impersonation_sessions OWNER TO postgres;

--
-- Name: import_mappings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.import_mappings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type character varying NOT NULL,
    key character varying,
    value character varying,
    create_when_empty boolean DEFAULT true,
    import_id uuid NOT NULL,
    mappable_type character varying,
    mappable_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.import_mappings OWNER TO postgres;

--
-- Name: import_rows; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.import_rows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    import_id uuid NOT NULL,
    account character varying,
    date character varying,
    qty character varying,
    ticker character varying,
    price character varying,
    amount character varying,
    currency character varying,
    name character varying,
    category character varying,
    tags character varying,
    entity_type character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    category_parent character varying,
    category_color character varying,
    category_classification character varying,
    category_icon character varying,
    exchange_operating_mic character varying,
    resource_type character varying,
    active boolean,
    effective_date character varying,
    conditions text,
    actions text,
    source_row_number integer NOT NULL,
    CONSTRAINT chk_import_rows_source_row_number_positive CHECK ((source_row_number > 0))
);


ALTER TABLE public.import_rows OWNER TO postgres;

--
-- Name: imports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.imports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    column_mappings jsonb,
    status character varying,
    raw_file_str character varying,
    normalized_csv_str character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    col_sep character varying DEFAULT ','::character varying,
    family_id uuid NOT NULL,
    account_id uuid,
    type character varying NOT NULL,
    date_col_label character varying,
    amount_col_label character varying,
    name_col_label character varying,
    category_col_label character varying,
    tags_col_label character varying,
    account_col_label character varying,
    qty_col_label character varying,
    ticker_col_label character varying,
    price_col_label character varying,
    entity_type_col_label character varying,
    notes_col_label character varying,
    currency_col_label character varying,
    date_format character varying DEFAULT '%m/%d/%Y'::character varying,
    signage_convention character varying DEFAULT 'inflows_positive'::character varying,
    error character varying,
    number_format character varying,
    exchange_operating_mic_col_label character varying,
    amount_type_strategy character varying DEFAULT 'signed_amount'::character varying,
    amount_type_inflow_value character varying,
    rows_count integer DEFAULT 0 NOT NULL,
    amount_type_identifier_value character varying,
    rows_to_skip integer DEFAULT 0 NOT NULL,
    ai_summary text,
    document_type character varying,
    extracted_data jsonb
);


ALTER TABLE public.imports OWNER TO postgres;

--
-- Name: indexa_capital_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.indexa_capital_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    indexa_capital_item_id uuid NOT NULL,
    name character varying,
    indexa_capital_account_id character varying,
    account_number character varying,
    currency character varying,
    current_balance numeric(19,4),
    account_status character varying,
    account_type character varying,
    provider character varying,
    institution_metadata jsonb,
    raw_payload jsonb,
    indexa_capital_authorization_id character varying,
    cash_balance numeric(19,4) DEFAULT 0.0,
    raw_holdings_payload jsonb DEFAULT '[]'::jsonb,
    raw_activities_payload jsonb DEFAULT '[]'::jsonb,
    last_holdings_sync timestamp(6) without time zone,
    last_activities_sync timestamp(6) without time zone,
    activities_fetch_pending boolean DEFAULT false,
    sync_start_date date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.indexa_capital_accounts OWNER TO postgres;

--
-- Name: indexa_capital_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.indexa_capital_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    username character varying,
    document character varying,
    password text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    api_token text
);


ALTER TABLE public.indexa_capital_items OWNER TO postgres;

--
-- Name: investments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.investments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.investments OWNER TO postgres;

--
-- Name: invitations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying,
    role character varying,
    token character varying,
    family_id uuid NOT NULL,
    inviter_id uuid NOT NULL,
    accepted_at timestamp(6) without time zone,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    token_digest character varying
);


ALTER TABLE public.invitations OWNER TO postgres;

--
-- Name: invite_codes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invite_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    token character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    token_digest character varying
);


ALTER TABLE public.invite_codes OWNER TO postgres;

--
-- Name: llm_usages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_usages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    provider character varying NOT NULL,
    model character varying NOT NULL,
    operation character varying NOT NULL,
    prompt_tokens integer DEFAULT 0 NOT NULL,
    completion_tokens integer DEFAULT 0 NOT NULL,
    total_tokens integer DEFAULT 0 NOT NULL,
    estimated_cost numeric(10,6),
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.llm_usages OWNER TO postgres;

--
-- Name: loans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    rate_type character varying,
    interest_rate numeric(10,3),
    term_months integer,
    initial_balance numeric(19,4),
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.loans OWNER TO postgres;

--
-- Name: lunchflow_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lunchflow_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lunchflow_item_id uuid NOT NULL,
    name character varying,
    account_id character varying,
    currency character varying,
    current_balance numeric(19,4),
    account_status character varying,
    provider character varying,
    account_type character varying,
    institution_metadata jsonb,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    holdings_supported boolean DEFAULT true NOT NULL,
    raw_holdings_payload jsonb
);


ALTER TABLE public.lunchflow_accounts OWNER TO postgres;

--
-- Name: lunchflow_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lunchflow_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    api_key text,
    base_url character varying
);


ALTER TABLE public.lunchflow_items OWNER TO postgres;

--
-- Name: merchants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.merchants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    color character varying,
    family_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    logo_url character varying,
    website_url character varying,
    type character varying NOT NULL,
    source character varying,
    provider_merchant_id character varying
);

ALTER TABLE ONLY public.merchants FORCE ROW LEVEL SECURITY;


ALTER TABLE public.merchants OWNER TO postgres;

--
-- Name: mercury_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mercury_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    mercury_item_id uuid NOT NULL,
    name character varying,
    account_id character varying NOT NULL,
    currency character varying,
    current_balance numeric(19,4),
    account_status character varying,
    account_type character varying,
    provider character varying,
    institution_metadata jsonb,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.mercury_accounts OWNER TO postgres;

--
-- Name: mercury_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mercury_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    token text,
    base_url character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.mercury_items OWNER TO postgres;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chat_id uuid NOT NULL,
    type character varying NOT NULL,
    status character varying DEFAULT 'complete'::character varying NOT NULL,
    content text,
    ai_model character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    debug boolean DEFAULT false,
    provider_id character varying,
    reasoning boolean DEFAULT false
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- Name: mobile_devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mobile_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id character varying,
    device_name character varying,
    device_type character varying,
    os_version character varying,
    app_version character varying,
    last_seen_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.mobile_devices OWNER TO postgres;

--
-- Name: oauth_access_grants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.oauth_access_grants (
    id bigint NOT NULL,
    resource_owner_id character varying NOT NULL,
    application_id bigint NOT NULL,
    token character varying NOT NULL,
    expires_in integer NOT NULL,
    redirect_uri text NOT NULL,
    scopes character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone
);


ALTER TABLE public.oauth_access_grants OWNER TO postgres;

--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.oauth_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.oauth_access_grants_id_seq OWNER TO postgres;

--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.oauth_access_grants_id_seq OWNED BY public.oauth_access_grants.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.oauth_access_tokens (
    id bigint NOT NULL,
    resource_owner_id character varying,
    application_id bigint NOT NULL,
    token character varying NOT NULL,
    refresh_token character varying,
    expires_in integer,
    scopes character varying,
    created_at timestamp(6) without time zone NOT NULL,
    revoked_at timestamp(6) without time zone,
    previous_refresh_token character varying DEFAULT ''::character varying NOT NULL,
    mobile_device_id uuid
);


ALTER TABLE public.oauth_access_tokens OWNER TO postgres;

--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.oauth_access_tokens_id_seq OWNER TO postgres;

--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.oauth_access_tokens_id_seq OWNED BY public.oauth_access_tokens.id;


--
-- Name: oauth_applications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.oauth_applications (
    id bigint NOT NULL,
    name character varying NOT NULL,
    uid character varying NOT NULL,
    secret character varying NOT NULL,
    redirect_uri text NOT NULL,
    scopes character varying DEFAULT ''::character varying NOT NULL,
    confidential boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    owner_id uuid,
    owner_type character varying
);


ALTER TABLE public.oauth_applications OWNER TO postgres;

--
-- Name: oauth_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.oauth_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.oauth_applications_id_seq OWNER TO postgres;

--
-- Name: oauth_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.oauth_applications_id_seq OWNED BY public.oauth_applications.id;


--
-- Name: oidc_identities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.oidc_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    provider character varying NOT NULL,
    uid character varying NOT NULL,
    info jsonb DEFAULT '{}'::jsonb,
    last_authenticated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    issuer character varying
);


ALTER TABLE public.oidc_identities OWNER TO postgres;

--
-- Name: other_assets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.other_assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.other_assets OWNER TO postgres;

--
-- Name: other_liabilities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.other_liabilities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.other_liabilities OWNER TO postgres;

--
-- Name: plaid_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plaid_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plaid_item_id uuid NOT NULL,
    plaid_id character varying NOT NULL,
    plaid_type character varying NOT NULL,
    plaid_subtype character varying,
    current_balance numeric(19,4),
    available_balance numeric(19,4),
    currency character varying NOT NULL,
    name character varying NOT NULL,
    mask character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    raw_payload jsonb DEFAULT '{}'::jsonb,
    raw_transactions_payload jsonb DEFAULT '{}'::jsonb,
    raw_holdings_payload jsonb DEFAULT '{}'::jsonb,
    raw_liabilities_payload jsonb DEFAULT '{}'::jsonb
);


ALTER TABLE public.plaid_accounts OWNER TO postgres;

--
-- Name: plaid_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plaid_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    access_token character varying,
    plaid_id character varying NOT NULL,
    name character varying,
    next_cursor character varying,
    scheduled_for_deletion boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    available_products character varying[] DEFAULT '{}'::character varying[],
    billed_products character varying[] DEFAULT '{}'::character varying[],
    plaid_region character varying DEFAULT 'us'::character varying NOT NULL,
    institution_url character varying,
    institution_id character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying NOT NULL,
    raw_payload jsonb DEFAULT '{}'::jsonb,
    raw_institution_payload jsonb DEFAULT '{}'::jsonb
);


ALTER TABLE public.plaid_items OWNER TO postgres;

--
-- Name: product_stock_movements; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_stock_movements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    quantity_delta integer NOT NULL,
    reason character varying NOT NULL,
    note character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.product_stock_movements FORCE ROW LEVEL SECURITY;


ALTER TABLE public.product_stock_movements OWNER TO postgres;

--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying NOT NULL,
    sku character varying,
    category character varying,
    supplier character varying,
    buy_price numeric(19,4) DEFAULT 0.0,
    sell_price numeric(19,4) DEFAULT 0.0,
    currency character varying DEFAULT 'pyg'::character varying NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    min_stock integer DEFAULT 0 NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.products FORCE ROW LEVEL SECURITY;


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: properties; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.properties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    year_built integer,
    area_value integer,
    area_unit character varying,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.properties OWNER TO postgres;

--
-- Name: purchase_order_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase_order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    purchase_order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    unit_cost numeric(19,4) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.purchase_order_items FORCE ROW LEVEL SECURITY;


ALTER TABLE public.purchase_order_items OWNER TO postgres;

--
-- Name: purchase_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    order_number integer NOT NULL,
    supplier_name character varying,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    currency character varying DEFAULT 'pyg'::character varying NOT NULL,
    expected_date date,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.purchase_orders FORCE ROW LEVEL SECURITY;


ALTER TABLE public.purchase_orders OWNER TO postgres;

--
-- Name: receivables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.receivables (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    total_amount numeric(19,4),
    installment_count integer,
    due_day integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);

ALTER TABLE ONLY public.receivables FORCE ROW LEVEL SECURITY;


ALTER TABLE public.receivables OWNER TO postgres;

--
-- Name: recurring_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recurring_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    merchant_id uuid,
    amount numeric(19,4) NOT NULL,
    currency character varying NOT NULL,
    expected_day_of_month integer NOT NULL,
    last_occurrence_date date NOT NULL,
    next_expected_date date NOT NULL,
    status character varying DEFAULT 'active'::character varying NOT NULL,
    occurrence_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying,
    manual boolean DEFAULT false NOT NULL,
    expected_amount_min numeric(19,4),
    expected_amount_max numeric(19,4),
    expected_amount_avg numeric(19,4),
    account_id uuid
);

ALTER TABLE ONLY public.recurring_transactions FORCE ROW LEVEL SECURITY;


ALTER TABLE public.recurring_transactions OWNER TO postgres;

--
-- Name: rejected_transfers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rejected_transfers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    inflow_transaction_id uuid NOT NULL,
    outflow_transaction_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.rejected_transfers OWNER TO postgres;

--
-- Name: rule_actions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rule_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_id uuid NOT NULL,
    action_type character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.rule_actions OWNER TO postgres;

--
-- Name: rule_conditions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rule_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_id uuid,
    parent_id uuid,
    condition_type character varying NOT NULL,
    operator character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.rule_conditions OWNER TO postgres;

--
-- Name: rule_runs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rule_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_id uuid NOT NULL,
    rule_name character varying,
    execution_type character varying NOT NULL,
    status character varying NOT NULL,
    transactions_queued integer DEFAULT 0 NOT NULL,
    transactions_processed integer DEFAULT 0 NOT NULL,
    transactions_modified integer DEFAULT 0 NOT NULL,
    pending_jobs_count integer DEFAULT 0 NOT NULL,
    executed_at timestamp(6) without time zone NOT NULL,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.rule_runs OWNER TO postgres;

--
-- Name: rules; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    resource_type character varying NOT NULL,
    effective_date date,
    active boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying
);

ALTER TABLE ONLY public.rules FORCE ROW LEVEL SECURITY;


ALTER TABLE public.rules OWNER TO postgres;

--
-- Name: sale_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sale_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(19,4) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.sale_items FORCE ROW LEVEL SECURITY;


ALTER TABLE public.sale_items OWNER TO postgres;

--
-- Name: sales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    sale_number integer NOT NULL,
    client_name character varying,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    currency character varying DEFAULT 'pyg'::character varying NOT NULL,
    payment_method character varying,
    invoice_number character varying,
    condition character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    delivery_address text,
    delivery_date date,
    carrier character varying
);

ALTER TABLE ONLY public.sales FORCE ROW LEVEL SECURITY;


ALTER TABLE public.sales OWNER TO postgres;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO postgres;

--
-- Name: securities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.securities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ticker character varying NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    country_code character varying,
    exchange_mic character varying,
    exchange_acronym character varying,
    logo_url character varying,
    exchange_operating_mic character varying,
    offline boolean DEFAULT false NOT NULL,
    failed_fetch_at timestamp(6) without time zone,
    failed_fetch_count integer DEFAULT 0 NOT NULL,
    last_health_check_at timestamp(6) without time zone,
    website_url character varying,
    kind character varying DEFAULT 'standard'::character varying NOT NULL,
    price_provider character varying,
    offline_reason character varying,
    first_provider_price_on date,
    CONSTRAINT chk_securities_kind CHECK (((kind)::text = ANY ((ARRAY['standard'::character varying, 'cash'::character varying])::text[])))
);


ALTER TABLE public.securities OWNER TO postgres;

--
-- Name: security_prices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.security_prices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    date date NOT NULL,
    price numeric(19,4) NOT NULL,
    currency character varying DEFAULT 'USD'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    security_id uuid,
    provisional boolean DEFAULT false NOT NULL
);


ALTER TABLE public.security_prices OWNER TO postgres;

--
-- Name: sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    user_agent character varying,
    ip_address character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    active_impersonator_session_id uuid,
    subscribed_at timestamp(6) without time zone,
    prev_transaction_page_params jsonb DEFAULT '{}'::jsonb,
    data jsonb DEFAULT '{}'::jsonb,
    ip_address_digest character varying
);


ALTER TABLE public.sessions OWNER TO postgres;

--
-- Name: settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.settings (
    id bigint NOT NULL,
    var character varying NOT NULL,
    value text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.settings OWNER TO postgres;

--
-- Name: settings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.settings_id_seq OWNER TO postgres;

--
-- Name: settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.settings_id_seq OWNED BY public.settings.id;


--
-- Name: simplefin_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.simplefin_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    simplefin_item_id uuid NOT NULL,
    name character varying,
    account_id character varying,
    currency character varying,
    current_balance numeric(19,4),
    available_balance numeric(19,4),
    account_type character varying,
    account_subtype character varying,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    balance_date timestamp(6) without time zone,
    extra jsonb,
    org_data jsonb,
    raw_holdings_payload jsonb
);


ALTER TABLE public.simplefin_accounts OWNER TO postgres;

--
-- Name: simplefin_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.simplefin_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    access_url text,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_url character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pending_account_setup boolean DEFAULT false NOT NULL,
    institution_domain character varying,
    institution_color character varying,
    sync_start_date date
);


ALTER TABLE public.simplefin_items OWNER TO postgres;

--
-- Name: snaptrade_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.snaptrade_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    snaptrade_item_id uuid NOT NULL,
    name character varying,
    snaptrade_account_id character varying,
    snaptrade_authorization_id character varying,
    account_number character varying,
    brokerage_name character varying,
    currency character varying,
    current_balance numeric(19,4),
    cash_balance numeric(19,4),
    account_status character varying,
    account_type character varying,
    provider character varying,
    institution_metadata jsonb,
    raw_payload text,
    raw_transactions_payload text,
    raw_holdings_payload text DEFAULT '[]'::text,
    raw_activities_payload text DEFAULT '[]'::text,
    last_holdings_sync timestamp(6) without time zone,
    last_activities_sync timestamp(6) without time zone,
    activities_fetch_pending boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sync_start_date date
);


ALTER TABLE public.snaptrade_accounts OWNER TO postgres;

--
-- Name: snaptrade_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.snaptrade_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    last_synced_at timestamp(6) without time zone,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    client_id character varying,
    consumer_key character varying,
    snaptrade_user_id character varying,
    snaptrade_user_secret character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.snaptrade_items OWNER TO postgres;

--
-- Name: sophtron_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sophtron_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sophtron_item_id uuid NOT NULL,
    name character varying NOT NULL,
    account_id character varying NOT NULL,
    currency character varying,
    balance numeric(19,4),
    available_balance numeric(19,4),
    account_status character varying,
    account_type character varying,
    account_sub_type character varying,
    last_updated timestamp(6) without time zone,
    institution_metadata jsonb,
    raw_payload jsonb,
    raw_transactions_payload jsonb,
    customer_id character varying NOT NULL,
    member_id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.sophtron_accounts OWNER TO postgres;

--
-- Name: sophtron_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sophtron_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    name character varying,
    institution_id character varying,
    institution_name character varying,
    institution_domain character varying,
    institution_url character varying,
    institution_color character varying,
    status character varying DEFAULT 'good'::character varying,
    scheduled_for_deletion boolean DEFAULT false,
    pending_account_setup boolean DEFAULT false,
    sync_start_date timestamp(6) without time zone,
    raw_payload jsonb,
    raw_institution_payload jsonb,
    user_id character varying NOT NULL,
    access_key character varying NOT NULL,
    base_url character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.sophtron_items OWNER TO postgres;

--
-- Name: sso_audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sso_audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    event_type character varying NOT NULL,
    provider character varying,
    ip_address character varying,
    user_agent character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.sso_audit_logs OWNER TO postgres;

--
-- Name: sso_providers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sso_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    strategy character varying NOT NULL,
    name character varying NOT NULL,
    label character varying NOT NULL,
    icon character varying,
    enabled boolean DEFAULT true NOT NULL,
    issuer character varying,
    client_id character varying,
    client_secret character varying,
    redirect_uri character varying,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.sso_providers OWNER TO postgres;

--
-- Name: statement_imports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.statement_imports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    bank_name character varying,
    parsed_count integer DEFAULT 0,
    imported_count integer DEFAULT 0,
    raw_transactions jsonb DEFAULT '[]'::jsonb,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.statement_imports OWNER TO postgres;

--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    status character varying NOT NULL,
    stripe_id character varying,
    amount numeric(19,4),
    currency character varying,
    "interval" character varying,
    current_period_ends_at timestamp(6) without time zone,
    trial_ends_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    cancel_at_period_end boolean DEFAULT false NOT NULL
);


ALTER TABLE public.subscriptions OWNER TO postgres;

--
-- Name: syncs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.syncs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    syncable_type character varying NOT NULL,
    syncable_id uuid NOT NULL,
    status character varying DEFAULT 'pending'::character varying,
    error character varying,
    data jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    parent_id uuid,
    pending_at timestamp(6) without time zone,
    syncing_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    failed_at timestamp(6) without time zone,
    window_start_date date,
    window_end_date date,
    sync_stats text
);


ALTER TABLE public.syncs OWNER TO postgres;

--
-- Name: taggings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.taggings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tag_id uuid NOT NULL,
    taggable_type character varying,
    taggable_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.taggings OWNER TO postgres;

--
-- Name: tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    color character varying DEFAULT '#e99537'::character varying NOT NULL,
    family_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.tags FORCE ROW LEVEL SECURITY;


ALTER TABLE public.tags OWNER TO postgres;

--
-- Name: tool_calls; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tool_calls (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    message_id uuid NOT NULL,
    provider_id character varying NOT NULL,
    provider_call_id character varying,
    type character varying NOT NULL,
    function_name character varying,
    function_arguments jsonb,
    function_result jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.tool_calls OWNER TO postgres;

--
-- Name: trades; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trades (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    security_id uuid NOT NULL,
    qty numeric(24,8),
    price numeric(19,10),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    currency character varying,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    investment_activity_label character varying,
    fee numeric(19,4) DEFAULT 0.0 NOT NULL
);


ALTER TABLE public.trades OWNER TO postgres;

--
-- Name: transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    category_id uuid,
    merchant_id uuid,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    kind character varying DEFAULT 'standard'::character varying NOT NULL,
    external_id character varying,
    extra jsonb DEFAULT '{}'::jsonb NOT NULL,
    investment_activity_label character varying
);

ALTER TABLE ONLY public.transactions FORCE ROW LEVEL SECURITY;


ALTER TABLE public.transactions OWNER TO postgres;

--
-- Name: transfers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transfers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    inflow_transaction_id uuid NOT NULL,
    outflow_transaction_id uuid NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.transfers OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    family_id uuid NOT NULL,
    first_name character varying,
    last_name character varying,
    email character varying,
    password_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    onboarded_at timestamp(6) without time zone,
    unconfirmed_email character varying,
    otp_secret character varying,
    otp_required boolean DEFAULT false NOT NULL,
    otp_backup_codes character varying[] DEFAULT '{}'::character varying[],
    show_sidebar boolean DEFAULT true,
    default_period character varying DEFAULT 'last_30_days'::character varying NOT NULL,
    last_viewed_chat_id uuid,
    show_ai_sidebar boolean DEFAULT true,
    ai_enabled boolean DEFAULT false NOT NULL,
    theme character varying DEFAULT 'system'::character varying,
    rule_prompts_disabled boolean DEFAULT false,
    rule_prompt_dismissed_at timestamp(6) without time zone,
    goals text[] DEFAULT '{}'::text[],
    set_onboarding_preferences_at timestamp(6) without time zone,
    set_onboarding_goals_at timestamp(6) without time zone,
    default_account_order character varying DEFAULT 'name_asc'::character varying,
    ui_layout character varying,
    preferences jsonb DEFAULT '{}'::jsonb NOT NULL,
    locale character varying,
    default_account_id uuid,
    webauthn_id character varying
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: valuations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.valuations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    kind character varying DEFAULT 'reconciliation'::character varying NOT NULL
);

ALTER TABLE ONLY public.valuations FORCE ROW LEVEL SECURITY;


ALTER TABLE public.valuations OWNER TO postgres;

--
-- Name: vehicles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vehicles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    year integer,
    mileage_value integer,
    mileage_unit character varying,
    make character varying,
    model character varying,
    locked_attributes jsonb DEFAULT '{}'::jsonb,
    subtype character varying
);


ALTER TABLE public.vehicles OWNER TO postgres;

--
-- Name: webauthn_credentials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.webauthn_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    nickname character varying NOT NULL,
    credential_id character varying NOT NULL,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    transports character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    last_used_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_webauthn_credentials_sign_count_non_negative CHECK ((sign_count >= 0))
);


ALTER TABLE public.webauthn_credentials OWNER TO postgres;

--
-- Name: oauth_access_grants id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_access_grants ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_grants_id_seq'::regclass);


--
-- Name: oauth_access_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_tokens_id_seq'::regclass);


--
-- Name: oauth_applications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_applications ALTER COLUMN id SET DEFAULT nextval('public.oauth_applications_id_seq'::regclass);


--
-- Name: settings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.settings ALTER COLUMN id SET DEFAULT nextval('public.settings_id_seq'::regclass);


--
-- Name: account_providers account_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_providers
    ADD CONSTRAINT account_providers_pkey PRIMARY KEY (id);


--
-- Name: account_shares account_shares_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_shares
    ADD CONSTRAINT account_shares_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: archived_exports archived_exports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.archived_exports
    ADD CONSTRAINT archived_exports_pkey PRIMARY KEY (id);


--
-- Name: balances balances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT balances_pkey PRIMARY KEY (id);


--
-- Name: binance_accounts binance_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.binance_accounts
    ADD CONSTRAINT binance_accounts_pkey PRIMARY KEY (id);


--
-- Name: binance_items binance_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.binance_items
    ADD CONSTRAINT binance_items_pkey PRIMARY KEY (id);


--
-- Name: budget_categories budget_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.budget_categories
    ADD CONSTRAINT budget_categories_pkey PRIMARY KEY (id);


--
-- Name: budgets budgets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT budgets_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: chats chats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (id);


--
-- Name: coinbase_accounts coinbase_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinbase_accounts
    ADD CONSTRAINT coinbase_accounts_pkey PRIMARY KEY (id);


--
-- Name: coinbase_items coinbase_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinbase_items
    ADD CONSTRAINT coinbase_items_pkey PRIMARY KEY (id);


--
-- Name: coinstats_accounts coinstats_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinstats_accounts
    ADD CONSTRAINT coinstats_accounts_pkey PRIMARY KEY (id);


--
-- Name: coinstats_items coinstats_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinstats_items
    ADD CONSTRAINT coinstats_items_pkey PRIMARY KEY (id);


--
-- Name: credit_cards credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT credit_cards_pkey PRIMARY KEY (id);


--
-- Name: cryptos cryptos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cryptos
    ADD CONSTRAINT cryptos_pkey PRIMARY KEY (id);


--
-- Name: data_enrichments data_enrichments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.data_enrichments
    ADD CONSTRAINT data_enrichments_pkey PRIMARY KEY (id);


--
-- Name: depositories depositories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.depositories
    ADD CONSTRAINT depositories_pkey PRIMARY KEY (id);


--
-- Name: enable_banking_accounts enable_banking_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enable_banking_accounts
    ADD CONSTRAINT enable_banking_accounts_pkey PRIMARY KEY (id);


--
-- Name: enable_banking_items enable_banking_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enable_banking_items
    ADD CONSTRAINT enable_banking_items_pkey PRIMARY KEY (id);


--
-- Name: entries entries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


--
-- Name: eval_datasets eval_datasets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_datasets
    ADD CONSTRAINT eval_datasets_pkey PRIMARY KEY (id);


--
-- Name: eval_results eval_results_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_results
    ADD CONSTRAINT eval_results_pkey PRIMARY KEY (id);


--
-- Name: eval_runs eval_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_runs
    ADD CONSTRAINT eval_runs_pkey PRIMARY KEY (id);


--
-- Name: eval_samples eval_samples_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_samples
    ADD CONSTRAINT eval_samples_pkey PRIMARY KEY (id);


--
-- Name: exchange_rate_pairs exchange_rate_pairs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exchange_rate_pairs
    ADD CONSTRAINT exchange_rate_pairs_pkey PRIMARY KEY (id);


--
-- Name: exchange_rates exchange_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.exchange_rates
    ADD CONSTRAINT exchange_rates_pkey PRIMARY KEY (id);


--
-- Name: families families_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.families
    ADD CONSTRAINT families_pkey PRIMARY KEY (id);


--
-- Name: family_documents family_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_documents
    ADD CONSTRAINT family_documents_pkey PRIMARY KEY (id);


--
-- Name: family_exports family_exports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_exports
    ADD CONSTRAINT family_exports_pkey PRIMARY KEY (id);


--
-- Name: family_merchant_associations family_merchant_associations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_merchant_associations
    ADD CONSTRAINT family_merchant_associations_pkey PRIMARY KEY (id);


--
-- Name: fleet_vehicles fleet_vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fleet_vehicles
    ADD CONSTRAINT fleet_vehicles_pkey PRIMARY KEY (id);


--
-- Name: fuel_log_lines fuel_log_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_log_lines
    ADD CONSTRAINT fuel_log_lines_pkey PRIMARY KEY (id);


--
-- Name: fuel_logs fuel_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_logs
    ADD CONSTRAINT fuel_logs_pkey PRIMARY KEY (id);


--
-- Name: goal_accounts goal_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_accounts
    ADD CONSTRAINT goal_accounts_pkey PRIMARY KEY (id);


--
-- Name: goal_pledges goal_pledges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_pledges
    ADD CONSTRAINT goal_pledges_pkey PRIMARY KEY (id);


--
-- Name: goals goals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);


--
-- Name: holdings holdings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holdings
    ADD CONSTRAINT holdings_pkey PRIMARY KEY (id);


--
-- Name: impersonation_session_logs impersonation_session_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.impersonation_session_logs
    ADD CONSTRAINT impersonation_session_logs_pkey PRIMARY KEY (id);


--
-- Name: impersonation_sessions impersonation_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.impersonation_sessions
    ADD CONSTRAINT impersonation_sessions_pkey PRIMARY KEY (id);


--
-- Name: import_mappings import_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.import_mappings
    ADD CONSTRAINT import_mappings_pkey PRIMARY KEY (id);


--
-- Name: import_rows import_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.import_rows
    ADD CONSTRAINT import_rows_pkey PRIMARY KEY (id);


--
-- Name: imports imports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.imports
    ADD CONSTRAINT imports_pkey PRIMARY KEY (id);


--
-- Name: indexa_capital_accounts indexa_capital_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.indexa_capital_accounts
    ADD CONSTRAINT indexa_capital_accounts_pkey PRIMARY KEY (id);


--
-- Name: indexa_capital_items indexa_capital_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.indexa_capital_items
    ADD CONSTRAINT indexa_capital_items_pkey PRIMARY KEY (id);


--
-- Name: investments investments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.investments
    ADD CONSTRAINT investments_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: invite_codes invite_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invite_codes
    ADD CONSTRAINT invite_codes_pkey PRIMARY KEY (id);


--
-- Name: llm_usages llm_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_usages
    ADD CONSTRAINT llm_usages_pkey PRIMARY KEY (id);


--
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- Name: lunchflow_accounts lunchflow_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lunchflow_accounts
    ADD CONSTRAINT lunchflow_accounts_pkey PRIMARY KEY (id);


--
-- Name: lunchflow_items lunchflow_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lunchflow_items
    ADD CONSTRAINT lunchflow_items_pkey PRIMARY KEY (id);


--
-- Name: merchants merchants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.merchants
    ADD CONSTRAINT merchants_pkey PRIMARY KEY (id);


--
-- Name: mercury_accounts mercury_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mercury_accounts
    ADD CONSTRAINT mercury_accounts_pkey PRIMARY KEY (id);


--
-- Name: mercury_items mercury_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mercury_items
    ADD CONSTRAINT mercury_items_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: mobile_devices mobile_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mobile_devices
    ADD CONSTRAINT mobile_devices_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_grants oauth_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT oauth_access_grants_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_tokens oauth_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_applications oauth_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_applications
    ADD CONSTRAINT oauth_applications_pkey PRIMARY KEY (id);


--
-- Name: oidc_identities oidc_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oidc_identities
    ADD CONSTRAINT oidc_identities_pkey PRIMARY KEY (id);


--
-- Name: other_assets other_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.other_assets
    ADD CONSTRAINT other_assets_pkey PRIMARY KEY (id);


--
-- Name: other_liabilities other_liabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.other_liabilities
    ADD CONSTRAINT other_liabilities_pkey PRIMARY KEY (id);


--
-- Name: plaid_accounts plaid_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plaid_accounts
    ADD CONSTRAINT plaid_accounts_pkey PRIMARY KEY (id);


--
-- Name: plaid_items plaid_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plaid_items
    ADD CONSTRAINT plaid_items_pkey PRIMARY KEY (id);


--
-- Name: product_stock_movements product_stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_stock_movements
    ADD CONSTRAINT product_stock_movements_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (id);


--
-- Name: purchase_order_items purchase_order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT purchase_order_items_pkey PRIMARY KEY (id);


--
-- Name: purchase_orders purchase_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_pkey PRIMARY KEY (id);


--
-- Name: receivables receivables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receivables
    ADD CONSTRAINT receivables_pkey PRIMARY KEY (id);


--
-- Name: recurring_transactions recurring_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recurring_transactions
    ADD CONSTRAINT recurring_transactions_pkey PRIMARY KEY (id);


--
-- Name: rejected_transfers rejected_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rejected_transfers
    ADD CONSTRAINT rejected_transfers_pkey PRIMARY KEY (id);


--
-- Name: rule_actions rule_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rule_actions
    ADD CONSTRAINT rule_actions_pkey PRIMARY KEY (id);


--
-- Name: rule_conditions rule_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rule_conditions
    ADD CONSTRAINT rule_conditions_pkey PRIMARY KEY (id);


--
-- Name: rule_runs rule_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rule_runs
    ADD CONSTRAINT rule_runs_pkey PRIMARY KEY (id);


--
-- Name: rules rules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id);


--
-- Name: sale_items sale_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT sale_items_pkey PRIMARY KEY (id);


--
-- Name: sales sales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT sales_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: securities securities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.securities
    ADD CONSTRAINT securities_pkey PRIMARY KEY (id);


--
-- Name: security_prices security_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.security_prices
    ADD CONSTRAINT security_prices_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (id);


--
-- Name: simplefin_accounts simplefin_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simplefin_accounts
    ADD CONSTRAINT simplefin_accounts_pkey PRIMARY KEY (id);


--
-- Name: simplefin_items simplefin_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simplefin_items
    ADD CONSTRAINT simplefin_items_pkey PRIMARY KEY (id);


--
-- Name: snaptrade_accounts snaptrade_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snaptrade_accounts
    ADD CONSTRAINT snaptrade_accounts_pkey PRIMARY KEY (id);


--
-- Name: snaptrade_items snaptrade_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snaptrade_items
    ADD CONSTRAINT snaptrade_items_pkey PRIMARY KEY (id);


--
-- Name: sophtron_accounts sophtron_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sophtron_accounts
    ADD CONSTRAINT sophtron_accounts_pkey PRIMARY KEY (id);


--
-- Name: sophtron_items sophtron_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sophtron_items
    ADD CONSTRAINT sophtron_items_pkey PRIMARY KEY (id);


--
-- Name: sso_audit_logs sso_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sso_audit_logs
    ADD CONSTRAINT sso_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: statement_imports statement_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.statement_imports
    ADD CONSTRAINT statement_imports_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: syncs syncs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.syncs
    ADD CONSTRAINT syncs_pkey PRIMARY KEY (id);


--
-- Name: taggings taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.taggings
    ADD CONSTRAINT taggings_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: tool_calls tool_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tool_calls
    ADD CONSTRAINT tool_calls_pkey PRIMARY KEY (id);


--
-- Name: trades trades_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trades
    ADD CONSTRAINT trades_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: transfers transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT transfers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: valuations valuations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valuations
    ADD CONSTRAINT valuations_pkey PRIMARY KEY (id);


--
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (id);


--
-- Name: webauthn_credentials webauthn_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.webauthn_credentials
    ADD CONSTRAINT webauthn_credentials_pkey PRIMARY KEY (id);


--
-- Name: idx_holdings_on_account_id_external_id_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_holdings_on_account_id_external_id_unique ON public.holdings USING btree (account_id, external_id) WHERE (external_id IS NOT NULL);


--
-- Name: idx_on_account_id_security_id_date_currency_5323e39f8b; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_on_account_id_security_id_date_currency_5323e39f8b ON public.holdings USING btree (account_id, security_id, date, currency);


--
-- Name: idx_on_enrichable_id_enrichable_type_source_attribu_5be5f63e08; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_on_enrichable_id_enrichable_type_source_attribu_5be5f63e08 ON public.data_enrichments USING btree (enrichable_id, enrichable_type, source, attribute_name);


--
-- Name: idx_on_family_id_merchant_id_23e883e08f; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_on_family_id_merchant_id_23e883e08f ON public.family_merchant_associations USING btree (family_id, merchant_id);


--
-- Name: idx_on_indexa_capital_authorization_id_58db208d52; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_on_indexa_capital_authorization_id_58db208d52 ON public.indexa_capital_accounts USING btree (indexa_capital_authorization_id);


--
-- Name: idx_on_inflow_transaction_id_outflow_transaction_id_412f8e7e26; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_on_inflow_transaction_id_outflow_transaction_id_412f8e7e26 ON public.rejected_transfers USING btree (inflow_transaction_id, outflow_transaction_id);


--
-- Name: idx_on_inflow_transaction_id_outflow_transaction_id_8cd07a28bd; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_on_inflow_transaction_id_outflow_transaction_id_8cd07a28bd ON public.transfers USING btree (inflow_transaction_id, outflow_transaction_id);


--
-- Name: idx_recurring_txns_acct_merchant; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_recurring_txns_acct_merchant ON public.recurring_transactions USING btree (family_id, account_id, merchant_id, amount, currency) WHERE (merchant_id IS NOT NULL);


--
-- Name: idx_recurring_txns_acct_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_recurring_txns_acct_name ON public.recurring_transactions USING btree (family_id, account_id, name, amount, currency) WHERE ((name IS NOT NULL) AND (merchant_id IS NULL));


--
-- Name: idx_unique_sfa_per_item_and_upstream; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unique_sfa_per_item_and_upstream ON public.simplefin_accounts USING btree (simplefin_item_id, account_id) WHERE (account_id IS NOT NULL);


--
-- Name: idx_unique_sophtron_accounts_per_item; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unique_sophtron_accounts_per_item ON public.sophtron_accounts USING btree (sophtron_item_id, account_id);


--
-- Name: index_account_balances_on_account_id_date_currency_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_account_balances_on_account_id_date_currency_unique ON public.balances USING btree (account_id, date, currency);


--
-- Name: index_account_providers_on_account_and_provider_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_account_providers_on_account_and_provider_type ON public.account_providers USING btree (account_id, provider_type);


--
-- Name: index_account_providers_on_provider_type_and_provider_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_account_providers_on_provider_type_and_provider_id ON public.account_providers USING btree (provider_type, provider_id);


--
-- Name: index_account_shares_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_account_shares_on_account_id ON public.account_shares USING btree (account_id);


--
-- Name: index_account_shares_on_account_id_and_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_account_shares_on_account_id_and_user_id ON public.account_shares USING btree (account_id, user_id);


--
-- Name: index_account_shares_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_account_shares_on_user_id ON public.account_shares USING btree (user_id);


--
-- Name: index_account_shares_on_user_id_and_include_in_finances; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_account_shares_on_user_id_and_include_in_finances ON public.account_shares USING btree (user_id, include_in_finances);


--
-- Name: index_accounts_on_accountable_id_and_accountable_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_accountable_id_and_accountable_type ON public.accounts USING btree (accountable_id, accountable_type);


--
-- Name: index_accounts_on_accountable_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_accountable_type ON public.accounts USING btree (accountable_type);


--
-- Name: index_accounts_on_currency; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_currency ON public.accounts USING btree (currency);


--
-- Name: index_accounts_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_family_id ON public.accounts USING btree (family_id);


--
-- Name: index_accounts_on_family_id_and_accountable_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_family_id_and_accountable_type ON public.accounts USING btree (family_id, accountable_type);


--
-- Name: index_accounts_on_family_id_and_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_family_id_and_id ON public.accounts USING btree (family_id, id);


--
-- Name: index_accounts_on_family_id_and_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_family_id_and_status ON public.accounts USING btree (family_id, status);


--
-- Name: index_accounts_on_family_id_status_accountable_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_family_id_status_accountable_type ON public.accounts USING btree (family_id, status, accountable_type);


--
-- Name: index_accounts_on_import_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_import_id ON public.accounts USING btree (import_id);


--
-- Name: index_accounts_on_owner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_owner_id ON public.accounts USING btree (owner_id);


--
-- Name: index_accounts_on_plaid_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_plaid_account_id ON public.accounts USING btree (plaid_account_id);


--
-- Name: index_accounts_on_simplefin_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_simplefin_account_id ON public.accounts USING btree (simplefin_account_id);


--
-- Name: index_accounts_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_accounts_on_status ON public.accounts USING btree (status);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_addresses_on_addressable; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_addresses_on_addressable ON public.addresses USING btree (addressable_type, addressable_id);


--
-- Name: index_api_keys_on_display_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_api_keys_on_display_key ON public.api_keys USING btree (display_key);


--
-- Name: index_api_keys_on_revoked_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_api_keys_on_revoked_at ON public.api_keys USING btree (revoked_at);


--
-- Name: index_api_keys_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_api_keys_on_user_id ON public.api_keys USING btree (user_id);


--
-- Name: index_api_keys_on_user_id_and_source; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_api_keys_on_user_id_and_source ON public.api_keys USING btree (user_id, source);


--
-- Name: index_archived_exports_on_download_token_digest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_archived_exports_on_download_token_digest ON public.archived_exports USING btree (download_token_digest);


--
-- Name: index_archived_exports_on_expires_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_archived_exports_on_expires_at ON public.archived_exports USING btree (expires_at);


--
-- Name: index_balances_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_balances_on_account_id ON public.balances USING btree (account_id);


--
-- Name: index_balances_on_account_id_and_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_balances_on_account_id_and_date ON public.balances USING btree (account_id, date DESC);


--
-- Name: index_binance_accounts_on_account_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_binance_accounts_on_account_type ON public.binance_accounts USING btree (account_type);


--
-- Name: index_binance_accounts_on_binance_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_binance_accounts_on_binance_item_id ON public.binance_accounts USING btree (binance_item_id);


--
-- Name: index_binance_accounts_on_item_and_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_binance_accounts_on_item_and_type ON public.binance_accounts USING btree (binance_item_id, account_type);


--
-- Name: index_binance_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_binance_items_on_family_id ON public.binance_items USING btree (family_id);


--
-- Name: index_binance_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_binance_items_on_status ON public.binance_items USING btree (status);


--
-- Name: index_budget_categories_on_budget_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_budget_categories_on_budget_id ON public.budget_categories USING btree (budget_id);


--
-- Name: index_budget_categories_on_budget_id_and_category_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_budget_categories_on_budget_id_and_category_id ON public.budget_categories USING btree (budget_id, category_id);


--
-- Name: index_budget_categories_on_category_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_budget_categories_on_category_id ON public.budget_categories USING btree (category_id);


--
-- Name: index_budgets_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_budgets_on_family_id ON public.budgets USING btree (family_id);


--
-- Name: index_budgets_on_family_id_and_start_date_and_end_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_budgets_on_family_id_and_start_date_and_end_date ON public.budgets USING btree (family_id, start_date, end_date);


--
-- Name: index_categories_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_categories_on_family_id ON public.categories USING btree (family_id);


--
-- Name: index_chats_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_chats_on_user_id ON public.chats USING btree (user_id);


--
-- Name: index_coinbase_accounts_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinbase_accounts_on_account_id ON public.coinbase_accounts USING btree (account_id);


--
-- Name: index_coinbase_accounts_on_coinbase_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinbase_accounts_on_coinbase_item_id ON public.coinbase_accounts USING btree (coinbase_item_id);


--
-- Name: index_coinbase_accounts_on_item_and_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_coinbase_accounts_on_item_and_account_id ON public.coinbase_accounts USING btree (coinbase_item_id, account_id) WHERE (account_id IS NOT NULL);


--
-- Name: index_coinbase_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinbase_items_on_family_id ON public.coinbase_items USING btree (family_id);


--
-- Name: index_coinbase_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinbase_items_on_status ON public.coinbase_items USING btree (status);


--
-- Name: index_coinstats_accounts_on_coinstats_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinstats_accounts_on_coinstats_item_id ON public.coinstats_accounts USING btree (coinstats_item_id);


--
-- Name: index_coinstats_accounts_on_item_account_and_wallet; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_coinstats_accounts_on_item_account_and_wallet ON public.coinstats_accounts USING btree (coinstats_item_id, account_id, wallet_address);


--
-- Name: index_coinstats_items_on_exchange_connection_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinstats_items_on_exchange_connection_id ON public.coinstats_items USING btree (exchange_connection_id);


--
-- Name: index_coinstats_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinstats_items_on_family_id ON public.coinstats_items USING btree (family_id);


--
-- Name: index_coinstats_items_on_family_id_and_exchange_portfolio_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_coinstats_items_on_family_id_and_exchange_portfolio_id ON public.coinstats_items USING btree (family_id, exchange_portfolio_id) WHERE (exchange_portfolio_id IS NOT NULL);


--
-- Name: index_coinstats_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_coinstats_items_on_status ON public.coinstats_items USING btree (status);


--
-- Name: index_data_enrichments_on_enrichable; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_data_enrichments_on_enrichable ON public.data_enrichments USING btree (enrichable_type, enrichable_id);


--
-- Name: index_enable_banking_accounts_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_enable_banking_accounts_on_account_id ON public.enable_banking_accounts USING btree (account_id);


--
-- Name: index_enable_banking_accounts_on_enable_banking_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_enable_banking_accounts_on_enable_banking_item_id ON public.enable_banking_accounts USING btree (enable_banking_item_id);


--
-- Name: index_enable_banking_accounts_on_identification_hashes; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_enable_banking_accounts_on_identification_hashes ON public.enable_banking_accounts USING gin (identification_hashes);


--
-- Name: index_enable_banking_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_enable_banking_items_on_family_id ON public.enable_banking_items USING btree (family_id);


--
-- Name: index_enable_banking_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_enable_banking_items_on_status ON public.enable_banking_items USING btree (status);


--
-- Name: index_entries_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_account_id ON public.entries USING btree (account_id);


--
-- Name: index_entries_on_account_id_and_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_account_id_and_date ON public.entries USING btree (account_id, date);


--
-- Name: index_entries_on_account_source_and_external_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_entries_on_account_source_and_external_id ON public.entries USING btree (account_id, source, external_id) WHERE ((external_id IS NOT NULL) AND (source IS NOT NULL));


--
-- Name: index_entries_on_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_date ON public.entries USING btree (date);


--
-- Name: index_entries_on_entryable_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_entryable_type ON public.entries USING btree (entryable_type);


--
-- Name: index_entries_on_import_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_import_id ON public.entries USING btree (import_id);


--
-- Name: index_entries_on_import_locked_true; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_import_locked_true ON public.entries USING btree (import_locked) WHERE (import_locked = true);


--
-- Name: index_entries_on_lower_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_lower_name ON public.entries USING btree (lower((name)::text));


--
-- Name: index_entries_on_parent_entry_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_parent_entry_id ON public.entries USING btree (parent_entry_id);


--
-- Name: index_entries_on_user_modified_true; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_entries_on_user_modified_true ON public.entries USING btree (user_modified) WHERE (user_modified = true);


--
-- Name: index_eval_datasets_on_eval_type_and_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_datasets_on_eval_type_and_active ON public.eval_datasets USING btree (eval_type, active);


--
-- Name: index_eval_datasets_on_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_eval_datasets_on_name ON public.eval_datasets USING btree (name);


--
-- Name: index_eval_results_on_eval_run_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_results_on_eval_run_id ON public.eval_results USING btree (eval_run_id);


--
-- Name: index_eval_results_on_eval_run_id_and_correct; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_results_on_eval_run_id_and_correct ON public.eval_results USING btree (eval_run_id, correct);


--
-- Name: index_eval_results_on_eval_sample_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_results_on_eval_sample_id ON public.eval_results USING btree (eval_sample_id);


--
-- Name: index_eval_runs_on_eval_dataset_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_runs_on_eval_dataset_id ON public.eval_runs USING btree (eval_dataset_id);


--
-- Name: index_eval_runs_on_eval_dataset_id_and_model; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_runs_on_eval_dataset_id_and_model ON public.eval_runs USING btree (eval_dataset_id, model);


--
-- Name: index_eval_runs_on_provider_and_model; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_runs_on_provider_and_model ON public.eval_runs USING btree (provider, model);


--
-- Name: index_eval_runs_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_runs_on_status ON public.eval_runs USING btree (status);


--
-- Name: index_eval_samples_on_eval_dataset_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_samples_on_eval_dataset_id ON public.eval_samples USING btree (eval_dataset_id);


--
-- Name: index_eval_samples_on_eval_dataset_id_and_difficulty; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_samples_on_eval_dataset_id_and_difficulty ON public.eval_samples USING btree (eval_dataset_id, difficulty);


--
-- Name: index_eval_samples_on_tags; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_eval_samples_on_tags ON public.eval_samples USING gin (tags);


--
-- Name: index_exchange_rate_pairs_on_pair_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_exchange_rate_pairs_on_pair_unique ON public.exchange_rate_pairs USING btree (from_currency, to_currency);


--
-- Name: index_exchange_rates_on_base_converted_date_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_exchange_rates_on_base_converted_date_unique ON public.exchange_rates USING btree (from_currency, to_currency, date);


--
-- Name: index_exchange_rates_on_from_currency; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_exchange_rates_on_from_currency ON public.exchange_rates USING btree (from_currency);


--
-- Name: index_exchange_rates_on_to_currency; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_exchange_rates_on_to_currency ON public.exchange_rates USING btree (to_currency);


--
-- Name: index_family_documents_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_family_documents_on_family_id ON public.family_documents USING btree (family_id);


--
-- Name: index_family_documents_on_provider_file_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_family_documents_on_provider_file_id ON public.family_documents USING btree (provider_file_id);


--
-- Name: index_family_documents_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_family_documents_on_status ON public.family_documents USING btree (status);


--
-- Name: index_family_exports_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_family_exports_on_family_id ON public.family_exports USING btree (family_id);


--
-- Name: index_family_merchant_associations_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_family_merchant_associations_on_family_id ON public.family_merchant_associations USING btree (family_id);


--
-- Name: index_family_merchant_associations_on_merchant_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_family_merchant_associations_on_merchant_id ON public.family_merchant_associations USING btree (merchant_id);


--
-- Name: index_fleet_vehicles_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_fleet_vehicles_on_family_id ON public.fleet_vehicles USING btree (family_id);


--
-- Name: index_fleet_vehicles_on_family_id_and_plate; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_fleet_vehicles_on_family_id_and_plate ON public.fleet_vehicles USING btree (family_id, plate);


--
-- Name: index_fuel_log_lines_on_fuel_log_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_fuel_log_lines_on_fuel_log_id ON public.fuel_log_lines USING btree (fuel_log_id);


--
-- Name: index_fuel_logs_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_fuel_logs_on_account_id ON public.fuel_logs USING btree (account_id);


--
-- Name: index_fuel_logs_on_entry_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_fuel_logs_on_entry_id ON public.fuel_logs USING btree (entry_id);


--
-- Name: index_fuel_logs_on_fleet_vehicle_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_fuel_logs_on_fleet_vehicle_id ON public.fuel_logs USING btree (fleet_vehicle_id);


--
-- Name: index_goal_accounts_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goal_accounts_on_account_id ON public.goal_accounts USING btree (account_id);


--
-- Name: index_goal_accounts_on_goal_and_account; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_goal_accounts_on_goal_and_account ON public.goal_accounts USING btree (goal_id, account_id);


--
-- Name: index_goal_accounts_on_goal_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goal_accounts_on_goal_id ON public.goal_accounts USING btree (goal_id);


--
-- Name: index_goal_pledges_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goal_pledges_on_account_id ON public.goal_pledges USING btree (account_id);


--
-- Name: index_goal_pledges_on_goal_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goal_pledges_on_goal_id ON public.goal_pledges USING btree (goal_id);


--
-- Name: index_goal_pledges_on_goal_id_and_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goal_pledges_on_goal_id_and_status ON public.goal_pledges USING btree (goal_id, status);


--
-- Name: index_goal_pledges_on_matched_transaction_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_goal_pledges_on_matched_transaction_id ON public.goal_pledges USING btree (matched_transaction_id) WHERE (matched_transaction_id IS NOT NULL);


--
-- Name: index_goal_pledges_open_by_expiry; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goal_pledges_open_by_expiry ON public.goal_pledges USING btree (status, expires_at) WHERE (status = 'open'::public.goal_pledge_status);


--
-- Name: index_goals_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goals_on_family_id ON public.goals USING btree (family_id);


--
-- Name: index_goals_on_family_id_and_state; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_goals_on_family_id_and_state ON public.goals USING btree (family_id, state);


--
-- Name: index_holdings_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_holdings_on_account_id ON public.holdings USING btree (account_id);


--
-- Name: index_holdings_on_account_provider_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_holdings_on_account_provider_id ON public.holdings USING btree (account_provider_id);


--
-- Name: index_holdings_on_provider_security_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_holdings_on_provider_security_id ON public.holdings USING btree (provider_security_id);


--
-- Name: index_holdings_on_security_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_holdings_on_security_id ON public.holdings USING btree (security_id);


--
-- Name: index_impersonation_session_logs_on_impersonation_session_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_impersonation_session_logs_on_impersonation_session_id ON public.impersonation_session_logs USING btree (impersonation_session_id);


--
-- Name: index_impersonation_sessions_on_impersonated_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_impersonation_sessions_on_impersonated_id ON public.impersonation_sessions USING btree (impersonated_id);


--
-- Name: index_impersonation_sessions_on_impersonator_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_impersonation_sessions_on_impersonator_id ON public.impersonation_sessions USING btree (impersonator_id);


--
-- Name: index_import_mappings_on_import_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_import_mappings_on_import_id ON public.import_mappings USING btree (import_id);


--
-- Name: index_import_mappings_on_mappable; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_import_mappings_on_mappable ON public.import_mappings USING btree (mappable_type, mappable_id);


--
-- Name: index_import_rows_on_import_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_import_rows_on_import_id ON public.import_rows USING btree (import_id);


--
-- Name: index_import_rows_on_import_id_and_source_row_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_import_rows_on_import_id_and_source_row_number ON public.import_rows USING btree (import_id, source_row_number);


--
-- Name: index_imports_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_imports_on_family_id ON public.imports USING btree (family_id);


--
-- Name: index_indexa_capital_accounts_on_indexa_capital_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_indexa_capital_accounts_on_indexa_capital_item_id ON public.indexa_capital_accounts USING btree (indexa_capital_item_id);


--
-- Name: index_indexa_capital_accounts_on_item_and_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_indexa_capital_accounts_on_item_and_account_id ON public.indexa_capital_accounts USING btree (indexa_capital_item_id, indexa_capital_account_id) WHERE (indexa_capital_account_id IS NOT NULL);


--
-- Name: index_indexa_capital_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_indexa_capital_items_on_family_id ON public.indexa_capital_items USING btree (family_id);


--
-- Name: index_indexa_capital_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_indexa_capital_items_on_status ON public.indexa_capital_items USING btree (status);


--
-- Name: index_invitations_on_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_invitations_on_email ON public.invitations USING btree (email);


--
-- Name: index_invitations_on_email_and_family_id_pending; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_invitations_on_email_and_family_id_pending ON public.invitations USING btree (email, family_id) WHERE (accepted_at IS NULL);


--
-- Name: index_invitations_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_invitations_on_family_id ON public.invitations USING btree (family_id);


--
-- Name: index_invitations_on_inviter_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_invitations_on_inviter_id ON public.invitations USING btree (inviter_id);


--
-- Name: index_invitations_on_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_invitations_on_token ON public.invitations USING btree (token);


--
-- Name: index_invitations_on_token_digest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_invitations_on_token_digest ON public.invitations USING btree (token_digest) WHERE (token_digest IS NOT NULL);


--
-- Name: index_invite_codes_on_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_invite_codes_on_token ON public.invite_codes USING btree (token);


--
-- Name: index_invite_codes_on_token_digest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_invite_codes_on_token_digest ON public.invite_codes USING btree (token_digest) WHERE (token_digest IS NOT NULL);


--
-- Name: index_llm_usages_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_llm_usages_on_family_id ON public.llm_usages USING btree (family_id);


--
-- Name: index_llm_usages_on_family_id_and_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_llm_usages_on_family_id_and_created_at ON public.llm_usages USING btree (family_id, created_at);


--
-- Name: index_llm_usages_on_family_id_and_operation; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_llm_usages_on_family_id_and_operation ON public.llm_usages USING btree (family_id, operation);


--
-- Name: index_lunchflow_accounts_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_lunchflow_accounts_on_account_id ON public.lunchflow_accounts USING btree (account_id);


--
-- Name: index_lunchflow_accounts_on_item_and_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_lunchflow_accounts_on_item_and_account_id ON public.lunchflow_accounts USING btree (lunchflow_item_id, account_id) WHERE (account_id IS NOT NULL);


--
-- Name: index_lunchflow_accounts_on_lunchflow_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_lunchflow_accounts_on_lunchflow_item_id ON public.lunchflow_accounts USING btree (lunchflow_item_id);


--
-- Name: index_lunchflow_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_lunchflow_items_on_family_id ON public.lunchflow_items USING btree (family_id);


--
-- Name: index_lunchflow_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_lunchflow_items_on_status ON public.lunchflow_items USING btree (status);


--
-- Name: index_merchants_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_merchants_on_family_id ON public.merchants USING btree (family_id);


--
-- Name: index_merchants_on_family_id_and_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_merchants_on_family_id_and_name ON public.merchants USING btree (family_id, name) WHERE ((type)::text = 'FamilyMerchant'::text);


--
-- Name: index_merchants_on_provider_merchant_id_and_source; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_merchants_on_provider_merchant_id_and_source ON public.merchants USING btree (provider_merchant_id, source) WHERE ((provider_merchant_id IS NOT NULL) AND ((type)::text = 'ProviderMerchant'::text));


--
-- Name: index_merchants_on_source_and_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_merchants_on_source_and_name ON public.merchants USING btree (source, name) WHERE ((type)::text = 'ProviderMerchant'::text);


--
-- Name: index_merchants_on_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_merchants_on_type ON public.merchants USING btree (type);


--
-- Name: index_mercury_accounts_on_item_and_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_mercury_accounts_on_item_and_account_id ON public.mercury_accounts USING btree (mercury_item_id, account_id);


--
-- Name: index_mercury_accounts_on_mercury_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_mercury_accounts_on_mercury_item_id ON public.mercury_accounts USING btree (mercury_item_id);


--
-- Name: index_mercury_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_mercury_items_on_family_id ON public.mercury_items USING btree (family_id);


--
-- Name: index_mercury_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_mercury_items_on_status ON public.mercury_items USING btree (status);


--
-- Name: index_messages_on_chat_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_messages_on_chat_id ON public.messages USING btree (chat_id);


--
-- Name: index_mobile_devices_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_mobile_devices_on_user_id ON public.mobile_devices USING btree (user_id);


--
-- Name: index_mobile_devices_on_user_id_and_device_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_mobile_devices_on_user_id_and_device_id ON public.mobile_devices USING btree (user_id, device_id);


--
-- Name: index_oauth_access_grants_on_application_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oauth_access_grants_on_application_id ON public.oauth_access_grants USING btree (application_id);


--
-- Name: index_oauth_access_grants_on_resource_owner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oauth_access_grants_on_resource_owner_id ON public.oauth_access_grants USING btree (resource_owner_id);


--
-- Name: index_oauth_access_grants_on_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_oauth_access_grants_on_token ON public.oauth_access_grants USING btree (token);


--
-- Name: index_oauth_access_tokens_on_application_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oauth_access_tokens_on_application_id ON public.oauth_access_tokens USING btree (application_id);


--
-- Name: index_oauth_access_tokens_on_mobile_device_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oauth_access_tokens_on_mobile_device_id ON public.oauth_access_tokens USING btree (mobile_device_id);


--
-- Name: index_oauth_access_tokens_on_refresh_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_refresh_token ON public.oauth_access_tokens USING btree (refresh_token);


--
-- Name: index_oauth_access_tokens_on_resource_owner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oauth_access_tokens_on_resource_owner_id ON public.oauth_access_tokens USING btree (resource_owner_id);


--
-- Name: index_oauth_access_tokens_on_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_token ON public.oauth_access_tokens USING btree (token);


--
-- Name: index_oauth_applications_on_owner_id_and_owner_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oauth_applications_on_owner_id_and_owner_type ON public.oauth_applications USING btree (owner_id, owner_type);


--
-- Name: index_oauth_applications_on_uid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_oauth_applications_on_uid ON public.oauth_applications USING btree (uid);


--
-- Name: index_oidc_identities_on_issuer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oidc_identities_on_issuer ON public.oidc_identities USING btree (issuer);


--
-- Name: index_oidc_identities_on_provider_and_uid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_oidc_identities_on_provider_and_uid ON public.oidc_identities USING btree (provider, uid);


--
-- Name: index_oidc_identities_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_oidc_identities_on_user_id ON public.oidc_identities USING btree (user_id);


--
-- Name: index_plaid_accounts_on_item_and_plaid_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_plaid_accounts_on_item_and_plaid_id ON public.plaid_accounts USING btree (plaid_item_id, plaid_id);


--
-- Name: index_plaid_accounts_on_plaid_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_plaid_accounts_on_plaid_item_id ON public.plaid_accounts USING btree (plaid_item_id);


--
-- Name: index_plaid_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_plaid_items_on_family_id ON public.plaid_items USING btree (family_id);


--
-- Name: index_plaid_items_on_plaid_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_plaid_items_on_plaid_id ON public.plaid_items USING btree (plaid_id);


--
-- Name: index_product_stock_movements_on_product_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_product_stock_movements_on_product_id ON public.product_stock_movements USING btree (product_id);


--
-- Name: index_products_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_products_on_family_id ON public.products USING btree (family_id);


--
-- Name: index_products_on_family_id_and_sku; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_products_on_family_id_and_sku ON public.products USING btree (family_id, sku) WHERE (sku IS NOT NULL);


--
-- Name: index_purchase_order_items_on_product_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_purchase_order_items_on_product_id ON public.purchase_order_items USING btree (product_id);


--
-- Name: index_purchase_order_items_on_purchase_order_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_purchase_order_items_on_purchase_order_id ON public.purchase_order_items USING btree (purchase_order_id);


--
-- Name: index_purchase_orders_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_purchase_orders_on_family_id ON public.purchase_orders USING btree (family_id);


--
-- Name: index_purchase_orders_on_family_id_and_order_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_purchase_orders_on_family_id_and_order_number ON public.purchase_orders USING btree (family_id, order_number);


--
-- Name: index_recurring_transactions_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_recurring_transactions_on_account_id ON public.recurring_transactions USING btree (account_id);


--
-- Name: index_recurring_transactions_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_recurring_transactions_on_family_id ON public.recurring_transactions USING btree (family_id);


--
-- Name: index_recurring_transactions_on_family_id_and_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_recurring_transactions_on_family_id_and_status ON public.recurring_transactions USING btree (family_id, status);


--
-- Name: index_recurring_transactions_on_merchant_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_recurring_transactions_on_merchant_id ON public.recurring_transactions USING btree (merchant_id);


--
-- Name: index_recurring_transactions_on_next_expected_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_recurring_transactions_on_next_expected_date ON public.recurring_transactions USING btree (next_expected_date);


--
-- Name: index_rejected_transfers_on_inflow_transaction_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rejected_transfers_on_inflow_transaction_id ON public.rejected_transfers USING btree (inflow_transaction_id);


--
-- Name: index_rejected_transfers_on_outflow_transaction_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rejected_transfers_on_outflow_transaction_id ON public.rejected_transfers USING btree (outflow_transaction_id);


--
-- Name: index_rule_actions_on_rule_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rule_actions_on_rule_id ON public.rule_actions USING btree (rule_id);


--
-- Name: index_rule_conditions_on_parent_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rule_conditions_on_parent_id ON public.rule_conditions USING btree (parent_id);


--
-- Name: index_rule_conditions_on_rule_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rule_conditions_on_rule_id ON public.rule_conditions USING btree (rule_id);


--
-- Name: index_rule_runs_on_executed_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rule_runs_on_executed_at ON public.rule_runs USING btree (executed_at);


--
-- Name: index_rule_runs_on_rule_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rule_runs_on_rule_id ON public.rule_runs USING btree (rule_id);


--
-- Name: index_rule_runs_on_rule_id_and_executed_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rule_runs_on_rule_id_and_executed_at ON public.rule_runs USING btree (rule_id, executed_at);


--
-- Name: index_rules_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_rules_on_family_id ON public.rules USING btree (family_id);


--
-- Name: index_sale_items_on_product_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sale_items_on_product_id ON public.sale_items USING btree (product_id);


--
-- Name: index_sale_items_on_sale_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sale_items_on_sale_id ON public.sale_items USING btree (sale_id);


--
-- Name: index_sales_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sales_on_family_id ON public.sales USING btree (family_id);


--
-- Name: index_sales_on_family_id_and_sale_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_sales_on_family_id_and_sale_number ON public.sales USING btree (family_id, sale_number);


--
-- Name: index_securities_on_country_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_securities_on_country_code ON public.securities USING btree (country_code);


--
-- Name: index_securities_on_exchange_operating_mic; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_securities_on_exchange_operating_mic ON public.securities USING btree (exchange_operating_mic);


--
-- Name: index_securities_on_kind; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_securities_on_kind ON public.securities USING btree (kind);


--
-- Name: index_securities_on_price_provider; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_securities_on_price_provider ON public.securities USING btree (price_provider);


--
-- Name: index_securities_on_price_provider_and_offline_reason; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_securities_on_price_provider_and_offline_reason ON public.securities USING btree (price_provider, offline_reason);


--
-- Name: index_securities_on_ticker_and_exchange_operating_mic_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_securities_on_ticker_and_exchange_operating_mic_unique ON public.securities USING btree (upper((ticker)::text), COALESCE(upper((exchange_operating_mic)::text), ''::text));


--
-- Name: index_security_prices_on_security_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_security_prices_on_security_id ON public.security_prices USING btree (security_id);


--
-- Name: index_security_prices_on_security_id_and_date_and_currency; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_security_prices_on_security_id_and_date_and_currency ON public.security_prices USING btree (security_id, date, currency);


--
-- Name: index_sessions_on_active_impersonator_session_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sessions_on_active_impersonator_session_id ON public.sessions USING btree (active_impersonator_session_id);


--
-- Name: index_sessions_on_ip_address_digest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sessions_on_ip_address_digest ON public.sessions USING btree (ip_address_digest);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_settings_on_var; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_settings_on_var ON public.settings USING btree (var);


--
-- Name: index_simplefin_accounts_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_simplefin_accounts_on_account_id ON public.simplefin_accounts USING btree (account_id);


--
-- Name: index_simplefin_accounts_on_simplefin_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_simplefin_accounts_on_simplefin_item_id ON public.simplefin_accounts USING btree (simplefin_item_id);


--
-- Name: index_simplefin_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_simplefin_items_on_family_id ON public.simplefin_items USING btree (family_id);


--
-- Name: index_simplefin_items_on_institution_domain; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_simplefin_items_on_institution_domain ON public.simplefin_items USING btree (institution_domain);


--
-- Name: index_simplefin_items_on_institution_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_simplefin_items_on_institution_id ON public.simplefin_items USING btree (institution_id);


--
-- Name: index_simplefin_items_on_institution_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_simplefin_items_on_institution_name ON public.simplefin_items USING btree (institution_name);


--
-- Name: index_simplefin_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_simplefin_items_on_status ON public.simplefin_items USING btree (status);


--
-- Name: index_snaptrade_accounts_on_item_and_snaptrade_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_snaptrade_accounts_on_item_and_snaptrade_account_id ON public.snaptrade_accounts USING btree (snaptrade_item_id, snaptrade_account_id) WHERE (snaptrade_account_id IS NOT NULL);


--
-- Name: index_snaptrade_accounts_on_snaptrade_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_snaptrade_accounts_on_snaptrade_item_id ON public.snaptrade_accounts USING btree (snaptrade_item_id);


--
-- Name: index_snaptrade_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_snaptrade_items_on_family_id ON public.snaptrade_items USING btree (family_id);


--
-- Name: index_snaptrade_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_snaptrade_items_on_status ON public.snaptrade_items USING btree (status);


--
-- Name: index_sophtron_accounts_on_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sophtron_accounts_on_account_id ON public.sophtron_accounts USING btree (account_id);


--
-- Name: index_sophtron_accounts_on_sophtron_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sophtron_accounts_on_sophtron_item_id ON public.sophtron_accounts USING btree (sophtron_item_id);


--
-- Name: index_sophtron_items_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sophtron_items_on_family_id ON public.sophtron_items USING btree (family_id);


--
-- Name: index_sophtron_items_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sophtron_items_on_status ON public.sophtron_items USING btree (status);


--
-- Name: index_sso_audit_logs_on_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sso_audit_logs_on_created_at ON public.sso_audit_logs USING btree (created_at);


--
-- Name: index_sso_audit_logs_on_event_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sso_audit_logs_on_event_type ON public.sso_audit_logs USING btree (event_type);


--
-- Name: index_sso_audit_logs_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sso_audit_logs_on_user_id ON public.sso_audit_logs USING btree (user_id);


--
-- Name: index_sso_audit_logs_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sso_audit_logs_on_user_id_and_created_at ON public.sso_audit_logs USING btree (user_id, created_at);


--
-- Name: index_sso_providers_on_enabled; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_sso_providers_on_enabled ON public.sso_providers USING btree (enabled);


--
-- Name: index_sso_providers_on_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_sso_providers_on_name ON public.sso_providers USING btree (name);


--
-- Name: index_statement_imports_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_statement_imports_on_family_id ON public.statement_imports USING btree (family_id);


--
-- Name: index_statement_imports_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_statement_imports_on_user_id ON public.statement_imports USING btree (user_id);


--
-- Name: index_subscriptions_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_subscriptions_on_family_id ON public.subscriptions USING btree (family_id);


--
-- Name: index_syncs_on_parent_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_syncs_on_parent_id ON public.syncs USING btree (parent_id);


--
-- Name: index_syncs_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_syncs_on_status ON public.syncs USING btree (status);


--
-- Name: index_syncs_on_syncable; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_syncs_on_syncable ON public.syncs USING btree (syncable_type, syncable_id);


--
-- Name: index_taggings_on_tag_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_taggings_on_tag_id ON public.taggings USING btree (tag_id);


--
-- Name: index_taggings_on_taggable; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_taggings_on_taggable ON public.taggings USING btree (taggable_type, taggable_id);


--
-- Name: index_tags_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_tags_on_family_id ON public.tags USING btree (family_id);


--
-- Name: index_tool_calls_on_message_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_tool_calls_on_message_id ON public.tool_calls USING btree (message_id);


--
-- Name: index_trades_on_investment_activity_label; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_trades_on_investment_activity_label ON public.trades USING btree (investment_activity_label);


--
-- Name: index_trades_on_security_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_trades_on_security_id ON public.trades USING btree (security_id);


--
-- Name: index_transactions_on_category_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transactions_on_category_id ON public.transactions USING btree (category_id);


--
-- Name: index_transactions_on_external_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transactions_on_external_id ON public.transactions USING btree (external_id);


--
-- Name: index_transactions_on_extra; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transactions_on_extra ON public.transactions USING gin (extra);


--
-- Name: index_transactions_on_investment_activity_label; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transactions_on_investment_activity_label ON public.transactions USING btree (investment_activity_label);


--
-- Name: index_transactions_on_kind; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transactions_on_kind ON public.transactions USING btree (kind);


--
-- Name: index_transactions_on_merchant_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transactions_on_merchant_id ON public.transactions USING btree (merchant_id);


--
-- Name: index_transfers_on_inflow_transaction_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transfers_on_inflow_transaction_id ON public.transfers USING btree (inflow_transaction_id);


--
-- Name: index_transfers_on_outflow_transaction_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transfers_on_outflow_transaction_id ON public.transfers USING btree (outflow_transaction_id);


--
-- Name: index_transfers_on_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_transfers_on_status ON public.transfers USING btree (status);


--
-- Name: index_users_on_default_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_users_on_default_account_id ON public.users USING btree (default_account_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_family_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_users_on_family_id ON public.users USING btree (family_id);


--
-- Name: index_users_on_last_viewed_chat_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_users_on_last_viewed_chat_id ON public.users USING btree (last_viewed_chat_id);


--
-- Name: index_users_on_locale; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_users_on_locale ON public.users USING btree (locale);


--
-- Name: index_users_on_otp_secret; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_users_on_otp_secret ON public.users USING btree (otp_secret) WHERE (otp_secret IS NOT NULL);


--
-- Name: index_users_on_preferences; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_users_on_preferences ON public.users USING gin (preferences);


--
-- Name: index_users_on_webauthn_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_users_on_webauthn_id ON public.users USING btree (webauthn_id) WHERE (webauthn_id IS NOT NULL);


--
-- Name: index_webauthn_credentials_on_credential_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX index_webauthn_credentials_on_credential_id ON public.webauthn_credentials USING btree (credential_id);


--
-- Name: index_webauthn_credentials_on_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX index_webauthn_credentials_on_user_id ON public.webauthn_credentials USING btree (user_id);


--
-- Name: rule_runs fk_rails_002f22f9bc; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rule_runs
    ADD CONSTRAINT fk_rails_002f22f9bc FOREIGN KEY (rule_id) REFERENCES public.rules(id);


--
-- Name: entries fk_rails_0250d88c1e; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_0250d88c1e FOREIGN KEY (parent_entry_id) REFERENCES public.entries(id) ON DELETE CASCADE;


--
-- Name: coinbase_items fk_rails_0316170f91; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinbase_items
    ADD CONSTRAINT fk_rails_0316170f91 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: simplefin_accounts fk_rails_037b8cd84e; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simplefin_accounts
    ADD CONSTRAINT fk_rails_037b8cd84e FOREIGN KEY (simplefin_item_id) REFERENCES public.simplefin_items(id);


--
-- Name: mercury_items fk_rails_0722d62e77; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mercury_items
    ADD CONSTRAINT fk_rails_0722d62e77 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: family_merchant_associations fk_rails_08e6e20f16; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_merchant_associations
    ADD CONSTRAINT fk_rails_08e6e20f16 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: rule_conditions fk_rails_092decce7f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rule_conditions
    ADD CONSTRAINT fk_rails_092decce7f FOREIGN KEY (parent_id) REFERENCES public.rule_conditions(id);


--
-- Name: transactions fk_rails_0ea2ad3927; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_0ea2ad3927 FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: sophtron_items fk_rails_0f1d377c6d; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sophtron_items
    ADD CONSTRAINT fk_rails_0f1d377c6d FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: messages fk_rails_0f670de7ba; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_0f670de7ba FOREIGN KEY (chat_id) REFERENCES public.chats(id);


--
-- Name: import_rows fk_rails_13e503c4a1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.import_rows
    ADD CONSTRAINT fk_rails_13e503c4a1 FOREIGN KEY (import_id) REFERENCES public.imports(id);


--
-- Name: trades fk_rails_14583816f0; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trades
    ADD CONSTRAINT fk_rails_14583816f0 FOREIGN KEY (security_id) REFERENCES public.securities(id);


--
-- Name: binance_accounts fk_rails_1cdb361f7b; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.binance_accounts
    ADD CONSTRAINT fk_rails_1cdb361f7b FOREIGN KEY (binance_item_id) REFERENCES public.binance_items(id);


--
-- Name: entries fk_rails_206562018a; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_206562018a FOREIGN KEY (import_id) REFERENCES public.imports(id);


--
-- Name: simplefin_items fk_rails_22288b4a2f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.simplefin_items
    ADD CONSTRAINT fk_rails_22288b4a2f FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: purchase_orders fk_rails_2541d4df93; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT fk_rails_2541d4df93 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: goal_pledges fk_rails_256a3eff2d; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_pledges
    ADD CONSTRAINT fk_rails_256a3eff2d FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE RESTRICT;


--
-- Name: family_exports fk_rails_25cf4f133b; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_exports
    ADD CONSTRAINT fk_rails_25cf4f133b FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: impersonation_sessions fk_rails_2b92af2e4a; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.impersonation_sessions
    ADD CONSTRAINT fk_rails_2b92af2e4a FOREIGN KEY (impersonator_id) REFERENCES public.users(id);


--
-- Name: goal_accounts fk_rails_2d65f785f4; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_accounts
    ADD CONSTRAINT fk_rails_2d65f785f4 FOREIGN KEY (goal_id) REFERENCES public.goals(id) ON DELETE CASCADE;


--
-- Name: rejected_transfers fk_rails_2da6f89959; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rejected_transfers
    ADD CONSTRAINT fk_rails_2da6f89959 FOREIGN KEY (outflow_transaction_id) REFERENCES public.transactions(id);


--
-- Name: impersonation_session_logs fk_rails_2ea2f2adc5; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.impersonation_session_logs
    ADD CONSTRAINT fk_rails_2ea2f2adc5 FOREIGN KEY (impersonation_session_id) REFERENCES public.impersonation_sessions(id);


--
-- Name: api_keys fk_rails_32c28d0dc2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_32c28d0dc2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: users fk_rails_33a7580ab9; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_33a7580ab9 FOREIGN KEY (last_viewed_chat_id) REFERENCES public.chats(id);


--
-- Name: coinstats_accounts fk_rails_34f42b2083; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinstats_accounts
    ADD CONSTRAINT fk_rails_34f42b2083 FOREIGN KEY (coinstats_item_id) REFERENCES public.coinstats_items(id);


--
-- Name: accounts fk_rails_363bf5a48d; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_363bf5a48d FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: entries fk_rails_37a3feaeb6; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_37a3feaeb6 FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: accounts fk_rails_37ced7af95; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_37ced7af95 FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: merchants fk_rails_392453ec74; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.merchants
    ADD CONSTRAINT fk_rails_392453ec74 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: account_shares fk_rails_3dfc6c1e60; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_shares
    ADD CONSTRAINT fk_rails_3dfc6c1e60 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transactions fk_rails_3e4f7da228; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_rails_3e4f7da228 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: coinbase_accounts fk_rails_409097c9ea; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinbase_accounts
    ADD CONSTRAINT fk_rails_409097c9ea FOREIGN KEY (coinbase_item_id) REFERENCES public.coinbase_items(id);


--
-- Name: enable_banking_accounts fk_rails_4501cd26dd; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enable_banking_accounts
    ADD CONSTRAINT fk_rails_4501cd26dd FOREIGN KEY (enable_banking_item_id) REFERENCES public.enable_banking_items(id);


--
-- Name: invitations fk_rails_466d8d37e1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_466d8d37e1 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: binance_items fk_rails_4b6850576f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.binance_items
    ADD CONSTRAINT fk_rails_4b6850576f FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: sales fk_rails_4c9854f25c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sales
    ADD CONSTRAINT fk_rails_4c9854f25c FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: fuel_logs fk_rails_4f6704f714; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_logs
    ADD CONSTRAINT fk_rails_4f6704f714 FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: goals fk_rails_54e7bcb021; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT fk_rails_54e7bcb021 FOREIGN KEY (family_id) REFERENCES public.families(id) ON DELETE CASCADE;


--
-- Name: lunchflow_items fk_rails_5d7e129030; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lunchflow_items
    ADD CONSTRAINT fk_rails_5d7e129030 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: account_providers fk_rails_5dd7c0e0b5; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_providers
    ADD CONSTRAINT fk_rails_5dd7c0e0b5 FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: rule_conditions fk_rails_5f51cc0bd1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rule_conditions
    ADD CONSTRAINT fk_rails_5f51cc0bd1 FOREIGN KEY (rule_id) REFERENCES public.rules(id);


--
-- Name: fleet_vehicles fk_rails_622ef5d41f; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fleet_vehicles
    ADD CONSTRAINT fk_rails_622ef5d41f FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: holdings fk_rails_6410f8b23a; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holdings
    ADD CONSTRAINT fk_rails_6410f8b23a FOREIGN KEY (account_provider_id) REFERENCES public.account_providers(id);


--
-- Name: users fk_rails_68e8c5de71; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_68e8c5de71 FOREIGN KEY (default_account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


--
-- Name: recurring_transactions fk_rails_6c55f76c0c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recurring_transactions
    ADD CONSTRAINT fk_rails_6c55f76c0c FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: eval_runs fk_rails_6d0bb7db13; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_runs
    ADD CONSTRAINT fk_rails_6d0bb7db13 FOREIGN KEY (eval_dataset_id) REFERENCES public.eval_datasets(id);


--
-- Name: llm_usages fk_rails_70d4e2ae94; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_usages
    ADD CONSTRAINT fk_rails_70d4e2ae94 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: statement_imports fk_rails_7283113922; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.statement_imports
    ADD CONSTRAINT fk_rails_7283113922 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: oauth_access_tokens fk_rails_732cb83ab7; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT fk_rails_732cb83ab7 FOREIGN KEY (application_id) REFERENCES public.oauth_applications(id);


--
-- Name: sessions fk_rails_738834d772; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_738834d772 FOREIGN KEY (active_impersonator_session_id) REFERENCES public.impersonation_sessions(id);


--
-- Name: invitations fk_rails_7480156672; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_7480156672 FOREIGN KEY (inviter_id) REFERENCES public.users(id);


--
-- Name: categories fk_rails_74d1a4d52c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_74d1a4d52c FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: goal_pledges fk_rails_833b9f7852; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_pledges
    ADD CONSTRAINT fk_rails_833b9f7852 FOREIGN KEY (matched_transaction_id) REFERENCES public.transactions(id) ON DELETE SET NULL;


--
-- Name: budget_categories fk_rails_83cbbb6bcc; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.budget_categories
    ADD CONSTRAINT fk_rails_83cbbb6bcc FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: accounts fk_rails_86697e7a91; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_86697e7a91 FOREIGN KEY (import_id) REFERENCES public.imports(id);


--
-- Name: users fk_rails_87dbf420c1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_87dbf420c1 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: sophtron_accounts fk_rails_89834a6fe7; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sophtron_accounts
    ADD CONSTRAINT fk_rails_89834a6fe7 FOREIGN KEY (sophtron_item_id) REFERENCES public.sophtron_items(id);


--
-- Name: lunchflow_accounts fk_rails_8f1fcd8aa3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lunchflow_accounts
    ADD CONSTRAINT fk_rails_8f1fcd8aa3 FOREIGN KEY (lunchflow_item_id) REFERENCES public.lunchflow_items(id);


--
-- Name: account_shares fk_rails_8f21052ce7; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_shares
    ADD CONSTRAINT fk_rails_8f21052ce7 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: plaid_accounts fk_rails_8fb63dd78c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plaid_accounts
    ADD CONSTRAINT fk_rails_8fb63dd78c FOREIGN KEY (plaid_item_id) REFERENCES public.plaid_items(id);


--
-- Name: rule_actions fk_rails_933d41413c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rule_actions
    ADD CONSTRAINT fk_rails_933d41413c FOREIGN KEY (rule_id) REFERENCES public.rules(id);


--
-- Name: mercury_accounts fk_rails_934709c5df; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mercury_accounts
    ADD CONSTRAINT fk_rails_934709c5df FOREIGN KEY (mercury_item_id) REFERENCES public.mercury_items(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: plaid_items fk_rails_9c72cf4f53; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plaid_items
    ADD CONSTRAINT fk_rails_9c72cf4f53 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: tool_calls fk_rails_9c8daee481; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tool_calls
    ADD CONSTRAINT fk_rails_9c8daee481 FOREIGN KEY (message_id) REFERENCES public.messages(id);


--
-- Name: accounts fk_rails_9d788ddfbc; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_9d788ddfbc FOREIGN KEY (plaid_account_id) REFERENCES public.plaid_accounts(id);


--
-- Name: transfers fk_rails_9d957b82f0; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT fk_rails_9d957b82f0 FOREIGN KEY (outflow_transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: enable_banking_items fk_rails_9f61ad61e0; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.enable_banking_items
    ADD CONSTRAINT fk_rails_9f61ad61e0 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: taggings fk_rails_9fcd2e236b; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.taggings
    ADD CONSTRAINT fk_rails_9fcd2e236b FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: sale_items fk_rails_a2563c1567; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_a2563c1567 FOREIGN KEY (sale_id) REFERENCES public.sales(id);


--
-- Name: accounts fk_rails_a30ca24798; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT fk_rails_a30ca24798 FOREIGN KEY (simplefin_account_id) REFERENCES public.simplefin_accounts(id);


--
-- Name: snaptrade_items fk_rails_a34a4871a3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snaptrade_items
    ADD CONSTRAINT fk_rails_a34a4871a3 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: webauthn_credentials fk_rails_a4355aef77; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.webauthn_credentials
    ADD CONSTRAINT fk_rails_a4355aef77 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: snaptrade_accounts fk_rails_a5c59ec8bb; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.snaptrade_accounts
    ADD CONSTRAINT fk_rails_a5c59ec8bb FOREIGN KEY (snaptrade_item_id) REFERENCES public.snaptrade_items(id);


--
-- Name: budget_categories fk_rails_a928ada795; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.budget_categories
    ADD CONSTRAINT fk_rails_a928ada795 FOREIGN KEY (budget_id) REFERENCES public.budgets(id);


--
-- Name: syncs fk_rails_ac338208d1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.syncs
    ADD CONSTRAINT fk_rails_ac338208d1 FOREIGN KEY (parent_id) REFERENCES public.syncs(id);


--
-- Name: oauth_access_grants fk_rails_b4b53e07b8; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT fk_rails_b4b53e07b8 FOREIGN KEY (application_id) REFERENCES public.oauth_applications(id);


--
-- Name: statement_imports fk_rails_b678234241; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.statement_imports
    ADD CONSTRAINT fk_rails_b678234241 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: transfers fk_rails_b7f6b2cde7; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transfers
    ADD CONSTRAINT fk_rails_b7f6b2cde7 FOREIGN KEY (inflow_transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: indexa_capital_accounts fk_rails_bab5d0452b; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.indexa_capital_accounts
    ADD CONSTRAINT fk_rails_bab5d0452b FOREIGN KEY (indexa_capital_item_id) REFERENCES public.indexa_capital_items(id);


--
-- Name: indexa_capital_items fk_rails_bc63a78aa4; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.indexa_capital_items
    ADD CONSTRAINT fk_rails_bc63a78aa4 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: holdings fk_rails_c18c2c3522; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holdings
    ADD CONSTRAINT fk_rails_c18c2c3522 FOREIGN KEY (security_id) REFERENCES public.securities(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: tags fk_rails_c7b66bad79; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT fk_rails_c7b66bad79 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: eval_results fk_rails_c82ad869ef; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_results
    ADD CONSTRAINT fk_rails_c82ad869ef FOREIGN KEY (eval_sample_id) REFERENCES public.eval_samples(id);


--
-- Name: impersonation_sessions fk_rails_cca4e14dea; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.impersonation_sessions
    ADD CONSTRAINT fk_rails_cca4e14dea FOREIGN KEY (impersonated_id) REFERENCES public.users(id);


--
-- Name: eval_results fk_rails_d1e43bddbb; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_results
    ADD CONSTRAINT fk_rails_d1e43bddbb FOREIGN KEY (eval_run_id) REFERENCES public.eval_runs(id);


--
-- Name: budgets fk_rails_d298be5805; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.budgets
    ADD CONSTRAINT fk_rails_d298be5805 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: family_documents fk_rails_d2b69b5a92; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_documents
    ADD CONSTRAINT fk_rails_d2b69b5a92 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: coinstats_items fk_rails_d581dcba42; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coinstats_items
    ADD CONSTRAINT fk_rails_d581dcba42 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: goal_pledges fk_rails_d5da6aad5d; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_pledges
    ADD CONSTRAINT fk_rails_d5da6aad5d FOREIGN KEY (goal_id) REFERENCES public.goals(id) ON DELETE CASCADE;


--
-- Name: fuel_logs fk_rails_d5dca6e163; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_logs
    ADD CONSTRAINT fk_rails_d5dca6e163 FOREIGN KEY (fleet_vehicle_id) REFERENCES public.fleet_vehicles(id);


--
-- Name: subscriptions fk_rails_d8acfbffc8; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_rails_d8acfbffc8 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: purchase_order_items fk_rails_d9bc69e4b3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT fk_rails_d9bc69e4b3 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: product_stock_movements fk_rails_dc802d5f48; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_stock_movements
    ADD CONSTRAINT fk_rails_dc802d5f48 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: recurring_transactions fk_rails_dc9ca6eb37; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recurring_transactions
    ADD CONSTRAINT fk_rails_dc9ca6eb37 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: recurring_transactions fk_rails_e209c15dd3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recurring_transactions
    ADD CONSTRAINT fk_rails_e209c15dd3 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: rules fk_rails_e4bc52f9b6; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT fk_rails_e4bc52f9b6 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: goal_accounts fk_rails_e4c27679ad; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.goal_accounts
    ADD CONSTRAINT fk_rails_e4c27679ad FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE RESTRICT;


--
-- Name: chats fk_rails_e555f43151; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT fk_rails_e555f43151 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: eval_samples fk_rails_e8e5655e33; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eval_samples
    ADD CONSTRAINT fk_rails_e8e5655e33 FOREIGN KEY (eval_dataset_id) REFERENCES public.eval_datasets(id);


--
-- Name: sso_audit_logs fk_rails_ee372936da; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sso_audit_logs
    ADD CONSTRAINT fk_rails_ee372936da FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: sale_items fk_rails_ee606308b2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_items
    ADD CONSTRAINT fk_rails_ee606308b2 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: fuel_logs fk_rails_ef239a435b; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_logs
    ADD CONSTRAINT fk_rails_ef239a435b FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: holdings fk_rails_ef2ad271e6; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holdings
    ADD CONSTRAINT fk_rails_ef2ad271e6 FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: purchase_order_items fk_rails_f247068a39; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order_items
    ADD CONSTRAINT fk_rails_f247068a39 FOREIGN KEY (purchase_order_id) REFERENCES public.purchase_orders(id);


--
-- Name: fuel_log_lines fk_rails_f2ecce1f04; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuel_log_lines
    ADD CONSTRAINT fk_rails_f2ecce1f04 FOREIGN KEY (fuel_log_id) REFERENCES public.fuel_logs(id) ON DELETE CASCADE;


--
-- Name: balances fk_rails_f3e5781e9c; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.balances
    ADD CONSTRAINT fk_rails_f3e5781e9c FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- Name: mobile_devices fk_rails_f61b19cc7b; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mobile_devices
    ADD CONSTRAINT fk_rails_f61b19cc7b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: family_merchant_associations fk_rails_f6ec19d267; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.family_merchant_associations
    ADD CONSTRAINT fk_rails_f6ec19d267 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: oidc_identities fk_rails_f976bdec82; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.oidc_identities
    ADD CONSTRAINT fk_rails_f976bdec82 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: security_prices fk_rails_fb42b7e597; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.security_prices
    ADD CONSTRAINT fk_rails_fb42b7e597 FOREIGN KEY (security_id) REFERENCES public.securities(id);


--
-- Name: rejected_transfers fk_rails_fbdaa55382; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rejected_transfers
    ADD CONSTRAINT fk_rails_fbdaa55382 FOREIGN KEY (inflow_transaction_id) REFERENCES public.transactions(id);


--
-- Name: holdings fk_rails_fce9c5a998; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holdings
    ADD CONSTRAINT fk_rails_fce9c5a998 FOREIGN KEY (provider_security_id) REFERENCES public.securities(id);


--
-- Name: products fk_rails_fdc6600f93; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_fdc6600f93 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: imports fk_rails_fef4f8a5b1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.imports
    ADD CONSTRAINT fk_rails_fef4f8a5b1 FOREIGN KEY (family_id) REFERENCES public.families(id);


--
-- Name: accounts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: accounts accounts_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY accounts_family_isolation_policy ON public.accounts USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: budget_categories; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.budget_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: budget_categories budget_categories_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY budget_categories_family_isolation_policy ON public.budget_categories USING ((budget_id IN ( SELECT budgets.id
   FROM public.budgets
  WHERE (budgets.family_id = public.current_family_id())))) WITH CHECK ((budget_id IN ( SELECT budgets.id
   FROM public.budgets
  WHERE (budgets.family_id = public.current_family_id()))));


--
-- Name: budgets; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

--
-- Name: budgets budgets_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY budgets_family_isolation_policy ON public.budgets USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: categories categories_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY categories_family_isolation_policy ON public.categories USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: entries; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.entries ENABLE ROW LEVEL SECURITY;

--
-- Name: entries entries_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY entries_family_isolation_policy ON public.entries USING ((account_id IN ( SELECT accounts.id
   FROM public.accounts
  WHERE (accounts.family_id = public.current_family_id())))) WITH CHECK ((account_id IN ( SELECT accounts.id
   FROM public.accounts
  WHERE (accounts.family_id = public.current_family_id()))));


--
-- Name: fleet_vehicles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.fleet_vehicles ENABLE ROW LEVEL SECURITY;

--
-- Name: fleet_vehicles fleet_vehicles_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY fleet_vehicles_family_isolation_policy ON public.fleet_vehicles USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: fuel_log_lines; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.fuel_log_lines ENABLE ROW LEVEL SECURITY;

--
-- Name: fuel_log_lines fuel_log_lines_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY fuel_log_lines_family_isolation_policy ON public.fuel_log_lines USING ((fuel_log_id IN ( SELECT fuel_logs.id
   FROM public.fuel_logs
  WHERE (fuel_logs.fleet_vehicle_id IN ( SELECT fleet_vehicles.id
           FROM public.fleet_vehicles
          WHERE (fleet_vehicles.family_id = public.current_family_id())))))) WITH CHECK ((fuel_log_id IN ( SELECT fuel_logs.id
   FROM public.fuel_logs
  WHERE (fuel_logs.fleet_vehicle_id IN ( SELECT fleet_vehicles.id
           FROM public.fleet_vehicles
          WHERE (fleet_vehicles.family_id = public.current_family_id()))))));


--
-- Name: fuel_logs; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.fuel_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: fuel_logs fuel_logs_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY fuel_logs_family_isolation_policy ON public.fuel_logs USING ((fleet_vehicle_id IN ( SELECT fleet_vehicles.id
   FROM public.fleet_vehicles
  WHERE (fleet_vehicles.family_id = public.current_family_id())))) WITH CHECK ((fleet_vehicle_id IN ( SELECT fleet_vehicles.id
   FROM public.fleet_vehicles
  WHERE (fleet_vehicles.family_id = public.current_family_id()))));


--
-- Name: goals; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

--
-- Name: goals goals_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY goals_family_isolation_policy ON public.goals USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: merchants; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.merchants ENABLE ROW LEVEL SECURITY;

--
-- Name: merchants merchants_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY merchants_family_isolation_policy ON public.merchants USING (((family_id = public.current_family_id()) OR (family_id IS NULL))) WITH CHECK (((family_id = public.current_family_id()) OR (family_id IS NULL)));


--
-- Name: product_stock_movements; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.product_stock_movements ENABLE ROW LEVEL SECURITY;

--
-- Name: product_stock_movements product_stock_movements_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY product_stock_movements_family_isolation_policy ON public.product_stock_movements USING ((product_id IN ( SELECT products.id
   FROM public.products
  WHERE (products.family_id = public.current_family_id())))) WITH CHECK ((product_id IN ( SELECT products.id
   FROM public.products
  WHERE (products.family_id = public.current_family_id()))));


--
-- Name: products; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

--
-- Name: products products_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY products_family_isolation_policy ON public.products USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: purchase_order_items; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_order_items purchase_order_items_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY purchase_order_items_family_isolation_policy ON public.purchase_order_items USING ((purchase_order_id IN ( SELECT purchase_orders.id
   FROM public.purchase_orders
  WHERE (purchase_orders.family_id = public.current_family_id())))) WITH CHECK ((purchase_order_id IN ( SELECT purchase_orders.id
   FROM public.purchase_orders
  WHERE (purchase_orders.family_id = public.current_family_id()))));


--
-- Name: purchase_orders; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_orders purchase_orders_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY purchase_orders_family_isolation_policy ON public.purchase_orders USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: receivables; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.receivables ENABLE ROW LEVEL SECURITY;

--
-- Name: receivables receivables_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY receivables_family_isolation_policy ON public.receivables USING ((id IN ( SELECT accounts.accountable_id
   FROM public.accounts
  WHERE (((accounts.accountable_type)::text = 'Receivable'::text) AND (accounts.family_id = public.current_family_id()))))) WITH CHECK (true);


--
-- Name: recurring_transactions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.recurring_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: recurring_transactions recurring_transactions_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY recurring_transactions_family_isolation_policy ON public.recurring_transactions USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: rules; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.rules ENABLE ROW LEVEL SECURITY;

--
-- Name: rules rules_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY rules_family_isolation_policy ON public.rules USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: sale_items; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

--
-- Name: sale_items sale_items_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY sale_items_family_isolation_policy ON public.sale_items USING ((sale_id IN ( SELECT sales.id
   FROM public.sales
  WHERE (sales.family_id = public.current_family_id())))) WITH CHECK ((sale_id IN ( SELECT sales.id
   FROM public.sales
  WHERE (sales.family_id = public.current_family_id()))));


--
-- Name: sales; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;

--
-- Name: sales sales_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY sales_family_isolation_policy ON public.sales USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: tags; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;

--
-- Name: tags tags_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY tags_family_isolation_policy ON public.tags USING ((family_id = public.current_family_id())) WITH CHECK ((family_id = public.current_family_id()));


--
-- Name: transactions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: transactions transactions_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY transactions_family_isolation_policy ON public.transactions USING ((id IN ( SELECT entries.entryable_id
   FROM public.entries
  WHERE (((entries.entryable_type)::text = 'Transaction'::text) AND (entries.account_id IN ( SELECT accounts.id
           FROM public.accounts
          WHERE (accounts.family_id = public.current_family_id()))))))) WITH CHECK (true);


--
-- Name: valuations; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.valuations ENABLE ROW LEVEL SECURITY;

--
-- Name: valuations valuations_family_isolation_policy; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY valuations_family_isolation_policy ON public.valuations USING ((id IN ( SELECT entries.entryable_id
   FROM public.entries
  WHERE (((entries.entryable_type)::text = 'Valuation'::text) AND (entries.account_id IN ( SELECT accounts.id
           FROM public.accounts
          WHERE (accounts.family_id = public.current_family_id()))))))) WITH CHECK (true);


--
-- PostgreSQL database dump complete
--

\unrestrict 8aimRRRWXsWO8dKdSQxba6TSES2pSmlHbFNYbyHDuxHL6A4k1fOSf8ITCrKOh6W
