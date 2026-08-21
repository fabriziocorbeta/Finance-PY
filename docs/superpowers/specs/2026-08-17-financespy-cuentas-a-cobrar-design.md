---
title: "Cuentas a Cobrar — FinancePY"
created: 2026-08-17
status: approved
related:
  - "docs/superpowers/specs/2026-07-23-financespy-pwa-offline-design.md"
---

# Cuentas a Cobrar — FinancePY

## Contexto y objetivo

El usuario pidió agregar 3 secciones a FinancePY inspiradas en mibilletera.online (screenshots): Cuentas a Cobrar, Histórico, Proyecciones. Al ser 3 subsistemas independientes con puntos de partida muy distintos, se decidió partirlos en specs separados — este cubre solo **Cuentas a Cobrar**, la primera a implementar.

Exploración del código existente reveló que FinancePY (fork de Sure Finance) ya trae un motor completo de Balance Sheet / Net Worth (`app/models/balance_sheet/`, con rangos de período 7D/30D/90D/etc. idénticos a los de mibilletera) y un sistema de `Transfer` entre cuentas ya usado para pagos de Loan/CreditCard. La decisión de diseño central es **reusar toda esa infraestructura en vez de construir algo paralelo** — una Cuenta a Cobrar es una `Account` real del sistema, así que Histórico y patrimonio neto la reflejan automáticamente sin código nuevo ahí.

mibilletera.online es referencia solo de **estructura/funcionalidad** (qué datos mostrar, qué acciones ofrecer) — el estilo visual sigue el sistema de diseño ya existente de FinancePY, confirmado explícitamente por el usuario, no se copia la skin oscura/violeta de mibilletera.

## Alcance (confirmado con el usuario)

- Nuevo `Accountable` type `Receivable`, `classification: "asset"` — plata que te deben suma al patrimonio neto total, igual que cualquier otra cuenta.
- Progreso de cobro se calcula **por monto** `(total − saldo_pendiente) / total`, no por cantidad de pagos — los montos de cada pago son libres (no hay cuota fija obligatoria), así que contar pagos no daría un número confiable.
- "Registrar Pago" es una **transferencia real** entre la Cuenta a Cobrar y otra cuenta del usuario (efectivo, banco, etc.) — no una simple resta de saldo. Esto es necesario para que el patrimonio neto total quede siempre correcto: cobrar no te empobrece, solo mueve el activo de "me deben" a "lo tengo".
- `installment_count` y `due_day` son campos **opcionales**, puramente informativos (referencia de "plan original: N cuotas, vence el día D") — no se usan para ningún cálculo ni disparan recordatorios.
- Nav: se agrega como **6to tab** en el bottom-nav móvil (junto a Inicio/Transacciones/Reportes/Presupuestos/Metas) y en el sidebar desktop — el usuario prioriza tenerlo a mano en el celular sobre mantener la fila de 5 tabs sin apretar.
- Locales: solo `en` y `es` — el paquete de ~20 idiomas que trae `Loan` viene de la comunidad de Sure Finance upstream, no algo que este proyecto mantenga a mano.

Fuera de alcance explícito (YAGNI):
- Recordatorios/notificaciones de vencimiento basados en `due_day` — queda como dato de referencia visual únicamente.
- Multi-moneda especial — usa el mismo mecanismo de `Money`/conversión que cualquier otra cuenta del sistema, sin lógica extra.
- Migración de datos existentes — no hay "cuentas a cobrar" previas en el sistema que migrar.
- Histórico y Proyecciones — subsistemas aparte, brainstorming y specs propios, no incluidos acá.

## Arquitectura

Mismo patrón que `Loan` (accountable type ya existente en el codebase), en espejo casi exacto: modelo + migración + controller delgado vía el concern `AccountableResource` ya existente + rutas + vistas + locales + registro en `Accountable::TYPES`. La única pieza genuinamente nueva (sin equivalente directo en `Loan`) es la página índice "Cuentas a Cobrar" que agrupa activas/completadas — `Loan` no tiene una página así, sus cuentas aparecen en el listado genérico de cuentas.

### Modelo y datos

Migración `db/migrate/<timestamp>_create_receivables.rb`, tabla `receivables` (mismo estilo que `loans`: uuid pk):

```ruby
create_table :receivables, id: :uuid do |t|
  t.decimal :total_amount, precision: 19, scale: 4
  t.integer :installment_count
  t.integer :due_day
  t.timestamps
end
```

`app/models/receivable.rb`:

```ruby
class Receivable < ApplicationRecord
  include Accountable

  validates :due_day, inclusion: { in: 1..31 }, allow_nil: true

  def original_balance
    Money.new(account.first_valuation_amount, account.currency)
  end

  class << self
    def color
      "#F79009" # amber — distinto de todos los colores ya usados por otros Accountable types
                # (Loan #D444F1, CreditCard #F13636, Depository #875BF7, Investment #1570EF,
                #  Crypto/OtherLiability #737373, Property #06AED4, Vehicle #F23E94, OtherAsset #12B76A)
    end

    def icon
      "hand-heart" # distinto de "hand-coins" (Loan)
    end

    def classification
      "asset"
    end
  end
end
```

`app/models/concerns/accountable.rb`: agregar `"Receivable"` al array `TYPES` — es el único punto de registro central; `delegated_type` en `Account` genera automáticamente `account.receivable?`, y `BalanceSheet::ClassificationGroup` deriva ícono/color/nombre/orden del tipo sin código adicional.

**Saldo pendiente** = `account.balance`, calculado por el motor existente (`Balance::ChartSeriesBuilder`), igual que cualquier cuenta — no hay campo `pending_balance` propio, se deriva.

### Controller y formulario (alta/edición)

`app/controllers/receivables_controller.rb`, mismo patrón que `LoansController`:

```ruby
class ReceivablesController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(
    :id, :total_amount, :installment_count, :due_day
  )
end
```

`config/routes.rb`, junto a la línea de `loans` (línea 446 actual):

```ruby
resources :receivables, only: %i[index new create edit update]
```

(`:index` se agrega porque, a diferencia de `loans`, acá sí hay una página propia — ver más abajo.)

`app/views/receivables/_form.html.erb` (mismo patrón que `loans/_form.html.erb`, usando el wrapper genérico `accounts/form`):

```erb
<%# locals: (account:, url:) %>

<%= render "accounts/form", account: account, url: url do |form| %>
  <%= render "shared/ruler", classes: "my-4" %>

  <div class="space-y-2">
    <%= form.fields_for :accountable do |receivable_form| %>
      <%= receivable_form.money_field :total_amount,
                               label: t("receivables.form.total_amount"),
                               default_currency: Current.family.currency,
                               required: true %>

      <div class="flex items-center gap-2">
        <%= receivable_form.number_field :installment_count,
                               label: t("receivables.form.installment_count"),
                               placeholder: t("receivables.form.installment_count_placeholder") %>
        <%= receivable_form.number_field :due_day,
                               label: t("receivables.form.due_day"),
                               placeholder: t("receivables.form.due_day_placeholder"),
                               min: 1, max: 31 %>
      </div>
    <% end %>
  </div>
<% end %>
```

`app/views/receivables/new.html.erb` y `edit.html.erb`: copia literal de la estructura de `loans/new.html.erb` / `loans/edit.html.erb`, cambiando el título vía locale.

### Flujo de "Registrar Pago"

Reusa `TransfersController` tal cual existe hoy — no se crea ningún controller/acción nueva para esto. `TransfersController#new` ya acepta `from_account_id` como parámetro para preseleccionar la cuenta origen:

```erb
<%= link_to t("receivables.dashboard.register_payment"),
    new_transfer_path(from_account_id: receivable_account.id),
    class: "btn-primary" %>
```

El usuario llega al formulario de transferencia ya existente con la Cuenta a Cobrar preseleccionada como origen, elige la cuenta destino (dónde entró la plata) + monto + fecha, y `Transfer::Creator` (ya existente) crea el `outflow_transaction` en la Receivable y el `inflow_transaction` en la cuenta destino — el balance de ambas cuentas se recalcula automáticamente por el motor ya existente, y el patrimonio neto total no se mueve (correcto: es un movimiento entre dos activos propios).

`app/models/transfer.rb`, método `kind_for_account`, agregar una rama:

```ruby
def kind_for_account(account)
  if account.loan?
    "loan_payment"
  elsif account.receivable?
    "receivable_collection"
  elsif account.credit_card?
    "cc_payment"
  elsif account.investment? || account.crypto?
    "investment_contribution"
  elsif account.liability?
    "cc_payment"
  else
    "funds_movement"
  end
end
```

### Página índice "Cuentas a Cobrar"

Única pieza sin equivalente directo en `Loan`. `ReceivablesController#index`:

```ruby
def index
  # .visible es el scope ya usado por BalanceSheet::NetWorthSeriesBuilder para
  # excluir cuentas ocultas/archivadas del cálculo de patrimonio -- mismo criterio acá.
  accounts = Current.family.accounts.visible.where(accountable_type: "Receivable")
  @active = accounts.reject { |a| a.balance.zero? }
  @completed = accounts.select { |a| a.balance.zero? }
end
```

Vista `app/views/receivables/index.html.erb`: cards con el mismo layout de información que la referencia de mibilletera (Total, Saldo pendiente, barra de progreso, botón Registrar Pago) pero con los componentes de diseño ya existentes en FinancePY (mismo tipo de card/botón/badge que el resto de la app, no el estilo oscuro/violeta de la referencia). Progreso mostrado como `((total − saldo_pendiente) / total * 100).round` % + texto "Gs X pagado de Gs Y total". Sección "Completadas" colapsada por defecto, igual patrón que la referencia.

### Locales

`config/locales/views/receivables/en.yml` y `es.yml` (solo estos 2, no el paquete completo de idiomas que trae `Loan`):

```yaml
# en.yml
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
```

```yaml
# es.yml
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
```

`config/locales/views/accounts/en.yml` y `es.yml`, agregar bajo el bloque `types:` existente (junto a `loan:`/`other_liability:`):

```yaml
# en.yml, dentro de accounts.types
receivable: Receivable
```
```yaml
# es.yml, dentro de accounts.types
receivable: Cuenta por cobrar
```

### Navegación

`app/views/layouts/application.html.erb`, agregar al array `mobile_nav_items` (línea ~9, junto a `goals`), **sin** `mobile_only: true` (para que aparezca tanto en el bottom-nav móvil como en el sidebar desktop, por decisión explícita del usuario):

```ruby
{ name: t(".nav.receivables"), path: receivables_path, icon: "hand-heart", icon_custom: false, active: page_active?(receivables_path) },
```

Agregar `nav.receivables: "Cuentas a Cobrar"` (es) / `"Receivables"` (en) al locale del layout correspondiente.

## Testing

Sigue el patrón existente de tests del proyecto (Minitest, fixtures) — no hay suite nueva que armar, se extiende la ya existente:

- `test/models/receivable_test.rb` (mirror de `test/models/loan_test.rb`): valida `classification == "asset"`, `due_day` fuera de 1..31 falla validación, `due_day` nil es válido.
- `test/controllers/receivables_controller_test.rb` (mirror de `test/controllers/loans_controller_test.rb`): crear/editar una receivable vía el controller genérico `AccountableResource`.
- `test/fixtures/receivables.yml`: 1-2 fixtures de ejemplo (mirror de `test/fixtures/loans.yml`).
- Test manual (no automatizable sin datos reales de familia): crear una Receivable, registrar un pago vía `new_transfer_path(from_account_id: ...)`, confirmar que el saldo de la Receivable baja, el de la cuenta destino sube, y el patrimonio neto total (Dashboard) no cambia — clave para validar la decisión de diseño central de este spec.
