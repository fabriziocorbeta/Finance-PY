# FinancePY Android Offline — Fase 1 (transacciones: lectura + creación) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Empaquetar FinancePY como app Android instalable (Capacitor) y dar el primer slice real de offline-first: ver transacciones de los últimos 90 días sin conexión, y crear una transacción nueva sin conexión, sincronizando al volver la señal.

**Architecture:** Nuevo namespace `Sync::` en Rails expone un endpoint de pull (lectura paginada por checkpoint) y uno de push (solo creates, idempotentes por UUID generado en el cliente) para `Transaction`/`Entry`. En el cliente, dos stores IndexedDB manejados a mano (uno de cache de lectura, uno de cola de escritura) más un controller Stimulus que renderiza la lista offline y el form de creación. Capacitor envuelve la app completa (`server.url` remoto) para dar el shell instalable + acceso a push nativo más adelante.

**Tech Stack:** Ruby on Rails 7.2, PostgreSQL (Supabase), importmap (sin bundler), Stimulus, IndexedDB, Capacitor (Android).

## Global Constraints

- **No hay Node en el pipeline de este proyecto** — ni en el host de la VM, ni en ninguna etapa del `Dockerfile`. Todo el JS va por **importmap** (módulos ES planos, sin build step) y Tailwind usa su binario standalone. `package.json` existe solo para Biome (linter, corre en CI con `setup-node`). **Ninguna tarea de este plan puede introducir `npm install`, un bundler, ni una dependencia npm en runtime.** El único uso de npm/Node permitido es en la Tarea 5 (Capacitor), que corre en la máquina del desarrollador para generar el proyecto Android — nunca en el servidor ni en la imagen Docker.
- Ruby local está roto (2.6.6 vs 3.4.7 requerido) — **todo comando `bin/rails` corre dentro del container**: `docker exec financespy-worktree-web-1 bin/rails ...` (el container del stack de desarrollo aislado, ver Tarea 0 — **no** `financespy-web-1`, que es producción real sirviendo `finance.cd-co.com.py`).
- No hay test suite completo funcional (fixtures fallan por permisos de la DB de test en Supabase) — specs nuevos y acotados sí corren bien. Verificación manual en navegador real es el fallback esperado para JS/UI.
- Convención de signo ya establecida en `TransactionsController#entry_params`: `nature == "inflow" ? -amount : amount` — inflow (dinero entra) se guarda **negativo**, outflow (gasto) **positivo**. No inventar otra convención en el cliente.
- `Entry`/`Transaction` es un `delegated_type` (`Entry` tiene `account_id/date/name/amount/currency`, `Transaction` es el entryable con `category_id/merchant_id/kind/extra`). Todo create pasa por `account.entries.new(entryable: Transaction.new(...))`, nunca `Transaction.new` suelto.
- IDs de `entries`/`transactions`/`accounts` son **UUID** (`gen_random_uuid()`), no enteros.
- **CSP enforce está activo** (`CSP_REPORT_ONLY=false`). Todo `<script>` nuevo necesita nonce — usar helpers de Rails con `nonce: true`, nunca un `<script>` HTML crudo, y nunca atributos de evento inline (`onclick=`, `onchange=`) que los nonces no cubren. Este patrón ya causó bugs reales en este proyecto (2026-07-25 y 2026-08-04).
- Alcance: **solo lectura de los últimos 90 días + creación**. Editar una transacción existente offline (con `lock_version` y resolución de conflictos) queda para un plan posterior — no implementar edición offline en ninguna tarea.
- Crear una transacción offline **no permite elegir categoría** (queda "sin categorizar", estado ya soportado — ver `@uncategorized_count` en `TransactionsController#index`). Categorizar se hace después, online.
- Fixtures reales: `users(:family_admin)` (family `dylan_family`), `accounts(:depository)`, `entries(:transaction)`. Login en tests: `sign_in @user = users(:family_admin)` (helper en `test/test_helper.rb:80`).

---

### Task 0: Workspace aislado (worktree + stack Docker separado)

**Files:**
- Create: `compose.worktree.yml` (en el worktree, no en el checkout de producción)

**Interfaces:**
- Produces: un stack Docker de desarrollo (`financespy-worktree-web-1`, etc.) escuchando en `127.0.0.1:3001`, completamente separado de los containers de producción. Todas las tareas siguientes corren `docker exec` contra ese container.

- [ ] **Step 1: Crear el worktree en la VM**

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="cd /home/Fabrizio/financespy && git worktree add /home/Fabrizio/financespy-worktrees/android-offline-phase1 -b feature/android-offline-phase1"
```

Expected: `Preparing worktree (new branch 'feature/android-offline-phase1')` seguido de `HEAD is now at 5f3666f ...`

- [ ] **Step 2: Copiar el `.env` al worktree**

El `.env` no está en git (tiene credenciales) — hay que copiarlo para que el stack de desarrollo pueda arrancar:

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="cp /home/Fabrizio/financespy/.env /home/Fabrizio/financespy-worktrees/android-offline-phase1/.env"
```

- [ ] **Step 3: Crear el compose aislado**

Crear `/home/Fabrizio/financespy-worktrees/android-offline-phase1/compose.worktree.yml`:

```yaml
# Stack de desarrollo aislado para la rama feature/android-offline-phase1.
# NO toca los containers de producción (financespy-web-1/worker-1/redis-1/caddy-1).
# Puerto 3001 en loopback, red propia, volúmenes propios.
# Levantar SIEMPRE con -p financespy-wt para no colisionar con el proyecto compose de prod.

x-rails-env: &rails_env
  SECRET_KEY_BASE: ${SECRET_KEY_BASE:?requerido}
  DATABASE_URL: ${DATABASE_URL:?requerido}
  SELF_HOSTED: "true"
  RAILS_FORCE_SSL: "false"
  RAILS_ASSUME_SSL: "false"
  APP_DOMAIN: localhost
  PRODUCT_NAME: ${PRODUCT_NAME:-FinancePY}
  BRAND_NAME: ${BRAND_NAME:-CD & Co.}
  REDIS_URL: redis://redis:6379/1
  ONBOARDING_STATE: ${ONBOARDING_STATE:-closed}
  EXCHANGE_RATE_PROVIDER: ${EXCHANGE_RATE_PROVIDER:-yahoo_finance}
  CORS_ALLOWED_ORIGINS: http://localhost:3001
  CSP_REPORT_ONLY: "false"
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
  OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN:-}
  OPENAI_URI_BASE: ${OPENAI_URI_BASE:-}
  OPENAI_MODEL: ${OPENAI_MODEL:-}

services:
  web:
    build: .
    command: bin/rails server -b 0.0.0.0 -p 3000
    ports:
      - "127.0.0.1:3001:3000"
    restart: "no"
    environment:
      <<: *rails_env
      WEB_CONCURRENCY: "1"
    depends_on:
      redis:
        condition: service_healthy
    dns:
      - 8.8.8.8
      - 1.1.1.1
    networks:
      - wt_net
    mem_limit: 1g
    cpus: 0.75

  redis:
    image: redis:8.8
    restart: "no"
    command: redis-server --maxmemory 100mb --maxmemory-policy allkeys-lru
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - wt_net
    mem_limit: 128m
    cpus: 0.25

networks:
  wt_net:
    driver: bridge
```

Nota deliberada: **sin servicio `worker`** (Sidekiq no hace falta para verificar estos endpoints — los jobs se encolan igual, solo no se procesan) y **sin `caddy`** (se accede directo al puerto de Rails). Menos memoria, menos superficie. `restart: "no"` para que este stack no reviva solo tras un reboot de la VM.

- [ ] **Step 4: Levantar el stack aislado y verificar que NO tocó producción**

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="cd /home/Fabrizio/financespy-worktrees/android-offline-phase1 && sudo docker compose -p financespy-wt -f compose.worktree.yml up -d --build"
```

Verificar el estado de ambos stacks:

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

Expected: los 5 containers de producción (`financespy-web-1`, `financespy-worker-1`, `financespy-redis-1`, `financespy-caddy-1`, `financespy-test-db-1`) **con el mismo uptime que antes** (no recreados), más los 2 nuevos (`financespy-wt-web-1`, `financespy-wt-redis-1`).

Verificar que producción sigue sana:

```bash
curl -sI https://finance.cd-co.com.py/ | head -1
```

Expected: `HTTP/2 302` (redirect al login = sitio sano).

Verificar que el stack nuevo responde:

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="curl -sI http://127.0.0.1:3001/ | head -1"
```

Expected: `HTTP/1.1 302 Found`

- [ ] **Step 5: Commit del compose aislado**

```bash
cd /home/Fabrizio/financespy-worktrees/android-offline-phase1
git add compose.worktree.yml
git commit -m "chore: isolated docker stack for worktree development"
```

---

### Task 1: Endpoint de pull — `GET /sync/transactions`

**Files:**
- Create: `app/controllers/sync/transactions_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/sync/transactions_controller_test.rb`

**Interfaces:**
- Produces: `GET /sync/transactions?checkpoint[updated_at]=<ISO8601>&checkpoint[id]=<uuid>&limit=<int>` → JSON `{ "documents": [{ "id", "account_id", "name", "date", "amount", "currency", "notes", "category_id", "merchant_id", "kind", "updated_at" }], "checkpoint": { "updated_at", "id" }, "accounts": [{ "id", "name", "currency" }] }`. Las Tareas 3 y 4 consumen esta forma exacta.

- [ ] **Step 1: Ruta**

`config/routes.rb` — agregar antes de la línea `resources :transactions, only: %i[index new create show update destroy] do` (línea ~350):

```ruby
  namespace :sync do
    resources :transactions, only: [ :index ] do
      post :push, on: :collection
    end
  end
```

- [ ] **Step 2: Escribir el failing test**

Crear `test/controllers/sync/transactions_controller_test.rb`:

```ruby
require "test_helper"

class Sync::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "returns recent transactions for the family with a checkpoint" do
    get sync_transactions_path, as: :json

    assert_response :success
    body = JSON.parse(response.body)

    assert body.key?("documents")
    assert body.key?("checkpoint")
    assert body.key?("accounts")

    doc = body["documents"].find { |d| d["id"] == entries(:transaction).id }
    assert doc.present?, "expected entries(:transaction) in the pull response"
    assert_equal entries(:transaction).account_id, doc["account_id"]
    assert_equal "Starbucks", doc["name"]
  end

  test "excludes transactions older than the 90 day window" do
    old_entry = @account.entries.create!(
      name: "Too old",
      date: 91.days.ago.to_date,
      amount: 10,
      currency: "USD",
      entryable: Transaction.new
    )

    get sync_transactions_path, as: :json
    body = JSON.parse(response.body)

    refute body["documents"].any? { |d| d["id"] == old_entry.id }
  end

  test "excludes another family's transactions" do
    outside_account = families(:empty).accounts.create!(
      name: "Outside", currency: "USD", accountable: Depository.new
    )
    outside_entry = outside_account.entries.create!(
      name: "Not mine",
      date: Date.current,
      amount: 10,
      currency: "USD",
      entryable: Transaction.new
    )

    get sync_transactions_path, as: :json
    body = JSON.parse(response.body)

    refute body["documents"].any? { |d| d["id"] == outside_entry.id }
  end

  test "paginates via checkpoint" do
    get sync_transactions_path, params: { limit: 1 }, as: :json
    body = JSON.parse(response.body)

    assert_equal 1, body["documents"].size
    assert body["checkpoint"]["id"].present?
  end
end
```

- [ ] **Step 3: Correr el test, confirmar que falla**

Run: `gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker exec financespy-wt-web-1 bin/rails test test/controllers/sync/transactions_controller_test.rb"`
Expected: FAIL — `NameError: uninitialized constant Sync` o ruta no encontrada.

- [ ] **Step 4: Implementación**

Crear `app/controllers/sync/transactions_controller.rb`:

```ruby
class Sync::TransactionsController < ApplicationController
  PULL_WINDOW_DAYS = 90
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 200

  def index
    entries = pull_scope.limit(resolved_limit)

    render json: {
      documents: entries.map { |entry| serialize_entry(entry) },
      checkpoint: next_checkpoint(entries.last),
      accounts: Current.user.accessible_accounts.map { |a|
        { id: a.id, name: a.name, currency: a.currency }
      }
    }
  end

  private

    def resolved_limit
      limit = params[:limit].presence&.to_i || DEFAULT_LIMIT
      limit.clamp(1, MAX_LIMIT)
    end

    def pull_scope
      scope = Current.family.entries
        .joins(:account)
        .merge(Account.accessible_by(Current.user))
        .where(entryable_type: "Transaction")
        .where("entries.date >= ?", PULL_WINDOW_DAYS.days.ago.to_date)
        .order(updated_at: :asc, id: :asc)
        .includes(:transaction)

      updated_at = params.dig(:checkpoint, :updated_at)
      id = params.dig(:checkpoint, :id)

      return scope if updated_at.blank? || id.blank?

      scope.where(
        "(entries.updated_at, entries.id) > (?, ?)",
        Time.iso8601(updated_at), id
      )
    rescue ArgumentError
      # checkpoint con timestamp malformado — tratar como pull inicial
      scope
    end

    def next_checkpoint(last_entry)
      return { updated_at: params.dig(:checkpoint, :updated_at), id: params.dig(:checkpoint, :id) } if last_entry.nil?

      { updated_at: last_entry.updated_at.iso8601, id: last_entry.id }
    end

    def serialize_entry(entry)
      transaction = entry.transaction

      {
        id: entry.id,
        account_id: entry.account_id,
        name: entry.name,
        date: entry.date.iso8601,
        amount: entry.amount.to_s,
        currency: entry.currency,
        notes: entry.notes,
        category_id: transaction.category_id,
        merchant_id: transaction.merchant_id,
        kind: transaction.kind,
        updated_at: entry.updated_at.iso8601
      }
    end
end
```

- [ ] **Step 5: Correr el test, confirmar que pasa**

Run: `gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker exec financespy-wt-web-1 bin/rails test test/controllers/sync/transactions_controller_test.rb"`
Expected: PASS — `4 runs, ... 0 failures, 0 errors`

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/sync/transactions_controller.rb test/controllers/sync/transactions_controller_test.rb
git commit -m "feat: add GET /sync/transactions pull endpoint for offline replication"
```

---

### Task 2: Endpoint de push — `POST /sync/transactions/push` (solo creates)

**Files:**
- Modify: `app/controllers/sync/transactions_controller.rb`
- Test: `test/controllers/sync/transactions_controller_test.rb`

**Interfaces:**
- Consumes: la ruta ya definida en Task 1.
- Produces: `POST /sync/transactions/push` con body `{ "rows": [{ "id", "account_id", "name", "date", "amount", "currency", "notes" }] }` → JSON `{ "applied": [<uuid>], "rejected": [{ "id", "reason" }] }`. La Tarea 4 consume esta forma exacta.

- [ ] **Step 1: Escribir el failing test**

Agregar a `test/controllers/sync/transactions_controller_test.rb`, antes del `end` final de la clase:

```ruby
  test "push creates a transaction using the client-generated id" do
    new_id = SecureRandom.uuid

    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post push_sync_transactions_path, params: {
        rows: [ {
          id: new_id,
          account_id: @account.id,
          name: "Offline coffee",
          date: Date.current.iso8601,
          amount: "5.5",
          currency: "USD",
          notes: nil
        } ]
      }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ new_id ], body["applied"]
    assert_equal [], body["rejected"]

    created = Entry.find(new_id)
    assert_equal "Offline coffee", created.name
    assert_equal @account, created.account
    assert_equal 5.5, created.amount.to_f
  end

  test "push is idempotent when the same row is replayed" do
    new_id = SecureRandom.uuid
    row = {
      id: new_id, account_id: @account.id, name: "Once",
      date: Date.current.iso8601, amount: "1", currency: "USD", notes: nil
    }

    post push_sync_transactions_path, params: { rows: [ row ] }, as: :json
    assert_equal [ new_id ], JSON.parse(response.body)["applied"]

    assert_no_difference [ "Entry.count", "Transaction.count" ] do
      post push_sync_transactions_path, params: { rows: [ row ] }, as: :json
    end

    assert_response :success
    assert_equal [ new_id ], JSON.parse(response.body)["applied"]
    assert_equal [], JSON.parse(response.body)["rejected"]
  end

  test "push rejects a row targeting an inaccessible account" do
    outside_account = families(:empty).accounts.create!(
      name: "Outside", currency: "USD", accountable: Depository.new
    )
    new_id = SecureRandom.uuid

    assert_no_difference [ "Entry.count", "Transaction.count" ] do
      post push_sync_transactions_path, params: {
        rows: [ {
          id: new_id, account_id: outside_account.id, name: "x",
          date: Date.current.iso8601, amount: "1", currency: "USD"
        } ]
      }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal [], body["applied"]
    assert_equal 1, body["rejected"].size
    assert_equal new_id, body["rejected"].first["id"]
    assert_equal "account_not_accessible", body["rejected"].first["reason"]
  end

  test "push rejects an invalid row without aborting the valid ones" do
    good_id = SecureRandom.uuid
    bad_id = SecureRandom.uuid

    assert_difference [ "Entry.count" ], 1 do
      post push_sync_transactions_path, params: {
        rows: [
          { id: good_id, account_id: @account.id, name: "Valid", date: Date.current.iso8601, amount: "2", currency: "USD" },
          { id: bad_id, account_id: @account.id, name: "", date: Date.current.iso8601, amount: "3", currency: "USD" }
        ]
      }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal [ good_id ], body["applied"]
    assert_equal bad_id, body["rejected"].first["id"]
    assert_equal "invalid", body["rejected"].first["reason"]
  end
```

- [ ] **Step 2: Correr, confirmar que falla**

Run: `gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker exec financespy-wt-web-1 bin/rails test test/controllers/sync/transactions_controller_test.rb"`
Expected: FAIL — `AbstractController::ActionNotFound` / la acción `push` no existe.

- [ ] **Step 3: Implementación**

En `app/controllers/sync/transactions_controller.rb`, agregar la acción pública `push` justo después de `index`:

```ruby
  def push
    applied = []
    rejected = []

    rows_params.each do |row|
      result = apply_push_row(row)

      if result[:ok]
        applied << result[:id]
      else
        rejected << { id: result[:id], reason: result[:reason] }
      end
    end

    render json: { applied: applied, rejected: rejected }
  end
```

Y en la sección `private`, agregar:

```ruby
    def rows_params
      params.permit(rows: [ :id, :account_id, :name, :date, :amount, :currency, :notes ])
            .require(:rows)
    end

    def apply_push_row(row)
      id = row[:id]

      # Replay de un push que ya se aplicó — éxito idempotente, no se re-crea.
      return { ok: true, id: id } if Entry.exists?(id: id)

      account = Current.user.accessible_accounts.find_by(id: row[:account_id])
      return { ok: false, id: id, reason: "account_not_accessible" } if account.nil?

      entry = account.entries.new(
        id: id,
        name: row[:name],
        date: row[:date],
        amount: row[:amount],
        currency: row[:currency],
        notes: row[:notes],
        entryable: Transaction.new
      )

      if entry.save
        entry.sync_account_later
        { ok: true, id: id }
      else
        Rails.logger.warn("[sync push] rejected #{id}: #{entry.errors.full_messages.join(', ')}")
        { ok: false, id: id, reason: "invalid" }
      end
    end
```

- [ ] **Step 4: Correr, confirmar que pasa**

Run: `gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker exec financespy-wt-web-1 bin/rails test test/controllers/sync/transactions_controller_test.rb"`
Expected: PASS — `8 runs, ... 0 failures, 0 errors`

- [ ] **Step 5: Commit**

```bash
git add app/controllers/sync/transactions_controller.rb test/controllers/sync/transactions_controller_test.rb
git commit -m "feat: add POST /sync/transactions/push endpoint, idempotent creates only"
```

---

### Task 3: Capa de datos offline (IndexedDB, módulos ES planos vía importmap)

**Files:**
- Create: `app/javascript/services/offline_transactions_db.js`
- Create: `app/javascript/services/offline_transactions_sync.js`

**Interfaces:**
- Consumes: `GET /sync/transactions` y `POST /sync/transactions/push` (Tareas 1-2).
- Produces:
  - De `offline_transactions_db.js`: `cacheDocuments(docs)`, `getCachedTransactions(limit)` → `Promise<Array<doc>>`, `queueWrite(doc)`, `getQueuedWrites()` → `Promise<Array<doc>>`, `deleteQueuedWrite(id)`, `saveCheckpoint(cp)`, `getCheckpoint()` → `Promise<{updated_at,id}|null>`, `saveAccounts(accounts)`, `getAccounts()` → `Promise<Array<{id,name,currency}>>`.
  - De `offline_transactions_sync.js`: `pullTransactions()` → `Promise<void>`, `pushQueuedWrites()` → `Promise<{applied:number, rejected:number}>`, `syncNow()` → `Promise<void>`.
  - La Tarea 4 (Stimulus controller) consume ambos módulos por esos nombres exactos.

- [ ] **Step 1: Store IndexedDB**

Crear `app/javascript/services/offline_transactions_db.js`. Sigue el mismo estilo de callbacks-envueltos-en-Promise que `app/javascript/services/offline_sales_db.js`, que ya existe y funciona en producción:

```js
const DB_NAME = "financespy_offline_transactions";
const DB_VERSION = 1;
const CACHE_STORE = "transactions_cache";
const QUEUE_STORE = "pending_transaction_writes";
const META_STORE = "sync_meta";

function openDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(CACHE_STORE)) {
        const cache = db.createObjectStore(CACHE_STORE, { keyPath: "id" });
        cache.createIndex("by_date", "date");
      }
      if (!db.objectStoreNames.contains(QUEUE_STORE)) {
        db.createObjectStore(QUEUE_STORE, { keyPath: "id" });
      }
      if (!db.objectStoreNames.contains(META_STORE)) {
        db.createObjectStore(META_STORE, { keyPath: "key" });
      }
    };
    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject(event.target.error);
  });
}

function runTransaction(storeName, mode, work) {
  return openDb().then(
    (db) =>
      new Promise((resolve, reject) => {
        const tx = db.transaction(storeName, mode);
        const store = tx.objectStore(storeName);
        let result;
        try {
          result = work(store);
        } catch (error) {
          reject(error);
          return;
        }
        tx.oncomplete = () => resolve(result && result.__request ? result.value : result);
        tx.onerror = (event) => reject(event.target.error);
      })
  );
}

function requestValue(request) {
  const holder = { __request: true, value: undefined };
  request.onsuccess = (event) => {
    holder.value = event.target.result;
  };
  return holder;
}

export function cacheDocuments(docs) {
  if (!docs.length) return Promise.resolve();
  return runTransaction(CACHE_STORE, "readwrite", (store) => {
    for (const doc of docs) store.put(doc);
  });
}

export function getCachedTransactions(limit = 100) {
  return runTransaction(CACHE_STORE, "readonly", (store) =>
    requestValue(store.getAll())
  ).then((all) =>
    (all || [])
      .sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0))
      .slice(0, limit)
  );
}

export function queueWrite(doc) {
  return runTransaction(QUEUE_STORE, "readwrite", (store) => {
    store.put(doc);
  });
}

export function getQueuedWrites() {
  return runTransaction(QUEUE_STORE, "readonly", (store) =>
    requestValue(store.getAll())
  ).then((all) => all || []);
}

export function deleteQueuedWrite(id) {
  return runTransaction(QUEUE_STORE, "readwrite", (store) => {
    store.delete(id);
  });
}

export function saveCheckpoint(checkpoint) {
  return runTransaction(META_STORE, "readwrite", (store) => {
    store.put({ key: "checkpoint", value: checkpoint });
  });
}

export function getCheckpoint() {
  return runTransaction(META_STORE, "readonly", (store) =>
    requestValue(store.get("checkpoint"))
  ).then((record) => (record ? record.value : null));
}

export function saveAccounts(accounts) {
  return runTransaction(META_STORE, "readwrite", (store) => {
    store.put({ key: "accounts", value: accounts });
  });
}

export function getAccounts() {
  return runTransaction(META_STORE, "readonly", (store) =>
    requestValue(store.get("accounts"))
  ).then((record) => (record ? record.value : []));
}
```

- [ ] **Step 2: Capa de sincronización**

Crear `app/javascript/services/offline_transactions_sync.js`:

```js
import {
  cacheDocuments,
  getCheckpoint,
  saveCheckpoint,
  saveAccounts,
  getQueuedWrites,
  deleteQueuedWrite,
} from "services/offline_transactions_db";

const PULL_BATCH_SIZE = 100;
const MAX_PULL_PAGES = 20;

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content;
}

export async function pullTransactions() {
  let checkpoint = await getCheckpoint();

  for (let page = 0; page < MAX_PULL_PAGES; page++) {
    const url = new URL("/sync/transactions", window.location.origin);
    url.searchParams.set("limit", String(PULL_BATCH_SIZE));
    if (checkpoint?.updated_at && checkpoint?.id) {
      url.searchParams.set("checkpoint[updated_at]", checkpoint.updated_at);
      url.searchParams.set("checkpoint[id]", checkpoint.id);
    }

    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      credentials: "same-origin",
    });
    if (!response.ok) throw new Error(`pull failed: ${response.status}`);

    const body = await response.json();

    await cacheDocuments(body.documents || []);
    if (body.accounts) await saveAccounts(body.accounts);

    if (body.checkpoint?.id) {
      checkpoint = body.checkpoint;
      await saveCheckpoint(checkpoint);
    }

    if (!body.documents || body.documents.length < PULL_BATCH_SIZE) break;
  }
}

export async function pushQueuedWrites() {
  const queued = await getQueuedWrites();
  if (!queued.length) return { applied: 0, rejected: 0 };

  const response = await fetch("/sync/transactions/push", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": csrfToken(),
    },
    credentials: "same-origin",
    body: JSON.stringify({ rows: queued }),
  });
  if (!response.ok) throw new Error(`push failed: ${response.status}`);

  const body = await response.json();

  for (const id of body.applied || []) {
    await deleteQueuedWrite(id);
  }

  // Las filas rechazadas se dejan en la cola a propósito: se muestran como
  // "necesita revisión" en la UI en vez de borrarse en silencio.
  return { applied: (body.applied || []).length, rejected: (body.rejected || []).length };
}

export async function syncNow() {
  if (!navigator.onLine) return;
  await pushQueuedWrites();
  await pullTransactions();
}
```

- [ ] **Step 3: Verificar que importmap los expone (sin cambios de config)**

`config/importmap.rb` ya tiene `pin_all_from "app/javascript/services", under: "services", to: "services"` — los dos archivos nuevos quedan disponibles automáticamente como `services/offline_transactions_db` y `services/offline_transactions_sync`, igual que el `offline_sales_db` existente. **No hace falta editar `importmap.rb`.**

Confirmar que Rails los ve:

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker exec financespy-wt-web-1 bin/importmap json | grep offline"
```

Expected: aparecen `services/offline_sales_db`, `services/offline_transactions_db` y `services/offline_transactions_sync`.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/services/offline_transactions_db.js app/javascript/services/offline_transactions_sync.js
git commit -m "feat: IndexedDB cache + sync layer for offline transactions"
```

---

### Task 4: UI Stimulus — lista offline + form de creación

**Files:**
- Create: `app/javascript/controllers/offline_transactions_controller.js`
- Modify: `app/views/transactions/index.html.erb`

**Interfaces:**
- Consumes: `services/offline_transactions_db` y `services/offline_transactions_sync` (Task 3).

- [ ] **Step 1: Controller Stimulus**

Crear `app/javascript/controllers/offline_transactions_controller.js`:

```js
import { Controller } from "@hotwired/stimulus";
import { getCachedTransactions, getAccounts, queueWrite } from "services/offline_transactions_db";
import { syncNow } from "services/offline_transactions_sync";

// Connects to data-controller="offline-transactions"
export default class extends Controller {
  static targets = ["onlineContent", "offlineContent", "list", "accountSelect", "form"];

  connect() {
    this.boundRefresh = () => this.refresh();
    window.addEventListener("online", this.boundRefresh);
    window.addEventListener("offline", this.boundRefresh);
    this.refresh();
  }

  disconnect() {
    window.removeEventListener("online", this.boundRefresh);
    window.removeEventListener("offline", this.boundRefresh);
  }

  async refresh() {
    if (navigator.onLine) {
      this.onlineContentTarget.classList.remove("hidden");
      this.offlineContentTarget.classList.add("hidden");
      try {
        await syncNow();
      } catch (error) {
        console.warn("[offline] sync failed", error);
      }
      return;
    }

    this.onlineContentTarget.classList.add("hidden");
    this.offlineContentTarget.classList.remove("hidden");
    await this.renderAccounts();
    await this.renderList();
  }

  async renderAccounts() {
    const accounts = await getAccounts();
    this.accountSelectTarget.innerHTML = accounts
      .map((a) => `<option value="${a.id}" data-currency="${a.currency}">${this.escape(a.name)}</option>`)
      .join("");
  }

  async renderList() {
    const docs = await getCachedTransactions(100);
    if (!docs.length) {
      this.listTarget.innerHTML = `<p class="text-sm text-secondary py-4">No hay movimientos guardados localmente todavía.</p>`;
      return;
    }
    this.listTarget.innerHTML = docs.map((doc) => this.rowHtml(doc)).join("");
  }

  rowHtml(doc) {
    const amount = Number.parseFloat(doc.amount);
    const isInflow = amount < 0;
    const sign = isInflow ? "+" : "-";
    const color = isInflow ? "text-green-600" : "text-primary";
    const pendingBadge = doc.__pending
      ? `<span class="text-xs bg-yellow-100 text-yellow-800 rounded px-1.5 py-0.5 ml-2">pendiente</span>`
      : "";

    return `<div class="flex justify-between items-center py-2 border-b border-secondary">
      <div>
        <div class="font-medium text-primary">${this.escape(doc.name)}${pendingBadge}</div>
        <div class="text-sm text-secondary">${doc.date}</div>
      </div>
      <div class="font-mono ${color}">${sign}${Math.abs(amount).toFixed(2)} ${this.escape(doc.currency)}</div>
    </div>`;
  }

  async submitOffline(event) {
    event.preventDefault();

    const form = this.formTarget;
    const selectedOption = this.accountSelectTarget.selectedOptions[0];
    if (!selectedOption) return;

    const rawAmount = Number.parseFloat(form.querySelector('[name="amount"]').value || "0");
    const nature = form.querySelector('[name="nature"]').value;
    // Misma convención que TransactionsController#entry_params:
    // inflow se guarda negativo, outflow positivo.
    const signedAmount = nature === "inflow" ? -Math.abs(rawAmount) : Math.abs(rawAmount);

    const doc = {
      id: crypto.randomUUID(),
      account_id: selectedOption.value,
      name: form.querySelector('[name="name"]').value,
      date: form.querySelector('[name="date"]').value,
      amount: signedAmount.toString(),
      currency: selectedOption.dataset.currency,
      notes: null,
    };

    await queueWrite(doc);
    // Se cachea también para que aparezca inmediatamente en la lista offline.
    const { cacheDocuments } = await import("services/offline_transactions_db");
    await cacheDocuments([{ ...doc, __pending: true, updated_at: new Date().toISOString() }]);

    form.reset();
    await this.renderList();
  }

  escape(value) {
    const div = document.createElement("div");
    div.textContent = value == null ? "" : String(value);
    return div.innerHTML;
  }
}
```

- [ ] **Step 2: Vista**

En `app/views/transactions/index.html.erb`, envolver el contenido existente. Leer el archivo primero para ubicar el nodo raíz del contenido, y aplicar esta estructura — el contenido actual va **dentro** de `onlineContent`, sin modificarlo:

```erb
<div data-controller="offline-transactions">
  <div data-offline-transactions-target="onlineContent">
    <%# ↓↓↓ TODO el contenido actual de la vista va acá, sin cambios ↓↓↓ %>
  </div>

  <div data-offline-transactions-target="offlineContent" class="hidden p-4">
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-4 text-sm text-yellow-800">
      Sin conexión — mostrando los últimos movimientos guardados en este dispositivo.
    </div>

    <form data-offline-transactions-target="form"
          data-action="submit->offline-transactions#submitOffline"
          class="mb-6 space-y-2">
      <select name="account_id" data-offline-transactions-target="accountSelect" required
              class="w-full border border-secondary rounded-lg p-2 bg-container"></select>
      <input type="text" name="name" placeholder="Descripción" required
             class="w-full border border-secondary rounded-lg p-2 bg-container">
      <input type="date" name="date" required
             class="w-full border border-secondary rounded-lg p-2 bg-container">
      <input type="number" step="0.01" name="amount" placeholder="Monto" required
             class="w-full border border-secondary rounded-lg p-2 bg-container">
      <select name="nature" required
              class="w-full border border-secondary rounded-lg p-2 bg-container">
        <option value="outflow">Gasto</option>
        <option value="inflow">Ingreso</option>
      </select>
      <button type="submit" class="w-full bg-inverse text-inverse rounded-lg p-2 font-medium">
        Guardar sin conexión
      </button>
    </form>

    <div data-offline-transactions-target="list"></div>
  </div>
</div>
```

Nota: el `data-action="submit->..."` de Stimulus es la forma correcta bajo CSP enforce — **no** usar `onsubmit=` inline, que el CSP bloquea silenciosamente.

- [ ] **Step 3: Verificación manual — online**

Abrir `http://127.0.0.1:3001/transactions` (túnel SSH desde la Mac: `gcloud compute ssh alejandro-vm --zone=us-central1-a -- -L 3001:127.0.0.1:3001`, después abrir `http://localhost:3001/transactions` en el navegador).

Loguearse. Confirmar: la vista se ve igual que siempre. En DevTools → Application → IndexedDB, confirmar que existe `financespy_offline_transactions` con `transactions_cache` poblado (el `syncNow()` del `connect()` hizo el pull).

- [ ] **Step 4: Verificación manual — offline**

DevTools → Network → Offline. Recargar. Confirmar: aparece el aviso amarillo, el select de cuentas poblado, y la lista de movimientos cacheados.

Completar el form y enviarlo. Confirmar: aparece arriba de la lista con el badge "pendiente", sin llamadas de red.

- [ ] **Step 5: Verificación manual — reconexión**

DevTools → Network → Online. Recargar. Confirmar en la pestaña Network un `POST /sync/transactions/push` con `200`. Confirmar que la transacción creada offline aparece ahora en la lista real server-rendered de `/transactions`.

Verificar server-side que se creó de verdad:

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker exec financespy-wt-web-1 bin/rails runner 'e = Entry.order(created_at: :desc).first; puts \"#{e.name} | #{e.amount} | #{e.date}\"'"
```

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/offline_transactions_controller.js app/views/transactions/index.html.erb
git commit -m "feat: offline transactions list and creation form"
```

---

### Task 5: Empaquetado Capacitor (shell Android instalable)

**Files:**
- Create: `capacitor.config.json`
- Create: `android/` (generado por `cap add android`, no editado a mano)
- Modify: `.gitignore`

**Interfaces:** ninguna — empaqueta lo construido en las Tareas 1-4, no agrega lógica nueva.

**Nota sobre dónde corre esto:** a diferencia de todas las tareas anteriores, **esta corre en la máquina del desarrollador (la Mac, que tiene Node v24.11.1), no en la VM ni en el container.** Capacitor solo genera el shell nativo; no toca el servidor ni la imagen Docker. Requiere Android Studio instalado localmente.

- [ ] **Step 1: Instalar Capacitor como dependencia de desarrollo**

```bash
npm install --save-dev @capacitor/core @capacitor/cli @capacitor/android
```

Va a `devDependencies` a propósito: nada de esto se instala ni se usa en el servidor.

- [ ] **Step 2: Inicializar**

```bash
npx cap init "FinancePY" "com.cdco.financespy" --web-dir=public
```

- [ ] **Step 3: Apuntar el WebView al dominio real**

Editar `capacitor.config.json` (generado por el paso anterior) para agregar la clave `server`:

```json
{
  "appId": "com.cdco.financespy",
  "appName": "FinancePY",
  "webDir": "public",
  "server": {
    "url": "https://finance.cd-co.com.py",
    "cleartext": false
  }
}
```

Usar siempre el dominio, nunca una IP — es estable independientemente de dónde termine corriendo el server (VM GCP o notebook, según el estado de la migración de hosting documentada en `wiki/decisiones/FinancePY - Hosting fase prueba (PC local).md` del vault).

- [ ] **Step 4: Generar el proyecto Android**

```bash
npx cap add android
```

Crea `android/` en la raíz del repo. **Distinto de `mobile/android/`**, que es un scaffold Flutter heredado del fork de Sure, sin usar — no tocarlo ni confundirlo.

- [ ] **Step 5: `.gitignore` para artefactos de build**

Agregar a `.gitignore`:

```
android/app/build/
android/.gradle/
android/local.properties
*.keystore
*.jks
```

- [ ] **Step 6: Abrir en Android Studio y generar el APK**

```bash
npx cap open android
```

En Android Studio: Build → Generate Signed Bundle/APK → APK → crear keystore nuevo (**guardarlo fuera del repo**, ya está en `.gitignore`) → variant `release`.

- [ ] **Step 7: Verificación en dispositivo real**

Instalar: `adb install app-release.apk`

Abrir la app, loguearse (login dentro del WebView de Capacitor — es aislado del Chrome del sistema, así que pide credenciales la primera vez; es lo esperado, no un bug). Confirmar que `/transactions` carga igual que en el navegador.

Poner el dispositivo en **modo avión**. Confirmar que la lista offline y el form de creación funcionan igual que lo verificado en DevTools. Sacar el modo avión, confirmar que sincroniza.

- [ ] **Step 8: Commit**

```bash
git add capacitor.config.json package.json package-lock.json android/ .gitignore
git commit -m "feat: package FinancePY as installable Android app via Capacitor"
```

---

### Task 6: Cierre — merge y limpieza del workspace

- [ ] **Step 1: Correr toda la suite de tests nuevos una última vez**

```bash
gcloud compute ssh alejandro-vm --zone=us-central1-a --command="sudo docker exec financespy-wt-web-1 bin/rails test test/controllers/sync/transactions_controller_test.rb"
```

Expected: `8 runs, ... 0 failures, 0 errors`

- [ ] **Step 2: Lint del JS nuevo (Biome, igual que CI)**

```bash
npx @biomejs/biome check app/javascript/services/offline_transactions_db.js app/javascript/services/offline_transactions_sync.js app/javascript/controllers/offline_transactions_controller.js
```

Corregir lo que reporte antes de mergear — CI corre esto y falla el build si no pasa.

- [ ] **Step 3: Merge a main**

```bash
cd /home/Fabrizio/financespy
git merge feature/android-offline-phase1
git push
```

- [ ] **Step 4: Bajar el stack de desarrollo aislado**

```bash
cd /home/Fabrizio/financespy-worktrees/android-offline-phase1
sudo docker compose -p financespy-wt -f compose.worktree.yml down
```

**Cuidado:** especificar siempre `-p financespy-wt` y el `-f compose.worktree.yml`. Un `docker compose down` sin esos flags, corrido desde el directorio equivocado, puede tumbar producción — pasó de verdad el 2026-07-28 (ver el warning en `compose.prod.yml`).

- [ ] **Step 5: Eliminar el worktree**

```bash
cd /home/Fabrizio/financespy
git worktree remove /home/Fabrizio/financespy-worktrees/android-offline-phase1
```

- [ ] **Step 6: Deploy a producción — SOLO con confirmación explícita del usuario**

**No ejecutar automáticamente.** El merge a `main` no despliega nada por sí solo; producción sigue corriendo la imagen anterior hasta que alguien la reconstruya. Preguntar al usuario antes de correr:

```bash
cd /home/Fabrizio/financespy && sudo docker compose -f compose.prod.yml up -d --build web worker
```

---

---

## Estado de ejecución (2026-08-05)

Rama `feature/android-offline-phase1` en un worktree aparte de la VM, con stack Docker propio (`compose.worktree.yml`, proyecto `financespy-wt`, puerto 3001). **Producción nunca se tocó.**

| Tarea | Estado | Evidencia |
|---|---|---|
| 0 — Workspace aislado | ✅ | Stack `financespy-wt` levantado, prod (`financespy-web-1`) intacta |
| 1 — Endpoint pull | ✅ | 8 tests / 39 assertions, 0 failures (DB de test aislada) |
| 2 — Endpoint push | ✅ | idem (incluye idempotencia y rechazo de cuenta ajena) |
| 3 — Capa IndexedDB + sync | ✅ | Cache poblado con **74 transacciones reales** (coincide con el total de la UI), `sync_meta` con checkpoint + cuentas, cero errores JS ni bloqueos CSP |
| 4 — UI Stimulus | ✅ | Offline: vista server-rendered oculta, 74 filas renderizadas desde cache, selector con cuentas reales. Submit encola 1 fila con UUID propio. Volver a online restaura la vista |
| 5 — Empaquetado Capacitor | ⚙️ config lista | `capacitor.config.json` (modo remoto, apunta al dominio) + deps 8.5.0 verificadas contra npm + scripts npm + `.gitignore` para keystores. Falta correr `cap add android` y abrir Android Studio — requiere la máquina del usuario. Pasos en `docs/CAPACITOR.md` |

**Verificación en vivo (2026-08-05), sin escribir nada en la base de producción** — condición acordada explícitamente con el usuario, ya que el stack de desarrollo comparte el `DATABASE_URL` de Supabase con producción:

- Cache: 74 → coincide exacto con el "Total Transactions: 74" de la UI. Primera fila `Creatina 2026-08-05 -362424.00 PYG`, igual al dato real.
- Alta offline: encoló 1 fila (UUID cliente, moneda heredada de la cuenta), se borró de la cola y del cache antes de restaurar la conexión.
- **Confirmado post-verificación: 0 POSTs a `/sync/transactions/push` en los logs y 0 filas de prueba en la base real.**

**Hallazgo de diseño confirmado en la verificación:** al encolar un alta, el controller también inserta la fila en `transactions_cache` (UI optimista, para que aparezca al instante sin conexión). Es intencional, pero implica que limpiar solo `pending_transaction_writes` deja la copia optimista — hay que borrar de ambos stores. Relevante para cuando se implemente el descarte de un alta encolada desde la UI.

**Nota real encontrada en los logs:** el pull devuelve `304 Not Modified` en revalidaciones (ETag automático de Rack). No es un bug: `fetch()` resuelve el 304 contra su cache y le entrega un 200 con cuerpo al JS — confirmado en el log de red del navegador. Es ahorro de ancho de banda gratis, conviene no romperlo agregando `no-cache` sin motivo.

## Correcciones encontradas durante la ejecución (2026-08-05)

Cosas que el plan asumía mal y se corrigieron al ejecutar contra el código real:

1. **`includes(:transaction)` no existe como asociación.** `delegated_type :entryable` genera el método `entry.transaction` para lectura, pero **no** una asociación real para eager loading — `includes(:transaction)` levanta `AssociationNotFoundError`. Todo el codebase usa `includes(:entryable)` (confirmado en `splits_controller.rb`, `balance/sync_cache.rb`, `recurring_transaction/identifier.rb`). Corregido a `includes(:entryable)` + `entry.entryable`.

2. **`Account` valida `balance` presente** (`validates :name, :balance, :currency, presence: true`). Los tests creaban cuentas de otra familia sin `balance` → `RecordInvalid`. Corregido con `balance: 0`.

3. **`config.hosts` hardcodeaba el dominio e ignoraba `APP_DOMAIN`**, devolviendo `403 Forbidden` al levantar el stack en local. Se corrigió para que lea la variable (no-op en producción: ahí `APP_DOMAIN` ya vale `finance.cd-co.com.py`, verificado en el container). Commit `6e06359`.

4. **`bin/rails test` en el servicio `web` habría corrido contra la base de PRODUCCIÓN.** `DATABASE_URL` es una sola variable global que Rails aplica a todo `RAILS_ENV`, y `db:test:prepare` dropea la base. Está documentado en `compose.prod.yml` porque ya tumbó producción una vez (2026-07-28). El plan original mandaba `docker exec financespy-wt-web-1 bin/rails test` — **eso era peligroso**. Se agregaron servicios `test-db`/`test-runner` aislados (profile `test`) al compose del worktree, y todos los comandos de test pasan por ahí.

5. **Los módulos JS nuevos no los sirve Propshaft hasta correr `assets:precompile`.** En producción, importmap resuelve contra el manifest precompilado; archivos nuevos montados en vivo dan `Importmap skipped missing path` hasta precompilar dentro del container.

## Próximos pasos (fuera de este plan)

- **Fase 2 — edición offline**: `lock_version` en `transactions`, manejo de `ActiveRecord::StaleObjectError` en el push, UI de "tu versión / la del servidor". Requiere además cachear categorías para el picker offline.
- **Fase 3 — dashboard/flujo de caja offline**: otra colección cacheada, posiblemente pre-agregada server-side para no hacer SUM/GROUP BY en JS.
- **Push nativo (FCM)**: la razón por la que se eligió Capacitor sobre TWA — requiere proyecto Firebase + `google-services.json` + plugin, y definir el trigger real (fin de sync, umbral de presupuesto).
- **Reintentos con backoff en la cola de escritura**: hoy el replay se dispara en `connect()` y en el evento `online`. Si el server rechaza por estar caído, la fila queda en cola para el próximo intento, pero no hay backoff explícito ni tope de reintentos como sí tiene la cola de Ventas. Agregar si en uso real aparece ruido.
- Publicación en Play Store (firma de release vía Play App Signing, `assetlinks.json` con fingerprint de Play) — solo si se decide ese camino.
