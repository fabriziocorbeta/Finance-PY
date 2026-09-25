# RLS design notes — Ola 2 / E1 Etapa B (casos especiales)

Companion to `docs/security/rls-inventory.md` and `config/rls_inventory.yml`.
This document covers the parts of the RLS rollout that aren't "add a
`family_id = current_family_id()` policy": the mechanism for code that
legitimately needs to see more than one family, and the specific traps this
etapa actually hit while building it.

Scope of this etapa: **ENABLE + policies only, no FORCE.** Every table this
etapa touched is `force: false` in the inventory. In prod today the app
connects as `financespy_app`, which **owns** all 114 tables, so `ENABLE ROW
LEVEL SECURITY` without `FORCE` is a behavioral no-op for the app's own
connection — the owner is exempt from RLS unless the table is FORCE'd. FORCE
is a separate, later etapa. Everything below that talks about FORCE is
about that later etapa, not this one.

## Threat model, in one paragraph

The attacker we're defending against here is **not** someone with direct
Postgres access (they'd need `financespy_app`'s credentials or superuser,
which is a different problem). It's **a bug in the Rails app** — a missing
`.where(family: ...)` scope, a controller that trusts a client-supplied id,
an N+1 fix that accidentally drops a scope — that would otherwise leak
another family's financial data through the app's own, already-authenticated
connection. RLS is the backstop for that class of bug: even if the
ActiveRecord query is wrong, the database itself won't return rows outside
`app.current_family_id`. FORCE (next etapa) is what makes that backstop
apply to the app's own connection and not just to a lower-privileged role.

## SECURITY DEFINER does not bypass FORCE — the trap, concretely

The coordinator's brief for this etapa flagged this as a known risk, and
building the `rule_conditions` policy below ran straight into the general
version of it, so it's worth stating precisely:

> A `SECURITY DEFINER` function's queries run with the privileges of the
> function's **owner**, not its caller. If the owner is `financespy_app`,
> and `financespy_app` is *also* the owner of a table that has `FORCE ROW
> LEVEL SECURITY` set, the function does **not** bypass that table's
> policies — FORCE applies to the owner too, by definition. The function
> only bypasses RLS if its owner is a superuser, has `BYPASSRLS`, or owns a
> table that isn't FORCE'd.

Concretely: `db/migrate/20260923143240_...rb` in this etapa needed a
recursive walk up `rule_conditions.parent_id` to find the ancestor row that
has `rule_id` set (see that migration's comment on `rule_condition_root_rule_id`
for why: nested sub-conditions don't store `rule_id`). Writing that walk as
a plain recursive CTE **inside** the `rule_conditions` policy's `USING`
clause causes Postgres to re-apply that same policy to every row the CTE
reads, which is genuinely infinite — confirmed against a live DB while
writing this (`PG::InvalidObjectDefinition: infinite recursion detected in
policy for relation "rule_conditions"`, reproduced in
`test/integration/row_level_security_ola2_etapa_b_test.rb`). The fix is a
`SECURITY DEFINER` function with `SET row_security = off`, which breaks the
cycle **today** because the function's owner (the migration-running/table-
owning role) is exempt from `rule_conditions`' RLS (ENABLE without FORCE).

**This stops working the moment `rule_conditions` gets `FORCE`'d and its
owner becomes `financespy_app`** (the owner-separation etapa) — the function
would then be subject to the same FORCE'd policy it's trying to evaluate,
and the infinite recursion comes back. Whoever does that etapa must either:

1. own `rule_condition_root_rule_id` (and any other helper function used
   inside a FORCE'd table's own policy) as a narrow role with `BYPASSRLS`
   and nothing else, not `financespy_app`; or
2. avoid self-referential policies entirely for tables that get FORCE'd,
   by denormalizing (e.g. store the resolved `rule_id` on every
   `rule_conditions` row, top-level or nested, instead of walking `parent_id`
   at read time).

Recorded here so it isn't rediscovered the hard way during the FORCE etapa.

## The "system access" mechanism (prep only, not wired to any policy yet)

`RlsContext.with_system_access(reason:)` (`app/models/concerns/rls_context.rb`)
and the `is_system_context()` SQL function
(`db/migrate/20260923143250_add_rls_system_context_helper.rb`) are the
primitive for the three genuinely-cross-family cases below. **Neither is
consumed by any policy's `USING`/`WITH CHECK` yet** — adding them today would
be a no-op (nothing checks `is_system_context()`), so this is intentionally
split into "add the primitive, get it reviewed and tested on its own" now,
and "wire it into specific policies" as a later, narrower change once FORCE
makes it matter and each case's blast radius can be scoped individually.

Why a GUC + a SQL function instead of just widening policies with an OR:
a blanket `USING (family_id = current_family_id() OR is_system_context())`
on every table defeats the entire point of FORCE the moment any code path
anywhere sets that GUC. The intended usage is the opposite: wire
`is_system_context()` into the **specific** policy of the **specific**
table a **specific**, reviewed job/tool actually needs, not globally.

`with_system_access` requires a non-blank `reason:` (no default — a call
site can't opt in silently) and logs every call with the reason and the
caller's file:line via `Rails.logger.warn`, so cross-family access is always
attributable after the fact. See
`test/models/concerns/rls_context_test.rb` for coverage of the primitive
itself (GUC set/reset, logging, exception path).

### Case: jobs that are genuinely cross-family

`ActiveJobRowLevelSecurity` (`app/jobs/concerns/active_job_row_level_security.rb`,
landed in E2) already resolves a *single* family from a job's arguments and
scopes the connection to it for the duration of `perform`. A job that
can't resolve one family — because it operates over all families by
design, e.g. a future platform-metrics aggregation job — currently falls
into that concern's "no family resolved" branch, which calls
`RlsContext.reset` and runs with `app.current_family_id` unset. Under a
FORCE'd table, that means the policy's `family_id = current_family_id()`
evaluates to `NULL` for every row (not "true for all"), so the job would see
**zero rows**, not all of them — silently broken, not silently leaky, but
broken. That job should instead wrap its cross-family read in
`RlsContext.with_system_access(reason: "platform_daily_metrics aggregation")`,
and the tables it reads (starting with `platform_daily_metrics` itself,
already `classification: global` and unscoped) get a policy with an
`is_system_context()` branch **when they're FORCE'd**, not before.

### Case: super_admin tooling

Same shape as the jobs case: an internal admin action that legitimately
needs to look at more than one family's data (support tooling, abuse
investigation) should call `RlsContext.with_system_access(reason: "...")`
around that specific read, scoped as tightly as possible (ideally: look up
the *one* family the admin action is about, and use `RlsContext.with_family`
instead of system access at all — system access is for when even that
isn't possible). `app/controllers/concerns/authentication.rb` already has
an impersonation flow (`impersonation_sessions`/`impersonation_session_logs`,
both `classification: auth`) for the "act as this one user" case, which is
strictly better than system access when it applies: it still scopes to a
single family via that user, and it's already audited by
`ImpersonationSession`/`SsoAuditLog`. System access is the fallback for
admin operations that are inherently cross-family (e.g. "how many families
are on plan X"), not a shortcut around impersonation.

### Case: platform-wide metrics

`platform_daily_metrics` is `classification: global` (no `family_id`,
correctly so — it aggregates across families by definition) and gets no
family-scoping policy, matching every other `global` table. The job that
*writes* it, though, needs to *read* every family's data to compute the
aggregate. Today that's a non-issue (no FORCE). Once family-scoped source
tables (`transactions`, `accounts`, etc.) are FORCE'd, that write job
becomes a system-access call site: `RlsContext.with_system_access(reason:
"platform_daily_metrics computation")` around the aggregation query, same as
the general cross-family-job case above.

### Case: Active Storage

`active_storage_attachments`/`_blobs`/`_variant_records` (`classification:
storage`) have no `family_id` at all by framework design — family is only
reachable by resolving the polymorphic `record_id`/`record_type` on
`active_storage_attachments` back to whatever owns it (`Account#logo`,
`FamilyDocument`, `ArchivedExport#export_file`, per the inventory notes).
Two real constraints make this different from the polymorphic-join tables
this etapa already did handle (`addresses`, `data_enrichments`):

- **Multiple, growing set of attachable types.** Unlike `addresses`
  (one consumer today) or `data_enrichments` (three, all `Entryable`), the
  attachable side of Active Storage is open-ended — anything in the app can
  declare `has_one_attached`/`has_many_attached`. A CASE-based policy
  enumerating every attachable type needs to be extended every time a new
  one is added, silently under-covering (fail-closed, not a leak — but
  broken uploads/downloads) if someone forgets.
- **`active_storage_blobs` has no link to `record` at all** — only
  `active_storage_attachments` does (`blob_id` -> `active_storage_blobs.id`,
  `record_id`/`record_type` -> the owner). A blob's own policy has to go
  through `active_storage_attachments` (`id IN (SELECT blob_id FROM
  active_storage_attachments WHERE ...)`), and a blob can in principle be
  attached to more than one record (Rails supports this), which needs an
  `OR`/`ANY` across attachments rather than a single `id IN (...)`
  assumption.

Recommended approach for the FORCE etapa (not implemented here, out of this
etapa's scope per the coordinator's brief): a single helper function
`active_storage_record_family_id(record_type text, record_id uuid) RETURNS
uuid`, `SECURITY DEFINER` (same owner-exemption caveat as
`rule_condition_root_rule_id` above — must be re-owned when FORCE +
owner-separation lands) with a `CASE record_type WHEN 'Account' THEN ...
WHEN 'FamilyDocument' THEN ... END`, so every attachable type is declared in
exactly one place instead of duplicated across `active_storage_attachments`'
and `active_storage_blobs`' own policies, and `active_storage_blobs`' policy
becomes `EXISTS (SELECT 1 FROM active_storage_attachments a WHERE a.blob_id
= active_storage_blobs.id AND active_storage_record_family_id(a.record_type,
a.record_id) = current_family_id())`.

### Case: auth / lookup tables (login by email, OAuth token, invitation by
token, Android webhook)

None of the 14 `classification: auth` tables got a policy this etapa —
deliberately. The reason isn't "lower priority", it's that a plain
`family_id = current_family_id()` policy is the **wrong shape** for these:
every one of them is looked up **before** `app.current_family_id` is known
(that's what makes them "auth" tables rather than "direct"/"indirect" ones —
see each table's `family_path` note in `config/rls_inventory.yml`, e.g.
`users`: "la tabla se consulta ANTES de conocer la family"). A family-scoped
policy on `users` would make `User.find_by(email: ...)` during login return
nothing, because nothing has called `RlsContext.set_family` yet at that
point in the request.

The mechanism these need, once they're brought under RLS, is a **narrow
lookup-shaped policy**, not the system-access escape hatch above (system
access is for legitimate cross-family reads by trusted code; a login
endpoint reachable by anyone with an email address is exactly the kind of
caller that should **not** get a blanket cross-family exemption). Sketch,
per table, for the FORCE etapa to flesh out:

- `users`, `sessions`, `oidc_identities`, `webauthn_credentials`,
  `mobile_devices`, `api_keys`: policy allows `SELECT` when the lookup key
  the app is actually allowed to query by (exact `email`, exact
  `session_token`/its digest, exact external identity id, exact device
  token, exact API key digest) matches, **regardless of
  `current_family_id()`** — the exact-match requirement on a
  high-entropy/hashed column is the access control, not the family. This is
  the same shape `merchants` already uses for its nullable case
  (`family_id = current_family_id() OR family_id IS NULL`), generalized:
  narrow the `OR` branch to an exact key match instead of "OR NULL".
- `oauth_access_grants`, `oauth_access_tokens`: same, keyed on the token
  value's hash, not `resource_owner_id`.
- `invite_codes`, `archived_exports`: already family-less by design
  (invite codes aren't tied to an existing family per the inventory note;
  exports are looked up by download token digest) — same exact-match-token
  shape.
- `impersonation_sessions`, `impersonation_session_logs`,
  `sso_audit_logs`, `sso_providers`, `oauth_applications`: these are
  genuinely admin/system surfaces, not end-user login paths — candidates
  for the system-access mechanism above rather than a lookup policy, since
  there's no single safe "exact key" an anonymous caller should be allowed
  to match on.

None of this is implemented in this etapa (the tables remain
`policy_present: false`, `force: false`) — designed here so the FORCE etapa
doesn't have to re-derive it, and so `RlsCatalogTest`'s "every direct/
indirect/root table has a policy" gate (deliberately scoped to just those
three classifications) doesn't block on it.

## A gap found while writing this: `families` itself and signup

`families` got a straightforward root policy this etapa (`id =
current_family_id()`, see
`db/migrate/20260923143235_enable_rls_policy_for_families.rb`). Writing the
design doc surfaced a real ordering problem with it that's worth recording
even though it does nothing today (no FORCE, and the DB owner is exempt
from RLS regardless): `RegistrationsController#create`
(`app/controllers/registrations_controller.rb`) does `family = Family.new`
before any `RlsContext.set_family` call — there's no session yet, so no
family is known yet, by construction (you can't know your family's id
before you've created it). Once `families` is FORCE'd, `WITH CHECK (id =
current_family_id())` would reject that INSERT for the DB owner too (post
owner-separation), breaking self-hosted signup and invite-only default-family
signup.

Not fixed here — it's out of this etapa's scope (no FORCE yet, so it's
currently a no-op) and touches the signup flow, which deserves its own
review rather than a rushed change bundled into an RLS migration. Recommended
fix for the FORCE etapa: generate the new `Family`'s UUID in Ruby
(`SecureRandom.uuid`) before `save`, call
`RlsContext.set_family(that_id)` first, *then* save — so `current_family_id()`
already matches the row being inserted, no special-case policy branch
needed. Flagging here per "verificá cada premisa... si es falsa,
documentalo" rather than forcing an untested change to signup into this
etapa.

## Summary table: which case gets which mechanism

| Case | Mechanism | Status |
|---|---|---|
| Ordinary direct/indirect tables | `family_id = current_family_id()` / join policy | Done this etapa |
| `rule_conditions` self-referential walk | `SECURITY DEFINER` + `SET row_security = off` helper function | Done this etapa (re-owning needed at FORCE+owner-separation) |
| Cross-family jobs (platform metrics, etc.) | `RlsContext.with_system_access` + per-table `is_system_context()` branch | Primitive added this etapa; per-table wiring deferred to FORCE etapa |
| super_admin ops | Prefer `RlsContext.with_family` via impersonation; `with_system_access` only when inherently cross-family | Primitive added this etapa; not wired |
| Active Storage | `active_storage_record_family_id(type, id)` SECURITY DEFINER helper, CASE per attachable type | Designed, not implemented |
| Auth/lookup tables (login, tokens, invites) | Narrow exact-key-match policy branch, not `current_family_id()` | Designed, not implemented |
| `families` root + signup | Set `app.current_family_id` before INSERT using a pre-generated UUID | Gap identified, not fixed (no-op until FORCE) |
| Global tables | No policy (by definition, no family relation) | Unchanged |
