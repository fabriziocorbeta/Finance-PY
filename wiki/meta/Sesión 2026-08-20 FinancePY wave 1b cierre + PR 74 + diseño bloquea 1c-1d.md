---
type: session
status: closed
created: 2026-08-20
updated: 2026-08-20
tags: [financespy, android-nativo, jules, diseño]
---

# Sesión 2026-08-20 — Wave 1b cerrada, PR #74 mergeado y deployado, diseño real pasa a bloquear 1c/1d

## Wave 1b (Reglas CRUD nativo) — cerrada, verificada en dispositivo físico contra producción

3 bugs reales, solo detectables en teléfono físico (mismo patrón de 1a):

1. **kotlinx.serialization omite campos con valor default al serializar.** `CreateRuleBody` declaraba `resource_type="transaction"` y `active=true` como defaults — nunca viajaban en el JSON, server respondía 422 (`resource_type` es obligatorio). Confirmado leyendo logs reales de Rails. Fix: `@EncodeDefault` en ambos campos (+ `@OptIn(ExperimentalSerializationApi::class)`).
2. **Teclado tapaba el botón "Guardar"** en `RuleFormScreen` — sin manejo de inset. Fix: `Modifier.imePadding()`.
3. **Barra de navegación gestual tapaba el borde inferior** de `App.kt` — mismo patrón que el `statusBarsPadding()` de una task anterior. Fix: `Modifier.navigationBarsPadding()`.

CRUD verificado end-to-end contra prod real: crear (aparece en server), leer (lista + detalle + historial de ejecuciones), borrar (`rules_count=0` confirmado en DB).

**Nota de comportamiento, no bug:** la lista no se refresca sola tras crear una regla (el ViewModel usa `remember`, no re-consulta) — reinicio de la app sí la muestra. Refresh automático post-mutación queda pendiente, fuera de scope de 1b.

## PR #74 (Jules) — API read-only Budgets/Goals/Receivables: revisado, corregido, mergeado, deployado

Jules abrió el PR con index/show para los 3 recursos. Review encontró:

- **Bug de seguridad real (no falso positivo):** `receivables_scope` solo filtraba por `family`, no por `.accessible_by(current_resource_owner)` — un miembro de family podía ver receivables de una cuenta **privada** de otro miembro de la misma family (mismo patrón que `Account.accessible_by` ya resuelve en el controller web, Jules no lo replicó). Corregido antes de mergear:

```ruby
def receivables_scope
  account_ids = current_resource_owner.family.accounts
                                      .visible
                                      .accessible_by(current_resource_owner)
                                      .where(accountable_type: "Receivable")
                                      .select(:accountable_id)
  Receivable.where(id: account_ids)
end
```

  Test de regresión agregado y verificado que **falla sin el fix** (antes de restaurarlo).

- 3 bugs de test (no de producto): fixture de `budgets` duplicaba `start_date`/`end_date` de uno existente (viola unicidad por family) → reusar `budgets(:one)`; `Budget#to_param` devuelve una fecha formateada, no el UUID → direccionar con `api_v1_budget_url(id: @budget.id)`; `Goal` creado en tests sin `goal_accounts` vinculada violaba `must_have_at_least_one_linked_account`.

- Confirmado que `Budget`/`Goal` **no** tienen el problema de `Receivable` — no hay `owner_id` ni concepto de share en su schema, solo `family_id`. El fix de accessible_by es específico de Receivable (que cuelga de `Account`, que sí puede ser privada dentro de una family).

Mergeado a `main` (`e0da0cc`), 373 tests / 0 failures / 0 errors verificados en infra de test aislada antes de mergear. Deployado en la notebook (imagen `financespy-web` rebuildeada hoy, containers confirmados arriba, sitio prod responde 302 normal).

## Decisión de secuencia — el diseño real pasa a bloquear wave 1c y wave 1d

Al ver la primera pantalla nativa funcional (`RuleFormScreen`), el usuario notó que la app no respeta el sistema de diseño real de FinancePY — Compose venía con Material3 genérico (texto plano, morado default), mientras que FinancePY tiene un design system propio maduro (`app/assets/tailwind/sure-design-system/{base.css,components.css,_generated.css,prose.css}`: tokens semánticos con variantes light/dark tipo `--color-success`/`--color-warning`/`--color-destructive`, fuente Geist).

Se le presentaron 3 opciones (seguir sin estilo por ahora / puerto parcial / puerto completo antes de seguir) — eligió explícitamente **"Diseño primero, después 1d"**: una wave de puerto del design system a Compose Material3 debe completarse antes de wave 1c (CRUD completo Budgets/Goals/Receivables) y wave 1d (wallet-capture).

**Spec del design-system port: no escrita todavía** — interrumpida dos veces por cortes de SSH (sshd cayendo en la WSL2 de la notebook, independiente del uptime de la instancia; producción no se vio afectada ninguna vez). Pendiente real: leer `base.css` completo (solo se grepeó hasta ahora) y escribir la spec vía el flujo normal de brainstorming antes de tocar Kotlin.

## Heavy-lifting delegado a Jules (paralelo, no toca el módulo nativo)

3 prompts dados el mismo día para CRUD completo (create/update/destroy) de Budgets, Goals y Receivables vía API v1 — construye sobre el read-only de PR #74, es el insumo directo que necesitará wave 1c una vez que el design system esté portado. Cada prompt repite explícitamente las reglas de scope de seguridad ya aprendidas en #74 (Budgets/Goals por family simple, Receivables por `.accessible_by`) para no repetir el mismo bug.

## Actualización de memoria/vault + primer setup de git para el repo Sistema (mismo día)

Tras cerrar lo de arriba, se actualizó memoria (`project_financespy.md`) y este vault (nota + índice + log). Al intentar pushear el vault a GitHub se descubrió que **este repo (Sistema) nunca tuvo remote configurado** — primer setup real.

Decisión del usuario: usar el mismo repo GitHub del ERP (`fabriziocorbeta/cd-co-erp`), que ya aloja dos codebases no relacionadas por branch (`main`=FinancePY, `version-1.1.0`=CD&Co ERP JS). El vault Sistema es un tercer contenido no relacionado — **rama huérfana nueva `vault`** (sin historia compartida con `main`/`version-1.1.0`) para no mezclar.

**Excluido del commit pese al "todo lo untracked" del usuario — no negociable, secretos reales:**
- `.local-secrets/` (keystores de firma Android + backup de la VM alejandro-vm)
- `.env`/`.env.local` reales (no `.example`) encontrados dentro de subcarpetas: `cd-co-crm/.env`, `01 - cdco/.env.local`, `cd-co-crm/supabase/.env.local`

Todo lo demás (node_modules, dump.rdb, zips, carpetas completas de otros proyectos como `crm-app/`, `cd-co-erp-main/`) sí se stageó, a pedido explícito del usuario tras la advertencia.

**Pendiente al cierre de esta nota:** `git add -A` corriendo en background (repo grande, timeout en foreground), falta commit + `git remote add` + push de la rama `vault`. Uno de los 3 PRs de Jules (CRUD Budgets/Goals/Receivables) ya está "Ready for review" — pendiente de revisar con el mismo criterio que PR #74 (chequear scope `.accessible_by` en Receivables, correr tests aislados antes de mergear).

## Ver también
- [[FinancePY]]
- [[Sesión 2026-08-13 FinancePY unificación móvil + puente SSH Tailscale + QA wallet capture]]
