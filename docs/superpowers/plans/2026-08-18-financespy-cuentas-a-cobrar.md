# Cuentas a Cobrar (FinancePY) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar un nuevo tipo de cuenta `Receivable` (asset) a FinancePY, con página propia "Cuentas a Cobrar" y cobro de pagos vía transferencia real entre cuentas, integrado al motor de Balance Sheet/Net Worth ya existente.

**Architecture:** Mirror casi exacto del `Loan` accountable ya existente (modelo + controller delgado vía el concern `AccountableResource` + rutas + vistas + locales). La única pieza sin equivalente directo es la página índice "Cuentas a Cobrar", que agrupa cuentas activas/completadas. "Registrar Pago" reusa el `TransfersController` ya existente (parámetro `from_account_id`), sin controller/acción nueva para eso.

**Tech Stack:** Rails 7.2.3.1, Minitest + fixtures, ViewComponent (`ApplicationComponent`), Tailwind.

## Global Constraints

- Spec fuente: `docs/superpowers/specs/2026-08-17-financespy-cuentas-a-cobrar-design.md` (status: approved).
- Repo remoto únicamente, sin filesystem local: `ssh -o BatchMode=yes fabrizio@100.105.31.71`, repo en `/home/fabrizio/financespy`, branch de trabajo `feature/receivables` (ver Task 0 — no se commitea directo a `main` en este plan, a diferencia del plan de PWA anterior, porque este cambio es más grande/riesgoso: migración nueva + toca cálculo de patrimonio).
- Patrón de edición remota (usar en todo Task que edite un archivo EXISTENTE): reemplazo exacto de string vía Python por SSH.

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/<ruta>')
old = '''<OLD_STRING>'''
new = '''<NEW_STRING>'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

Para archivos NUEVOS, usar `cat > ruta <<'EOF' ... EOF` vía SSH directamente (sin necesidad de reemplazo, no hay contenido previo que preservar).

- **Testing local, patrón validado (usar en todo Task que corra tests) — NO usar `bin/rails test` contra los containers `financespy-web-1`/`financespy-worker-1` de producción, apuntan a la Supabase real y Rails lo bloquea a propósito (`ActiveRecord::ProtectedEnvironmentError`).** Se usa en cambio un Postgres de test aislado y descartable, levantado en Task 0, con este comando exacto:

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test \
  -e DB_HOST=financespy_test_pg \
  -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test <RUTA_DEL_TEST> 2>&1
'
```

(Nota: `DATABASE_URL` con scheme `postgres://`/`postgresql://` falla acá con `URI::InvalidURIError` — bug real del gem `uri` 1.1.1 en este entorno, confirmado durante el brainstorming. Por eso se usan las variables sueltas `DB_HOST`/`POSTGRES_USER`/etc., que `config/database.yml` ya soporta como fallback y sí funcionan.)

- Hallazgo aparte, no relacionado a este plan, reportado al usuario por separado: el workflow "Publish Docker image" de GitHub Actions viene fallando en los últimos 3 pushes a `main`. No se investiga ni se arregla en este plan.

---

### Task 0: Levantar infraestructura de test local

**Files:** ninguno — solo containers Docker, no versionado.

- [ ] **Step 1: Verificar si `financespy_test_pg` ya existe (puede quedar de una sesión anterior)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'docker ps --filter name=financespy_test_pg --format "{{.Names}}\t{{.Status}}"'
```

Si ya aparece `Up ...`, saltar al Step 3. Si no aparece nada, seguir al Step 2.

- [ ] **Step 2: Levantar el Postgres de test, aislado, en la misma red que usan los containers de producción (para que puedan resolverse por nombre)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run -d --name financespy_test_pg --rm \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  --network financespy_financespy_net postgres:16
'
```

Expected: imprime un container ID largo (hex), sin error.

- [ ] **Step 3: Confirmar que levantó sano**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'sleep 3 && docker ps --filter name=financespy_test_pg --format "{{.Status}}"'
```

Expected: `Up N seconds` (o más).

- [ ] **Step 4: Cargar el schema actual en la base de test (primera vez, o si el schema cambió desde la última corrida)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails db:test:prepare 2>&1
'
```

Expected: sin output (silencioso = éxito) o líneas `-- create_table(...)`, sin excepción Ruby.

- [ ] **Step 5: Smoke test — confirmar que corre un test real existente**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/models/loan_test.rb 2>&1
'
```

Expected: `2 runs, 4 assertions, 0 failures, 0 errors, 0 skips`.

- [ ] **Step 6: Crear la rama de trabajo**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 'cd ~/financespy && git checkout -b feature/receivables && git push -u origin feature/receivables'
```

Expected: `Switched to a new branch 'feature/receivables'` seguido de confirmación de push.

---

### Task 1: Modelo `Receivable` + migración + registro en `Accountable::TYPES`

**Files:**
- Create: `db/migrate/20260818130000_create_receivables.rb`
- Create: `app/models/receivable.rb`
- Create: `test/models/receivable_test.rb`
- Modify: `app/models/concerns/accountable.rb` (línea `TYPES = %w[...]`)

**Interfaces:**
- Produce: clase `Receivable < ApplicationRecord` con `classification` (asset), `color`, `icon`, validación de `due_day` — consumido por Task 2 (controller/vistas) y Task 3 (`Transfer.kind_for_account`).

- [ ] **Step 1: Escribir el test que falla**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/test/models/receivable_test.rb <<'EOF'
require \"test_helper\"

class ReceivableTest < ActiveSupport::TestCase
  test \"classification is asset\" do
    assert_equal \"asset\", Receivable.classification
  end

  test \"accepts nil due_day\" do
    receivable = Receivable.new(due_day: nil)
    assert receivable.valid?
  end

  test \"accepts due_day within 1..31\" do
    receivable = Receivable.new(due_day: 15)
    assert receivable.valid?
  end

  test \"rejects due_day outside 1..31\" do
    receivable = Receivable.new(due_day: 32)
    assert_not receivable.valid?
    assert_includes receivable.errors[:due_day], \"is not included in the list\"
  end
end
EOF"
```

- [ ] **Step 2: Correr el test, confirmar que falla**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/models/receivable_test.rb 2>&1
'
```

Expected: `NameError: uninitialized constant Receivable` (o similar), 0 tests corridos con éxito.

- [ ] **Step 3: Escribir la migración**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/db/migrate/20260818130000_create_receivables.rb <<'EOF'
class CreateReceivables < ActiveRecord::Migration[7.2]
  def change
    create_table :receivables, id: :uuid do |t|
      t.decimal :total_amount, precision: 19, scale: 4
      t.integer :installment_count
      t.integer :due_day
      t.timestamps
    end
  end
end
EOF"
```

- [ ] **Step 4: Correr la migración contra la base de test (actualiza también `db/schema.rb`, versionado)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails db:migrate 2>&1
'
```

Expected: línea `== 20260818130000 CreateReceivables: migrating ...` seguida de `== ... migrated`, sin error.

- [ ] **Step 5: Escribir el modelo**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/app/models/receivable.rb <<'EOF'
class Receivable < ApplicationRecord
  include Accountable

  validates :due_day, inclusion: { in: 1..31 }, allow_nil: true

  def original_balance
    Money.new(account.first_valuation_amount, account.currency)
  end

  class << self
    def color
      \"#F79009\" # amber -- distinto de todos los colores ya usados por otros Accountable types
                  # (Loan #D444F1, CreditCard #F13636, Depository #875BF7, Investment #1570EF,
                  #  Crypto/OtherLiability #737373, Property #06AED4, Vehicle #F23E94, OtherAsset #12B76A)
    end

    def icon
      \"hand-heart\" # distinto de \"hand-coins\" (Loan)
    end

    def classification
      \"asset\"
    end
  end
end
EOF"
```

- [ ] **Step 6: Registrar `Receivable` en `Accountable::TYPES`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/models/concerns/accountable.rb')
old = '''TYPES = %w[Depository Investment Crypto Property Vehicle OtherAsset CreditCard Loan OtherLiability]'''
new = '''TYPES = %w[Depository Investment Crypto Property Vehicle OtherAsset CreditCard Loan OtherLiability Receivable]'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

Expected: `OK`.

(Nota: agregar al final del array hace que "Cuentas a Cobrar" ordene último entre los grupos de tipo asset en la página de Balance Sheet -- comportamiento por defecto, no especificado de otra forma en el spec.)

- [ ] **Step 7: Correr el test de nuevo, confirmar que pasa**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/models/receivable_test.rb 2>&1
'
```

Expected: `4 runs, 5 assertions, 0 failures, 0 errors, 0 skips`.

- [ ] **Step 8: Commit**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add db/migrate/20260818130000_create_receivables.rb db/schema.rb app/models/receivable.rb app/models/concerns/accountable.rb test/models/receivable_test.rb && git commit -m 'feat: agregar Receivable accountable type

Nuevo tipo de cuenta asset para Cuentas a Cobrar. Se integra al motor de
Balance Sheet/Net Worth ya existente sin codigo adicional -- solo
requiere estar en Accountable::TYPES.'"
```

---

### Task 2: Controller, rutas, vistas de alta/edición, locales, fixtures

**Files:**
- Create: `app/controllers/receivables_controller.rb`
- Create: `app/views/receivables/_form.html.erb`
- Create: `app/views/receivables/new.html.erb`
- Create: `app/views/receivables/edit.html.erb`
- Create: `config/locales/views/receivables/en.yml`
- Create: `config/locales/views/receivables/es.yml`
- Create: `test/controllers/receivables_controller_test.rb`
- Create: `test/fixtures/receivables.yml`
- Modify: `config/routes.rb` (agregar `resources :receivables`)
- Modify: `config/locales/views/accounts/en.yml` (bloque `types:`)
- Modify: `config/locales/views/accounts/es.yml` (bloque `types:`)
- Modify: `test/fixtures/accounts.yml` (agregar entrada `receivable:`)

**Interfaces:**
- Consume: `Receivable` (Task 1), concern `AccountableResource` ya existente (`app/controllers/concerns/accountable_resource.rb`, sin cambios), partial `accounts/form` ya existente (sin cambios).
- Produce: rutas `new_receivable_path`, `receivables_path`, `receivable_path` -- consumidas por Task 4 (índice) y Task 5 (nav).

- [ ] **Step 1: Fixture `test/fixtures/receivables.yml`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/test/fixtures/receivables.yml <<'EOF'
one:
  total_amount: 1282500
  installment_count: 6
  due_day: 13
EOF"
```

- [ ] **Step 2: Agregar entrada `receivable:` a `test/fixtures/accounts.yml`, junto a la de `loan:`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/test/fixtures/accounts.yml')
old = '''loan:
  family: dylan_family
  owner: family_admin
  name: Mortgage Loan
  balance: 500000
  currency: USD
  accountable_type: Loan
  accountable: one
  status: active'''
new = '''loan:
  family: dylan_family
  owner: family_admin
  name: Mortgage Loan
  balance: 500000
  currency: USD
  accountable_type: Loan
  accountable: one
  status: active

receivable:
  family: dylan_family
  owner: family_admin
  name: GYM Schatzi
  balance: 855000
  currency: USD
  accountable_type: Receivable
  accountable: one
  status: active'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 3: Escribir el test que falla (controller aun no existe)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/test/controllers/receivables_controller_test.rb <<'EOF'
require \"test_helper\"

class ReceivablesControllerTest < ActionDispatch::IntegrationTest
  include AccountableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:receivable)
  end

  test \"creates with receivable details\" do
    assert_difference -> { Account.count } => 1,
      -> { Receivable.count } => 1,
      -> { Valuation.count } => 1,
      -> { Entry.count } => 1 do
      post receivables_path, params: {
        account: {
          name: \"New Receivable\",
          balance: 100000,
          currency: \"USD\",
          institution_name: \"\",
          institution_domain: \"\",
          notes: \"Test receivable\",
          accountable_type: \"Receivable\",
          accountable_attributes: {
            total_amount: 100000,
            installment_count: 4,
            due_day: 10
          }
        }
      }
    end

    created_account = Account.order(:created_at).last

    assert_equal \"New Receivable\", created_account.name
    assert_equal 100000, created_account.balance
    assert_equal \"USD\", created_account.currency
    assert_equal 100000, created_account.accountable.total_amount.to_i
    assert_equal 4, created_account.accountable.installment_count
    assert_equal 10, created_account.accountable.due_day

    assert_redirected_to created_account
    assert_equal \"Receivable account created\", flash[:notice]
    assert_enqueued_with(job: SyncJob)
  end

  test \"updates with receivable details\" do
    assert_no_difference [ \"Account.count\", \"Receivable.count\" ] do
      patch receivable_path(@account), params: {
        account: {
          name: \"Updated Receivable\",
          balance: 90000,
          currency: \"USD\",
          accountable_type: \"Receivable\",
          accountable_attributes: {
            id: @account.accountable_id,
            total_amount: 120000,
            installment_count: 5,
            due_day: 20
          }
        }
      }
    end

    @account.reload

    assert_equal \"Updated Receivable\", @account.name
    assert_equal 90000, @account.balance
    assert_equal 120000, @account.accountable.total_amount.to_i
    assert_equal 5, @account.accountable.installment_count
    assert_equal 20, @account.accountable.due_day

    assert_redirected_to @account
    assert_equal \"Receivable account updated\", flash[:notice]
    assert_enqueued_with(job: SyncJob)
  end
end
EOF"
```

- [ ] **Step 4: Correr el test, confirmar que falla (falta el controller/rutas)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/controllers/receivables_controller_test.rb 2>&1
'
```

Expected: error de ruta indefinida (`undefined method 'receivables_path'` o `NameError`), 0 pasando.

- [ ] **Step 5: Agregar las rutas, junto a la línea de `loans` (línea 446 actual)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/config/routes.rb')
old = '''  resources :loans, only: %i[new create edit update]'''
new = '''  resources :loans, only: %i[new create edit update]
  resources :receivables, only: %i[index new create edit update]'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 6: Escribir el controller**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/app/controllers/receivables_controller.rb <<'EOF'
class ReceivablesController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(
    :id, :total_amount, :installment_count, :due_day
  )

  def index
    # .visible es el scope ya usado por BalanceSheet::NetWorthSeriesBuilder para
    # excluir cuentas ocultas/archivadas del calculo de patrimonio -- mismo criterio aca.
    accounts = Current.family.accounts.visible.where(accountable_type: \"Receivable\")
    @active = accounts.reject { |a| a.balance.zero? }
    @completed = accounts.select { |a| a.balance.zero? }
  end
end
EOF"
```

- [ ] **Step 7: Vista `_form.html.erb`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/app/views/receivables/_form.html.erb <<'EOF'
<%# locals: (account:, url:) %>

<%= render \"accounts/form\", account: account, url: url do |form| %>
  <%= render \"shared/ruler\", classes: \"my-4\" %>

  <div class=\"space-y-2\">
    <%= form.fields_for :accountable do |receivable_form| %>
      <%= receivable_form.money_field :total_amount,
                               label: t(\"receivables.form.total_amount\"),
                               default_currency: Current.family.currency,
                               required: true %>

      <div class=\"flex items-center gap-2\">
        <%= receivable_form.number_field :installment_count,
                               label: t(\"receivables.form.installment_count\"),
                               placeholder: t(\"receivables.form.installment_count_placeholder\") %>
        <%= receivable_form.number_field :due_day,
                               label: t(\"receivables.form.due_day\"),
                               placeholder: t(\"receivables.form.due_day_placeholder\"),
                               min: 1, max: 31 %>
      </div>
    <% end %>
  </div>
<% end %>
EOF"
```

- [ ] **Step 8: Vista `new.html.erb`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/app/views/receivables/new.html.erb <<'EOF'
<% if params[:step] == \"method_select\" %>
  <%= render \"accounts/new/method_selector\",
             path: new_receivable_path(return_to: params[:return_to]),
             provider_configs: @provider_configs,
             accountable_type: \"Receivable\" %>
<% else %>
  <%= render DS::Dialog.new do |dialog| %>
    <% dialog.with_header(title: t(\".title\")) %>
    <% dialog.with_body do %>
      <%= render \"receivables/form\", account: @account, url: receivables_path %>
    <% end %>
  <% end %>
<% end %>
EOF"
```

- [ ] **Step 9: Vista `edit.html.erb`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/app/views/receivables/edit.html.erb <<'EOF'
<%= render DS::Dialog.new do |dialog| %>
  <% dialog.with_header(title: t(\".edit\", account: @account.name)) %>
  <% dialog.with_body do %>
    <%= render \"form\", account: @account, url: receivable_path(@account) %>
  <% end %>
<% end %>
EOF"
```

- [ ] **Step 10: Locale `en.yml`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "mkdir -p ~/financespy/config/locales/views/receivables && cat > ~/financespy/config/locales/views/receivables/en.yml <<'EOF'
en:
  receivables:
    form:
      total_amount: Total amount
      installment_count: Number of installments (optional)
      installment_count_placeholder: '6'
      due_day: Due day (optional)
      due_day_placeholder: '13'
    new:
      title: Enter receivable details
    edit:
      edit: Edit %{account}
    dashboard:
      title: Cuentas a Cobrar
      register_payment: Register Payment
      completed: Completed (%{count})
EOF"
```

- [ ] **Step 11: Locale `es.yml`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/config/locales/views/receivables/es.yml <<'EOF'
es:
  receivables:
    form:
      total_amount: Monto total
      installment_count: Cantidad de cuotas (opcional)
      installment_count_placeholder: '6'
      due_day: Día de vencimiento (opcional)
      due_day_placeholder: '13'
    new:
      title: Ingresá los datos de la cuenta a cobrar
    edit:
      edit: Editar %{account}
    dashboard:
      title: Cuentas a Cobrar
      register_payment: Registrar Pago
      completed: Completadas (%{count})
EOF"
```

- [ ] **Step 12: Agregar `receivable` al bloque `types:` de `config/locales/views/accounts/en.yml`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/config/locales/views/accounts/en.yml')
old = '''      loan: Loan
      other_liability: Other Liability'''
new = '''      loan: Loan
      other_liability: Other Liability
      receivable: Receivable'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 13: Mismo agregado en `es.yml`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/config/locales/views/accounts/es.yml')
old = '''      loan: Préstamo
      other_liability: Otra deuda'''
new = '''      loan: Préstamo
      other_liability: Otra deuda
      receivable: Cuenta por cobrar'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 14: Correr el test de nuevo, confirmar que pasa**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/controllers/receivables_controller_test.rb 2>&1
'
```

Expected: `5 runs, N assertions, 0 failures, 0 errors, 0 skips` (2 tests propios + 3 de `AccountableResourceInterfaceTest`).

- [ ] **Step 15: Commit**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add app/controllers/receivables_controller.rb app/views/receivables/ config/routes.rb config/locales/views/receivables/ config/locales/views/accounts/en.yml config/locales/views/accounts/es.yml test/controllers/receivables_controller_test.rb test/fixtures/receivables.yml test/fixtures/accounts.yml && git commit -m 'feat: alta/edicion de Cuentas a Cobrar

Controller delgado via AccountableResource (mismo patron que Loan),
formulario con monto total + cuotas/vencimiento opcionales.'"
```

---

### Task 3: Extender `Transfer.kind_for_account` para Receivable

**Files:**
- Modify: `app/models/transfer.rb`
- Modify: `test/models/transfer_test.rb`

**Interfaces:**
- Consume: `accounts(:receivable)` fixture (Task 2).
- Produce: `Transfer.kind_for_account` devuelve `"receivable_collection"` para cuentas Receivable -- consumido por la UI de "Registrar Pago" (etiqueta visual del transfer, sin lógica adicional).

- [ ] **Step 1: Agregar el test que falla**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/test/models/transfer_test.rb')
old = '''  test \"kind_for_account returns loan_payment for loan accounts\" do
    assert_equal \"loan_payment\", Transfer.kind_for_account(accounts(:loan))
  end'''
new = '''  test \"kind_for_account returns loan_payment for loan accounts\" do
    assert_equal \"loan_payment\", Transfer.kind_for_account(accounts(:loan))
  end

  test \"kind_for_account returns receivable_collection for receivable accounts\" do
    assert_equal \"receivable_collection\", Transfer.kind_for_account(accounts(:receivable))
  end'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 2: Correr el test, confirmar que falla**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/models/transfer_test.rb -n "/kind_for_account/" 2>&1
'
```

Expected: 1 failure (`funds_movement` en vez de `receivable_collection`, el catch-all `else` branch).

- [ ] **Step 3: Extender `kind_for_account`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/models/transfer.rb')
old = '''      if account.loan?
        \"loan_payment\"
      elsif account.credit_card?'''
new = '''      if account.loan?
        \"loan_payment\"
      elsif account.receivable?
        \"receivable_collection\"
      elsif account.credit_card?'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 4: Correr el test, confirmar que pasa**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/models/transfer_test.rb 2>&1
'
```

Expected: todos los tests del archivo en verde, 0 failures, 0 errors.

- [ ] **Step 5: Commit**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add app/models/transfer.rb test/models/transfer_test.rb && git commit -m 'feat: etiquetar transfers de Receivable como receivable_collection'"
```

---

### Task 4: Página índice "Cuentas a Cobrar"

**Files:**
- Create: `app/views/receivables/index.html.erb`
- Create: `app/views/receivables/_card.html.erb`
- Modify: `test/fixtures/receivables.yml` (agregar entrada `two`, cuota completada)
- Modify: `test/fixtures/accounts.yml` (agregar cuenta `receivable_completed`)
- Modify: `test/controllers/receivables_controller_test.rb` (agregar test de `index`)

**Interfaces:**
- Consume: `ReceivablesController#index` (Task 2, ya escrito -- `@active`/`@completed`), `DS::ProgressRing` (componente ya existente en el codebase, visto en `app/components/goals/card_component.html.erb`).

- [ ] **Step 1: Agregar fixtures para tener un caso "completada" (balance cero) además del ya existente "activa"**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/test/fixtures/receivables.yml')
old = '''one:
  total_amount: 1282500
  installment_count: 6
  due_day: 13'''
new = '''one:
  total_amount: 1282500
  installment_count: 6
  due_day: 13

two:
  total_amount: 90000
  installment_count: 1
  due_day: null'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"

ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/test/fixtures/accounts.yml')
old = '''receivable:
  family: dylan_family
  owner: family_admin
  name: GYM Schatzi
  balance: 855000
  currency: USD
  accountable_type: Receivable
  accountable: one
  status: active'''
new = '''receivable:
  family: dylan_family
  owner: family_admin
  name: GYM Schatzi
  balance: 855000
  currency: USD
  accountable_type: Receivable
  accountable: one
  status: active

receivable_completed:
  family: dylan_family
  owner: family_admin
  name: Cena Javier
  balance: 0
  currency: USD
  accountable_type: Receivable
  accountable: two
  status: active'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 2: Agregar el test de `index` que falla (vista aun no existe)**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/test/controllers/receivables_controller_test.rb')
old = '''  test \"creates with receivable details\" do'''
new = '''  test \"index shows active and completed receivables separately\" do
    get receivables_path
    assert_response :success
    assert_match \"GYM Schatzi\", response.body
    assert_match \"Cena Javier\", response.body
  end

  test \"creates with receivable details\" do'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

- [ ] **Step 3: Correr el test, confirmar que falla**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/controllers/receivables_controller_test.rb -n "/index/" 2>&1
'
```

Expected: `ActionView::MissingTemplate` (falta `receivables/index`).

- [ ] **Step 4: Escribir el partial de card, reusando `DS::ProgressRing` (mismo componente que usa `Goals::CardComponent`) y las clases de card ya establecidas en el codebase**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/app/views/receivables/_card.html.erb <<'EOF'
<%# locals: (account:) %>
<% receivable = account.receivable %>
<% total = receivable.total_amount ? Money.new(receivable.total_amount, account.currency) : account.balance_money %>
<% pending = account.balance_money %>
<% progress_percent = total.amount.zero? ? 100 : (((total.amount - pending.amount) / total.amount) * 100).round %>

<div class=\"bg-container rounded-xl shadow-border-xs p-6\">
  <div class=\"flex items-start gap-3\">
    <div class=\"min-w-0 flex-1\">
      <p class=\"text-base font-medium text-primary truncate\"><%= account.name %></p>
      <% if receivable.due_day.present? %>
        <p class=\"text-xs text-subdued mt-0.5\"><%= t(\"receivables.form.due_day\") %>: <%= receivable.due_day %></p>
      <% end %>
    </div>
    <div class=\"shrink-0\">
      <%= render DS::ProgressRing.new(percent: progress_percent, tone: pending.amount.zero? ? :success : :neutral) %>
    </div>
  </div>

  <div class=\"mt-5\">
    <div class=\"flex items-baseline gap-1.5\">
      <span class=\"text-xl font-medium text-primary tabular-nums privacy-sensitive\"><%= pending.format(precision: 0) %></span>
      <span class=\"text-xs text-subdued tabular-nums privacy-sensitive\">/ <%= total.format(precision: 0) %></span>
    </div>
  </div>

  <% if pending.amount.positive? %>
    <div class=\"mt-4\">
      <%= link_to t(\"receivables.dashboard.register_payment\"),
          new_transfer_path(from_account_id: account.id),
          class: \"w-full inline-flex justify-center items-center rounded-lg bg-primary text-white text-sm font-medium py-2 px-4 hover:bg-primary/90 transition-colors\" %>
    </div>
  <% end %>
</div>
EOF"
```

- [ ] **Step 5: Escribir la vista índice**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cat > ~/financespy/app/views/receivables/index.html.erb <<'EOF'
<% content_for :page_title, t(\"receivables.dashboard.title\") %>

<div class=\"space-y-6\">
  <h1 class=\"text-xl font-medium text-primary\"><%= t(\"receivables.dashboard.title\") %></h1>

  <div class=\"grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4\">
    <% @active.each do |account| %>
      <%= render \"receivables/card\", account: account %>
    <% end %>
  </div>

  <% if @completed.any? %>
    <details class=\"mt-6\">
      <summary class=\"text-sm text-subdued cursor-pointer\">
        <%= t(\"receivables.dashboard.completed\", count: @completed.size) %>
      </summary>
      <div class=\"grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-4\">
        <% @completed.each do |account| %>
          <%= render \"receivables/card\", account: account %>
        <% end %>
      </div>
    </details>
  <% end %>
</div>
EOF"
```

- [ ] **Step 6: Correr el test, confirmar que pasa**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test test/controllers/receivables_controller_test.rb 2>&1
'
```

Expected: todos los tests del archivo en verde (6 tests: index + creates + updates + 3 de `AccountableResourceInterfaceTest`).

- [ ] **Step 7: Commit**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add app/views/receivables/index.html.erb app/views/receivables/_card.html.erb test/fixtures/receivables.yml test/fixtures/accounts.yml test/controllers/receivables_controller_test.rb && git commit -m 'feat: pagina indice Cuentas a Cobrar

Cards con DS::ProgressRing (mismo componente que Goals), agrupadas en
activas/completadas. Progreso calculado por monto, no por cantidad de
pagos -- decision del spec, los montos de cada pago son libres.'"
```

---

### Task 5: Nav item + push + PR

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Agregar el ítem al array `mobile_nav_items`, junto a `goals`**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "python3 - <<'PYEOF'
import pathlib
p = pathlib.Path('/home/fabrizio/financespy/app/views/layouts/application.html.erb')
old = '''    { name: t(\".nav.goals\"), path: goals_path, icon: \"target\", icon_custom: false, active: page_active?(goals_path) },'''
new = '''    { name: t(\".nav.goals\"), path: goals_path, icon: \"target\", icon_custom: false, active: page_active?(goals_path) },
    { name: t(\".nav.receivables\"), path: receivables_path, icon: \"hand-heart\", icon_custom: false, active: page_active?(receivables_path) },'''
content = p.read_text()
n = content.count(old)
assert n == 1, f'expected exactly 1 match, found {n}'
p.write_text(content.replace(old, new))
print('OK')
PYEOF"
```

(Nota: esto agrega un 6to item al bottom-nav móvil, en línea con el spec de Cuentas a Cobrar tal como fue aprobado. El spec de navegación personalizable (`docs/superpowers/specs/2026-08-18-financespy-bottom-nav-personalizable-design.md`), que aún no se implementó, va a refactorizar este mismo array a algo elegible por el usuario -- este Task deja el estado intermedio correcto: visible por defecto, sin romper nada.)

- [ ] **Step 2: Agregar el locale del nav item**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "grep -rn 'nav:' config/locales/views/layouts/application/es.yml 2>/dev/null || find ~/financespy/config/locales -iname '*application*' | grep -i layout"
```

Ejecutar este comando primero para confirmar la ruta exacta del locale del layout (no se asumió arriba con precisión de archivo:línea como el resto del plan). Con la ruta confirmada, agregar `receivables: Cuentas a Cobrar` (es) / `receivables: Receivables` (en) junto a la clave `goals:` existente dentro del bloque `nav:`, usando el mismo patrón de reemplazo exacto de string ya usado en los Tasks anteriores.

- [ ] **Step 3: Correr el suite completo, confirmar que nada se rompió**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 '
docker run --rm --network financespy_financespy_net \
  -e RAILS_ENV=test -e DB_HOST=financespy_test_pg -e DB_PORT=5432 \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sure_test \
  -e SECRET_KEY_BASE=test_secret_key_base_1234567890 \
  -v /home/fabrizio/financespy:/rails \
  financespy-web:latest \
  bin/rails test 2>&1 | tail -60
'
```

Expected: `0 failures, 0 errors` en el resumen final (puede haber skips preexistentes, no relacionados).

- [ ] **Step 4: Commit, push, abrir PR**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git add app/views/layouts/application.html.erb config/locales/views/layouts/ && git commit -m 'feat: agregar Cuentas a Cobrar a la navegacion movil'"
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && git push origin feature/receivables"
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && gh pr create --title 'feat: Cuentas a Cobrar' --body 'Implementa el spec docs/superpowers/specs/2026-08-17-financespy-cuentas-a-cobrar-design.md -- nuevo accountable type Receivable (asset), pagina indice, cobro de pagos via transferencia real entre cuentas.'"
```

Expected: URL de la PR creada. Esto dispara el workflow real `ci.yml` (`test`/`scan_ruby`) -- verificación final independiente del suite corrido localmente en Task 0-4.

- [ ] **Step 5: Confirmar que CI pasa**

```bash
ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && sleep 60 && gh pr checks"
```

Expected: todos los checks en verde. Si `ci / test` falla mientras que la corrida local (Step 3) pasó, investigar la diferencia antes de mergear -- no asumir que es flakiness sin confirmar.

---

## Self-Review

**Cobertura del spec:** modelo+migración+TYPES (Task 1) → controller/rutas/vistas/locales/fixtures de alta-edición (Task 2) → `Transfer.kind_for_account` (Task 3) → página índice con cards y agrupación activa/completada (Task 4) → nav item (Task 5). Los 4 edge cases del spec (sobrepago permitido, campos opcionales sin due_day/installment_count) no requieren código propio -- ya cubiertos por no tener validación de monto en el modelo y por `allow_nil` en `due_day`, confirmado con tests en Task 1.

**Placeholders:** ninguno -- cada step tiene comando/código real. Única excepción intencional y declarada: Task 5 Step 2 (locale del layout nav) pide confirmar la ruta exacta del archivo antes de editar, en vez de asumirla, porque no se exploró esa ruta específica durante el brainstorming (a diferencia de todo el resto del plan, que sí tiene archivo:línea verificado).

**Consistencia de tipos/nombres:** `Receivable`, `total_amount`, `installment_count`, `due_day` se declaran en Task 1 y se usan sin cambios de nombre en Tasks 2-4. `receivable_collection` (Task 3) coincide exacto con lo especificado en el spec. Verificado.

**Infra de testing:** validada en vivo durante el brainstorming (no es teórica) -- `financespy_test_pg` + el comando `docker run` de Global Constraints corrieron `test/models/loan_test.rb` con éxito real antes de escribir este plan.
