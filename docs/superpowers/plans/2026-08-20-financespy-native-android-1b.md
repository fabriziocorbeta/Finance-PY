# App Android nativa FinancePY — Wave 1b Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Ejecución real de este plan: directa (SSH al host), no Jules** — el sandbox de Jules no pudo conectar al repo privado esta sesión (ver notas de wave 1a). Cada Task se implementa y verifica en `fabrizio@100.105.31.71:~/financespy`, commit + push directo a `main` (mismo patrón que cerró 1a).
>
> **Lección de 1a, aplica a cada Task nativa de este plan**: un `BUILD SUCCESSFUL` no prueba que la app funcione. Wave 1a compiló limpio 6 veces seguidas mientras `MainActivity.kt` nunca se empaquetaba en el dex (plugin Kotlin faltante en `androidApp`) — 5 bugs reales solo aparecieron al instalar+abrir en un teléfono real. Cada Task nativa de este plan que toque una pantalla nueva debe instalarse y probarse en el dispositivo físico conectado por USB antes de darse por cerrada, no alcanza con el build.

**Goal:** Agregar a la app Android nativa FinancePY (wave 1a ya en `main`, probada en dispositivo real) el detalle de cuenta, la gestión de reglas de auto-categorización (lectura + creación/edición acotada a 1 condición + 1 acción) y la navegación entre pantallas que hoy no existe (1a es solo 2 tabs planos).

**Architecture:** Backend Rails nuevo (create/update/destroy en `Api::V1::RulesController`, hoy solo lectura) + extensión del módulo `native/financespy-kmp/` de 1a: nuevas entities Room aplanadas para reglas, nuevos DTOs/llamadas API, `SyncEngine` extendido, y 4 pantallas nuevas conectadas vía Navigation Compose Multiplatform (1a no tenía stack de navegación real, solo `TabRow` sin back-stack).

**Tech Stack:** Mismo de 1a (Kotlin Multiplatform, Compose Multiplatform, Ktor, Room KMP, Koin) + `org.jetbrains.androidx.navigation:navigation-compose` (Navigation Compose Multiplatform) + Rails/Pagy (backend, sin gemas nuevas).

## Global Constraints

- Todo el código nativo va en `native/financespy-kmp/` (repo `fabriziocorbeta/cd-co-erp`, ya existe desde 1a) — no tocar `android/` (Capacitor) ni `native/android/wallet-listener/`.
- `applicationId` de este build sigue siendo `py.com.cdco.financespy.dev` — nunca el de producción.
- Alcance de Reglas confirmado con el usuario (spec, sección Alcance): **1 condición + 1 acción por regla**. Condiciones soportadas: `transaction_name` (operador `like`/`=`), `transaction_merchant` (operador `=`, valor = merchant id), `transaction_category` (operador `=`, valor = category id). Acciones soportadas: `set_transaction_category` (valor = category id), `set_transaction_tags` (valor = **un solo** tag id — confirmado en `Rule::ActionExecutor::SetTransactionTags#execute`, cada acción agrega 1 tag, no una lista). Nada de condiciones compuestas, nada de los otros 5 tipos de condición ni los otros 7 tipos de acción del registry real — fuera de alcance explícito.
- "Reportes" no es parte de 1b (decisión del usuario en el brainstorm).
- Backend: scope de autorización para mutaciones de reglas es `:read_write` (mismo patrón que `tags_controller.rb`/`transactions_controller.rb` ya usan), lectura sigue en `:read`.

---

## Task 1: Backend Rails — create/update/destroy en RulesController

**Files:**
- Modify: `config/routes.rb:476` (en el host remoto, ruta real dentro de `fabrizio@100.105.31.71:~/financespy`)
- Modify: `app/controllers/api/v1/rules_controller.rb`
- Test: `test/controllers/api/v1/rules_controller_test.rb`

**Interfaces:**
- Produces: `POST /api/v1/rules`, `PATCH /api/v1/rules/:id`, `DELETE /api/v1/rules/:id` — Task 3 (DTOs/API client nativo) depende del shape de respuesta exacto de estos 3 endpoints (mismo que `show.json.jbuilder` ya devuelve para create/update: `{"data": {id, name, resource_type, active, effective_date, conditions: [...], actions: [...], created_at, updated_at}}`, y `204 No Content` para destroy).

- [ ] **Step 1: Cambiar la ruta**

En `config/routes.rb`, línea 476, reemplazar:
```ruby
resources :rules, only: [ :index, :show ]
```
por:
```ruby
resources :rules, only: %i[index show create update destroy]
```

- [ ] **Step 2: Escribir los tests de create/update/destroy (van a fallar — la acción todavía no existe)**

Agregar al final de `test/controllers/api/v1/rules_controller_test.rb` (antes del `end` final de la clase), reusando el `setup` ya existente en el archivo (`@user`, `@family`, `@api_key` con scope `read`):

```ruby
  test "should create a rule with write scope" do
    write_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )
    Redis.new.del("api_rate_limit:#{write_key.id}")

    assert_difference -> { @family.rules.count }, 1 do
      post api_v1_rules_url,
        params: {
          rule: {
            name: "Uber cleanup",
            resource_type: "transaction",
            active: true,
            conditions_attributes: [ { condition_type: "transaction_name", operator: "like", value: "uber" } ],
            actions_attributes: [ { action_type: "set_transaction_category", value: categories(:food_and_drink).id } ]
          }
        },
        headers: api_headers(write_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "Uber cleanup", json_response["data"]["name"]
    assert_equal 1, json_response["data"]["conditions"].length
    assert_equal 1, json_response["data"]["actions"].length
  end

  test "should reject rule creation with read-only scope" do
    post api_v1_rules_url,
      params: {
        rule: {
          name: "Should fail",
          resource_type: "transaction",
          active: true,
          conditions_attributes: [ { condition_type: "transaction_name", operator: "like", value: "x" } ],
          actions_attributes: [ { action_type: "set_transaction_category", value: categories(:food_and_drink).id } ]
        }
      },
      headers: api_headers(@api_key)

    assert_response :forbidden
  end

  test "should update a rule" do
    write_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key 2",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_write2_#{SecureRandom.hex(8)}"
    )
    Redis.new.del("api_rate_limit:#{write_key.id}")

    patch api_v1_rule_url(@rule),
      params: { rule: { active: false } },
      headers: api_headers(write_key)

    assert_response :success
    assert_equal false, JSON.parse(response.body)["data"]["active"]
  end

  test "should destroy a rule" do
    write_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key 3",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_write3_#{SecureRandom.hex(8)}"
    )
    Redis.new.del("api_rate_limit:#{write_key.id}")

    assert_difference -> { @family.rules.count }, -1 do
      delete api_v1_rule_url(@rule), headers: api_headers(write_key)
    end

    assert_response :no_content
  end
```

Nota: si `categories(:food_and_drink)` no existe como fixture real, correr `grep -rn "food_and_drink\|:food" test/fixtures/categories.yml` en el host antes de este step y usar el nombre de fixture real que exista — no asumir sin verificar contra el archivo real.

- [ ] **Step 3: Correr los tests, deben fallar (acciones no existen todavía)**

Run (dentro del container Docker de test, mismo patrón que 1a — ver notas de infra de sesiones previas: `DB_HOST=financespy_test_pg` etc.): `bin/rails test test/controllers/api/v1/rules_controller_test.rb`
Expected: los 4 tests nuevos fallan (`AbstractController::ActionNotFound` o 404, ya que `create`/`update`/`destroy` no existen en el controller ni en las rutas hasta este punto — Step 1 ya cambió las rutas, así que el fallo real acá debería ser `NoMethodError`/`ActionController::UrlGenerationError` o similar del lado del controller, no 404 de rutas).

- [ ] **Step 4: Implementar create/update/destroy en el controller**

Reemplazar el contenido completo de `app/controllers/api/v1/rules_controller.rb`:

```ruby
# frozen_string_literal: true

class Api::V1::RulesController < Api::V1::BaseController
  include Pagy::Backend

  BOOLEAN_FILTERS = {
    "true" => true,
    "1" => true,
    "false" => false,
    "0" => false
  }.freeze
  RESOURCE_TYPES = %w[transaction].freeze

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :set_rule, only: %i[show update destroy]

  def index
    return render_invalid_resource_type_filter if invalid_resource_type_filter?

    @per_page = safe_per_page_param
    rules_query = current_resource_owner.family.rules
      .includes(:actions, conditions: :sub_conditions)
      .order(:created_at, :id)

    rules_query = rules_query.where(resource_type: params[:resource_type]) if params[:resource_type].present?
    if params[:active].present?
      active = parse_boolean_filter(params[:active])
      return if performed?

      rules_query = rules_query.where(active: active)
    end

    @pagy, @rules = pagy(
      rules_query,
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  end

  def show
    render :show
  end

  def create
    @rule = current_resource_owner.family.rules.new(rule_params)

    if @rule.save
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Rule could not be created",
        errors: @rule.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "RulesController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    if @rule.update(rule_params)
      render :show
    else
      render json: {
        error: "validation_failed",
        message: "Rule could not be updated",
        errors: @rule.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "RulesController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    @rule.destroy!
    head :no_content
  rescue => e
    Rails.logger.error "RulesController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_rule
      @rule = current_resource_owner.family.rules
        .includes(:actions, conditions: :sub_conditions)
        .find(params[:id])
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:read_write)
    end

    def rule_params
      params.require(:rule).permit(
        :name, :resource_type, :active,
        conditions_attributes: [ :id, :condition_type, :operator, :value, :_destroy ],
        actions_attributes: [ :id, :action_type, :value, :_destroy ]
      )
    end

    def parse_boolean_filter(value)
      normalized = value.to_s.downcase
      return BOOLEAN_FILTERS[normalized] if BOOLEAN_FILTERS.key?(normalized)

      render_validation_error("active must be one of: true, false, 1, 0")
      nil
    end

    def invalid_resource_type_filter?
      params[:resource_type].present? && !params[:resource_type].in?(RESOURCE_TYPES)
    end

    def render_invalid_resource_type_filter
      render_validation_error("resource_type must be one of: #{RESOURCE_TYPES.join(", ")}")
    end
end
```

Nota: `create`/`update` reusan la vista `show.json.jbuilder` existente (`render :show`) — ya renderiza `@rule` con el partial `_rule`, que ya incluye `conditions`/`actions`. No hace falta escribir vistas jbuilder nuevas.

- [ ] **Step 5: Correr los tests de nuevo, deben pasar**

Run: `bin/rails test test/controllers/api/v1/rules_controller_test.rb`
Expected: todos los tests pasan (los preexistentes de index/show + los 4 nuevos de create/update/destroy), 0 failures, 0 errors.

- [ ] **Step 6: Correr la suite completa de rules para confirmar que no rompiste nada relacionado**

Run: `bin/rails test test/controllers/rules_controller_test.rb test/models/rule_test.rb` (si existe este último — si no existe, correr solo el primero)
Expected: BUILD/tests pasan igual que antes de este Task.

- [ ] **Step 7: Commit y deploy**

```bash
git add config/routes.rb app/controllers/api/v1/rules_controller.rb test/controllers/api/v1/rules_controller_test.rb
git commit -m "feat(api): create/update/destroy en RulesController (wave 1b task 1)"
git push origin main
```
Deploy (mismo patrón de sesiones previas): `docker compose -f compose.local.yml --env-file .env.local up -d --build web worker`. Confirmar que el sitio sigue respondiendo (`curl -sI https://finance.cd-co.com.py` → 302) después del rebuild.

---

## Task 2: Room — RuleEntity/RuleRunEntity aplanadas + DAOs

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleEntity.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleRunEntity.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleDao.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleRunDao.kt`
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/FinancePyDatabase.kt` (agregar las 2 entities nuevas + bump de `version`)

**Interfaces:**
- Produces: `RuleEntity(id, name, resourceType, active, conditionType, conditionOperator, conditionValue, actionType, actionValue, updatedAt)`, `RuleRunEntity(id, ruleId, status, executionType, executedAt)`, `RuleDao { upsertAll, deleteAllExcept, observeAll, findById }`, `RuleRunDao { upsertAll, observeByRuleId }`. Task 3 (sync) depende de `upsertAll`/`deleteAllExcept`. Task 6 (pantallas de lectura) depende de `observeAll`/`observeByRuleId`. Task 7 (formulario) depende de `findById`.

- [ ] **Step 1: `RuleEntity`**

```kotlin
package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "rules")
data class RuleEntity(
    @PrimaryKey val id: String,
    val name: String?,
    val resourceType: String,
    val active: Boolean,
    val conditionType: String,
    val conditionOperator: String,
    val conditionValue: String,
    val actionType: String,
    val actionValue: String,
    val updatedAt: String
)
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleEntity.kt`

- [ ] **Step 2: `RuleRunEntity`**

```kotlin
package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "rule_runs")
data class RuleRunEntity(
    @PrimaryKey val id: String,
    val ruleId: String,
    val status: String,
    val executionType: String,
    val executedAt: String
)
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleRunEntity.kt`

- [ ] **Step 3: `RuleDao`**

```kotlin
package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface RuleDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(rules: List<RuleEntity>)

    @Query("DELETE FROM rules WHERE id NOT IN (:ids)")
    suspend fun deleteAllExcept(ids: List<String>)

    @Query("SELECT * FROM rules ORDER BY name ASC")
    fun observeAll(): Flow<List<RuleEntity>>

    @Query("SELECT * FROM rules WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): RuleEntity?

    @Query("DELETE FROM rules WHERE id = :id")
    suspend fun deleteById(id: String)
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleDao.kt`

- [ ] **Step 4: `RuleRunDao`**

```kotlin
package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface RuleRunDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(ruleRuns: List<RuleRunEntity>)

    @Query("SELECT * FROM rule_runs WHERE ruleId = :ruleId ORDER BY executedAt DESC")
    fun observeByRuleId(ruleId: String): Flow<List<RuleRunEntity>>
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/RuleRunDao.kt`

- [ ] **Step 5: Registrar en `FinancePyDatabase` + bump de versión**

Modificar `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/FinancePyDatabase.kt` — reemplazar contenido completo:

```kotlin
package py.com.cdco.financespy.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        AccountEntity::class, EntryEntity::class, TransactionEntity::class,
        RuleEntity::class, RuleRunEntity::class
    ],
    version = 2,
    exportSchema = true
)
abstract class FinancePyDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun entryDao(): EntryDao
    abstract fun transactionDao(): TransactionDao
    abstract fun ruleDao(): RuleDao
    abstract fun ruleRunDao(): RuleRunDao
}

expect fun buildDatabase(): FinancePyDatabase
```
Nota: subir `version` de 1 a 2 sin `Migration` explícita — Room por default destruye y recrea la DB si no hay migración registrada y la versión cambió, lo cual está bien acá porque **1a nunca shippeó a producción real** (sigue siendo build de desarrollo `py.com.cdco.financespy.dev`, sideload) — perder la caché local y resincronizar desde cero en el próximo `syncAll()` es aceptable, no hay usuarios reales dependiendo de esa DB local todavía. Si en el futuro esto deja de ser cierto, agregar una `Migration` real acá en vez de destructive fallback.

- [ ] **Step 6: Verificar build**

Run: `cd native/financespy-kmp && ANDROID_HOME=/home/fabrizio/Android/Sdk ./gradlew :shared:compileDebugKotlinAndroid --no-daemon`
Expected: `BUILD SUCCESSFUL` (KSP genera el nuevo `Database_Impl` con las 5 tablas sin errores).

- [ ] **Step 7: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): Room RuleEntity/RuleRunEntity aplanadas (wave 1b task 2)"
git push origin main
```

---

## Task 3: DTOs + API client (rules/rule_runs/categories/merchants/tags) + sync de reglas

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/RuleDto.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/CategoryDto.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/MerchantDto.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/TagDto.kt`
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/FinancePyApi.kt`
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/sync/SyncEngine.kt`

**Interfaces:**
- Consumes: `RuleDao`/`RuleRunDao` (Task 2), `ApiClient`/`FinancePyApi` (1a).
- Produces: `FinancePyApi.fetchAllRules()`, `.fetchRuleRuns(ruleId)`, `.fetchCategories()`, `.fetchMerchants()`, `.fetchTags()`, `.createRule(request)`, `.updateRule(id, request)`, `.deleteRule(id)`. Task 5/6/7 (pantallas) dependen de estas exactas firmas.

- [ ] **Step 1: DTOs — shape real confirmado contra el server (ver Task 1 y la investigación de esta wave)**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/RuleDto.kt`:
```kotlin
package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class RulesEnvelope(val data: List<RuleDto>, val meta: RulesMetaDto)

@Serializable
data class RuleEnvelope(val data: RuleDto)

@Serializable
data class RulesMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class RuleDto(
    val id: String,
    val name: String? = null,
    val resource_type: String,
    val active: Boolean,
    val effective_date: String? = null,
    val conditions: List<RuleConditionDto>,
    val actions: List<RuleActionDto>,
    val created_at: String,
    val updated_at: String
)

@Serializable
data class RuleConditionDto(
    val id: String,
    val condition_type: String,
    val operator: String,
    val value: String? = null
)

@Serializable
data class RuleActionDto(
    val id: String,
    val action_type: String,
    val value: String? = null
)

@Serializable
data class RuleRunsEnvelope(val data: List<RuleRunDto>, val meta: RulesMetaDto)

@Serializable
data class RuleRunDto(
    val id: String,
    val rule_id: String,
    val status: String,
    val execution_type: String,
    val executed_at: String? = null
)

@Serializable
data class CreateRuleRequest(
    val rule: CreateRuleBody
)

@Serializable
data class CreateRuleBody(
    val name: String?,
    val resource_type: String = "transaction",
    val active: Boolean = true,
    val conditions_attributes: List<ConditionAttributes>,
    val actions_attributes: List<ActionAttributes>
)

@Serializable
data class ConditionAttributes(
    val condition_type: String,
    val operator: String,
    val value: String
)

@Serializable
data class ActionAttributes(
    val action_type: String,
    val value: String
)

@Serializable
data class UpdateRuleRequest(val rule: UpdateRuleBody)

@Serializable
data class UpdateRuleBody(val active: Boolean? = null, val name: String? = null)
```
Nota sobre `rule_id`/`rule_runs` shape: el spec de esta wave no llegó a confirmar el jbuilder exacto de `rule_runs` contra el server real (no se leyó `app/views/api/v1/rule_runs/*.json.jbuilder` durante el brainstorm) — antes de implementar Step 5 de este Task, correr en el host: `cat ~/financespy/app/views/api/v1/rule_runs/*.json.jbuilder` y ajustar `RuleRunDto`/`RuleRunsEnvelope` si el shape real difiere de lo asumido acá (se asumió el mismo patrón `data`+`meta` que `rules` por ser controllers hermanos con Pagy, pero no fue verificado línea por línea). Documentar en el commit de este Task qué shape resultó ser el real.

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/CategoryDto.kt`:
```kotlin
package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class CategoriesResponse(val categories: List<CategoryDto>, val pagination: PaginationDto)

@Serializable
data class CategoryDto(
    val id: String,
    val name: String,
    val color: String,
    val icon: String
)
```

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/MerchantDto.kt`:
```kotlin
package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class MerchantDto(
    val id: String,
    val name: String,
    val type: String
)
```
Nota: `GET /api/v1/merchants` devuelve un array JSON plano (`[{...}, ...]`), sin wrapper `{merchants: [...]}` ni paginación — confirmado leyendo `merchants_controller.rb#index` (`render json: @merchants.map { |m| merchant_json(m) }`). Ktor puede deserializar directo a `List<MerchantDto>`, no hace falta un envelope.

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/TagDto.kt`:
```kotlin
package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class TagDto(
    val id: String,
    val name: String,
    val color: String
)
```
Mismo caso que merchants: `GET /api/v1/tags` devuelve array plano (confirmado en `tags_controller.rb#index`).

- [ ] **Step 2: Extender `FinancePyApi`**

Agregar a `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/FinancePyApi.kt` (dentro de la clase `FinancePyApi`, junto a los métodos existentes):

```kotlin
suspend fun fetchAllRules(): List<py.com.cdco.financespy.api.dto.RuleDto> {
    val all = mutableListOf<py.com.cdco.financespy.api.dto.RuleDto>()
    var page = 1
    while (true) {
        val response: py.com.cdco.financespy.api.dto.RulesEnvelope = http.get("/api/v1/rules") {
            parameter("page", page)
            parameter("per_page", 100)
        }.body()
        all += response.data
        if (response.meta.next_page == null) break
        page = response.meta.next_page!!
    }
    return all
}

suspend fun fetchRuleRuns(ruleId: String): List<py.com.cdco.financespy.api.dto.RuleRunDto> {
    val response: py.com.cdco.financespy.api.dto.RuleRunsEnvelope = http.get("/api/v1/rule_runs") {
        parameter("rule_id", ruleId)
        parameter("per_page", 100)
    }.body()
    return response.data
}

suspend fun fetchCategories(): List<py.com.cdco.financespy.api.dto.CategoryDto> {
    val response: py.com.cdco.financespy.api.dto.CategoriesResponse = http.get("/api/v1/categories") {
        parameter("per_page", 100)
    }.body()
    return response.categories
}

suspend fun fetchMerchants(): List<py.com.cdco.financespy.api.dto.MerchantDto> =
    http.get("/api/v1/merchants").body()

suspend fun fetchTags(): List<py.com.cdco.financespy.api.dto.TagDto> =
    http.get("/api/v1/tags").body()

suspend fun createRule(body: py.com.cdco.financespy.api.dto.CreateRuleBody): py.com.cdco.financespy.api.dto.RuleDto {
    val response: py.com.cdco.financespy.api.dto.RuleEnvelope = http.post("/api/v1/rules") {
        contentType(io.ktor.http.ContentType.Application.Json)
        setBody(py.com.cdco.financespy.api.dto.CreateRuleRequest(rule = body))
    }.body()
    return response.data
}

suspend fun updateRule(id: String, body: py.com.cdco.financespy.api.dto.UpdateRuleBody): py.com.cdco.financespy.api.dto.RuleDto {
    val response: py.com.cdco.financespy.api.dto.RuleEnvelope = http.patch("/api/v1/rules/$id") {
        contentType(io.ktor.http.ContentType.Application.Json)
        setBody(py.com.cdco.financespy.api.dto.UpdateRuleRequest(rule = body))
    }.body()
    return response.data
}

suspend fun deleteRule(id: String) {
    http.delete("/api/v1/rules/$id")
}
```
Agregar los imports que falten al tope del archivo: `io.ktor.client.request.post`, `io.ktor.client.request.patch`, `io.ktor.client.request.delete`, `io.ktor.client.request.setBody`, `io.ktor.http.contentType`.

- [ ] **Step 3: Extender `SyncEngine` para sincronizar reglas**

Modificar `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/sync/SyncEngine.kt` — el constructor gana 2 parámetros nuevos (`ruleDao`, `ruleRunDao`) y `syncAll()` gana un paso nuevo. Reemplazar el contenido completo del archivo:

```kotlin
package py.com.cdco.financespy.sync

import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity
import py.com.cdco.financespy.db.RuleRunDao
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.db.TransactionEntity

const val SYNC_WINDOW_DAYS = 90

class SyncEngine(
    private val api: FinancePyApi,
    private val accountDao: AccountDao,
    private val entryDao: EntryDao,
    private val transactionDao: TransactionDao,
    private val ruleDao: RuleDao,
    private val ruleRunDao: RuleRunDao,
    private val currentDateProvider: () -> String
) {
    suspend fun syncAll(): Result<Unit> = runCatching {
        syncAccounts()
        syncTransactions()
        syncRules()
    }

    private suspend fun syncAccounts() {
        val remote = api.fetchAllAccounts()
        accountDao.upsertAll(remote.map { it.toEntity() })
        accountDao.deleteAllExcept(remote.map { it.id })
    }

    private suspend fun syncTransactions() {
        val startDate = subtractDays(currentDateProvider(), SYNC_WINDOW_DAYS)
        val remote = api.fetchRecentTransactions(startDate)
        entryDao.upsertAll(remote.map { it.toEntryEntity() })
        transactionDao.upsertAll(remote.map { it.toTransactionEntity() })
        entryDao.deleteStaleWithinWindow(remote.map { it.id }, startDate)
    }

    private suspend fun syncRules() {
        val remote = api.fetchAllRules()
        val entities = remote.mapNotNull { it.toEntityOrNull() }
        ruleDao.upsertAll(entities)
        ruleDao.deleteAllExcept(entities.map { it.id })
        remote.forEach { rule ->
            val runs = runCatching { api.fetchRuleRuns(rule.id) }.getOrNull().orEmpty()
            ruleRunDao.upsertAll(runs.map {
                py.com.cdco.financespy.db.RuleRunEntity(
                    id = it.id, ruleId = it.rule_id, status = it.status,
                    executionType = it.execution_type, executedAt = it.executed_at ?: ""
                )
            })
        }
    }
}

private fun AccountDto.toEntity() = AccountEntity(
    id = id, name = name, balanceCents = balance_cents, cashBalanceCents = cash_balance_cents,
    currency = currency, classification = classification, accountType = account_type,
    subtype = subtype, status = status, updatedAt = updated_at
)

private fun TransactionListItemDto.toEntryEntity() = EntryEntity(
    id = id, accountId = account.id, date = date, name = name, amountCents = signed_amount_cents,
    currency = currency, entryableType = "Transaction", entryableId = id,
    parentEntryId = null, transferId = null, updatedAt = updated_at
)

private fun TransactionListItemDto.toTransactionEntity() = TransactionEntity(
    id = id, categoryId = category?.id, categoryName = category?.name,
    merchantId = merchant?.id, merchantName = merchant?.name, kind = "standard"
)

// Wave 1b solo soporta reglas de 1 condicion + 1 accion (ver spec). Una regla real
// del server con 0 o >1 condiciones/acciones (creada por la web, fuera del alcance
// de este cliente) no se puede representar en el schema aplanado de RuleEntity —
// se omite del sync en vez de crashear o truncar datos silenciosamente mal.
private fun RuleDto.toEntityOrNull(): RuleEntity? {
    val condition = conditions.firstOrNull() ?: return null
    val action = actions.firstOrNull() ?: return null
    if (conditions.size > 1 || actions.size > 1) return null
    return RuleEntity(
        id = id, name = name, resourceType = resource_type, active = active,
        conditionType = condition.condition_type, conditionOperator = condition.operator,
        conditionValue = condition.value ?: "",
        actionType = action.action_type, actionValue = action.value ?: "",
        updatedAt = updated_at
    )
}

private fun subtractDays(isoDate: String, days: Int): String {
    val parts = isoDate.substring(0, 10).split("-").map { it.toInt() }
    var year = parts[0]
    var month = parts[1]
    var day = parts[2]
    repeat(days) {
        day--
        if (day < 1) {
            month--
            if (month < 1) { month = 12; year-- }
            day = daysInMonth(year, month)
        }
    }
    return "%04d-%02d-%02d".format(year, month, day)
}

private fun daysInMonth(year: Int, month: Int): Int = when (month) {
    1, 3, 5, 7, 8, 10, 12 -> 31
    4, 6, 9, 11 -> 30
    2 -> if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) 29 else 28
    else -> 30
}
```
Nota: `subtractDays`/`daysInMonth` quedaron duplicadas acá en vez de importarlas de `sync/DateMath.kt` (que ya existe desde 1a con la misma función pública `subtractDays`) — **usar la versión de `DateMath.kt` existente, borrar esta duplicada**. Se deja escrita acá completa solo para que este Task sea autocontenido si se lee fuera de orden; al implementar, importar `py.com.cdco.financespy.sync.subtractDays` de `DateMath.kt` en vez de redefinirla.

- [ ] **Step 4: Actualizar el sitio único donde se construye `SyncEngine` (MainActivity) para pasar los 2 DAOs nuevos**

En `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`, el bloque que construye `SyncEngine(...)` gana 2 argumentos:
```kotlin
val syncEngine = SyncEngine(
    api = api,
    accountDao = database.accountDao(),
    entryDao = database.entryDao(),
    transactionDao = database.transactionDao(),
    ruleDao = database.ruleDao(),
    ruleRunDao = database.ruleRunDao(),
    currentDateProvider = { currentIsoDate() }
)
```

- [ ] **Step 5: Verificar shape real de `rule_runs` contra el server (ver nota de Step 1) y ajustar DTOs si hace falta**

Run (en el host): `cat ~/financespy/app/views/api/v1/rule_runs/*.json.jbuilder`
Si el shape difiere de `RuleRunsEnvelope`/`RuleRunDto` tal como quedaron en Step 1, corregir esos 2 tipos antes de seguir. Documentar en el commit de este Task cuál era el shape real.

- [ ] **Step 6: Verificar build**

Run: `cd native/financespy-kmp && ANDROID_HOME=/home/fabrizio/Android/Sdk ./gradlew :androidApp:assembleDebug --no-daemon`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 7: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): DTOs + API client + sync de reglas (wave 1b task 3)"
git push origin main
```

---

## Task 4: Navigation Compose Multiplatform — reemplaza el TabRow plano de 1a

**Files:**
- Modify: `native/financespy-kmp/shared/build.gradle.kts` (agregar dependencia `navigation-compose`)
- Modify: `native/financespy-kmp/gradle/libs.versions.toml`
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/navigation/Routes.kt`

**Interfaces:**
- Produces: `object Routes { const val DASHBOARD; const val TRANSACTIONS; const val RULES; const val ACCOUNT_DETAIL = "account/{accountId}"; const val RULE_DETAIL = "rule/{ruleId}"; const val RULE_FORM = "rule_form?ruleId={ruleId}" }` y el `NavController` disponible dentro de `App()`. Tasks 5/6/7 (pantallas nuevas) dependen de poder navegar a estas rutas y de poder leer `accountId`/`ruleId` desde `NavBackStackEntry.arguments`.

- [ ] **Step 1: Agregar la dependencia**

En `native/financespy-kmp/gradle/libs.versions.toml`, agregar a `[versions]`:
```toml
navigationCompose = "2.8.0-alpha11"
```
Y a `[libraries]`:
```toml
navigation-compose = { module = "org.jetbrains.androidx.navigation:navigation-compose", version.ref = "navigationCompose" }
```

En `native/financespy-kmp/shared/build.gradle.kts`, agregar dentro del bloque `commonMain.dependencies` (junto a `implementation(compose.material3)` etc.):
```kotlin
implementation(libs.navigation.compose)
```

- [ ] **Step 2: `Routes.kt`**

```kotlin
package py.com.cdco.financespy.navigation

object Routes {
    const val DASHBOARD = "dashboard"
    const val TRANSACTIONS = "transactions"
    const val RULES = "rules"
    const val ACCOUNT_DETAIL = "account/{accountId}"
    const val RULE_DETAIL = "rule/{ruleId}"
    const val RULE_FORM = "rule_form?ruleId={ruleId}"

    fun accountDetail(accountId: String) = "account/$accountId"
    fun ruleDetail(ruleId: String) = "rule/$ruleId"
    fun ruleFormEdit(ruleId: String) = "rule_form?ruleId=$ruleId"
    fun ruleFormCreate() = "rule_form"
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/navigation/Routes.kt`

- [ ] **Step 3: Reescribir `App.kt` con `NavHost` — las pantallas de Tasks 5/6/7 todavía no existen, este Step deja placeholders `Text("TODO")` que Tasks siguientes reemplazan uno por uno**

Reemplazar el contenido completo de `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt`:

```kotlin
package py.com.cdco.financespy

import androidx.compose.material3.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.navigation.Routes
import py.com.cdco.financespy.screens.AccountDetailScreen
import py.com.cdco.financespy.screens.AccountDetailViewModel
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.LoginScreen
import py.com.cdco.financespy.screens.RuleDetailScreen
import py.com.cdco.financespy.screens.RuleDetailViewModel
import py.com.cdco.financespy.screens.RuleFormScreen
import py.com.cdco.financespy.screens.RuleFormViewModel
import py.com.cdco.financespy.screens.RulesListScreen
import py.com.cdco.financespy.screens.RulesListViewModel
import py.com.cdco.financespy.screens.TransactionsScreen
import py.com.cdco.financespy.screens.TransactionsViewModel

@Composable
fun App(
    isLoggedIn: Boolean?,
    onLoginClick: () -> Unit,
    dashboardViewModelFactory: () -> DashboardViewModel,
    transactionsViewModelFactory: () -> TransactionsViewModel,
    rulesListViewModelFactory: () -> RulesListViewModel,
    ruleDetailViewModelFactory: (String) -> RuleDetailViewModel,
    ruleFormViewModelFactory: (String?) -> RuleFormViewModel,
    accountDetailViewModelFactory: (String) -> AccountDetailViewModel
) {
    MaterialTheme {
        when (isLoggedIn) {
            null -> {}
            false -> LoginScreen(onLoginClick = onLoginClick)
            true -> {
                val navController = rememberNavController()
                val backStackEntry by navController.currentBackStackEntryAsState()
                val currentRoute = backStackEntry?.destination?.route

                Column {
                    if (currentRoute == Routes.DASHBOARD || currentRoute == Routes.TRANSACTIONS || currentRoute == Routes.RULES) {
                        TabRow(
                            selectedTabIndex = when (currentRoute) {
                                Routes.TRANSACTIONS -> 1
                                Routes.RULES -> 2
                                else -> 0
                            }
                        ) {
                            Tab(
                                selected = currentRoute == Routes.DASHBOARD,
                                onClick = { navController.navigate(Routes.DASHBOARD) { launchSingleTop = true } },
                                text = { Text("Dashboard") }
                            )
                            Tab(
                                selected = currentRoute == Routes.TRANSACTIONS,
                                onClick = { navController.navigate(Routes.TRANSACTIONS) { launchSingleTop = true } },
                                text = { Text("Transacciones") }
                            )
                            Tab(
                                selected = currentRoute == Routes.RULES,
                                onClick = { navController.navigate(Routes.RULES) { launchSingleTop = true } },
                                text = { Text("Reglas") }
                            )
                        }
                    }

                    NavHost(navController = navController, startDestination = Routes.DASHBOARD) {
                        composable(Routes.DASHBOARD) {
                            DashboardScreen(
                                viewModel = remember { dashboardViewModelFactory() },
                                onAccountClick = { accountId -> navController.navigate(Routes.accountDetail(accountId)) }
                            )
                        }
                        composable(Routes.TRANSACTIONS) {
                            TransactionsScreen(viewModel = remember { transactionsViewModelFactory() })
                        }
                        composable(Routes.RULES) {
                            RulesListScreen(
                                viewModel = remember { rulesListViewModelFactory() },
                                onRuleClick = { ruleId -> navController.navigate(Routes.ruleDetail(ruleId)) },
                                onCreateClick = { navController.navigate(Routes.ruleFormCreate()) }
                            )
                        }
                        composable(Routes.ACCOUNT_DETAIL) { entry ->
                            val accountId = entry.arguments?.getString("accountId") ?: return@composable
                            AccountDetailScreen(viewModel = remember(accountId) { accountDetailViewModelFactory(accountId) })
                        }
                        composable(Routes.RULE_DETAIL) { entry ->
                            val ruleId = entry.arguments?.getString("ruleId") ?: return@composable
                            RuleDetailScreen(
                                viewModel = remember(ruleId) { ruleDetailViewModelFactory(ruleId) },
                                onEditClick = { navController.navigate(Routes.ruleFormEdit(ruleId)) },
                                onDeleted = { navController.popBackStack(Routes.RULES, inclusive = false) }
                            )
                        }
                        composable(Routes.RULE_FORM) { entry ->
                            val ruleId = entry.arguments?.getString("ruleId")
                            RuleFormScreen(
                                viewModel = remember(ruleId) { ruleFormViewModelFactory(ruleId) },
                                onSaved = { navController.popBackStack() }
                            )
                        }
                    }
                }
            }
        }
    }
}
```
Nota: este Step referencia `AccountDetailScreen`/`AccountDetailViewModel`, `RulesListScreen`/`RulesListViewModel`, `RuleDetailScreen`/`RuleDetailViewModel`, `RuleFormScreen`/`RuleFormViewModel` que **todavía no existen** — este archivo no compila hasta que Tasks 5/6/7 los creen. Es intencional (mismo patrón que 1a Task 5 dejaba `onLoginClick` con un comentario "cableado real queda en MainActivity") — la firma completa de `App()` queda fijada acá desde ya para que Tasks 5/6/7 sepan exactamente qué composable/ViewModel deben producir, pero el build real de este Task 4 en solitario **va a fallar** por referencias no resueltas. Step 4 de abajo lo aclara.

- [ ] **Step 4: Confirmar que las referencias nuevas están efectivamente pendientes (no intentar buildear todavía)**

No correr `./gradlew :androidApp:assembleDebug` al cierre de este Task — va a fallar por diseño hasta que Tasks 5, 6 y 7 agreguen las pantallas/ViewModels que `App.kt` ya referencia. El build real se verifica al cierre de Task 7 (última pieza).

- [ ] **Step 5: Commit (sin verificar build — documentado explícitamente el motivo)**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): Navigation Compose Multiplatform, reemplaza TabRow plano (wave 1b task 4)

No compila en solitario: App.kt referencia AccountDetailScreen/RulesListScreen/
RuleDetailScreen/RuleFormScreen que agregan las tasks 5-7. Build real se
verifica al cierre de task 7."
git push origin main
```

---

## Task 5: `AccountDetailScreen` — sin backend nuevo, prueba el patrón de navegación

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/AccountDetailViewModel.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/AccountDetailScreen.kt`
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryDao.kt` (agregar `observeByAccountId`)
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/DashboardScreen.kt` (agregar `onAccountClick` y hacer cada fila de cuenta clickeable)
- Modify: `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt` (agregar `accountDetailViewModelFactory` al `App(...)` que ya se llama en `setContent`)

**Interfaces:**
- Consumes: `AccountDao.observeAll()` (1a), `EntryDao.observeByAccountId(accountId, limit)` (nuevo en este Task).
- Produces: `@Composable fun AccountDetailScreen(viewModel: AccountDetailViewModel)`.

- [ ] **Step 1: `observeByAccountId` en `EntryDao`**

Agregar a `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryDao.kt`:
```kotlin
@Query("SELECT * FROM entries WHERE accountId = :accountId ORDER BY date DESC")
fun observeByAccountId(accountId: String): Flow<List<EntryEntity>>
```

- [ ] **Step 2: `AccountDetailViewModel`**

```kotlin
package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity

data class AccountDetailState(
    val account: AccountEntity? = null,
    val entries: List<EntryEntity> = emptyList()
)

class AccountDetailViewModel(
    scope: CoroutineScope,
    accountId: String,
    accountDao: AccountDao,
    entryDao: EntryDao
) {
    private val _state = MutableStateFlow(AccountDetailState())
    val state: StateFlow<AccountDetailState> = _state

    init {
        combine(accountDao.observeAll(), entryDao.observeByAccountId(accountId)) { accounts, entries ->
            AccountDetailState(account = accounts.firstOrNull { it.id == accountId }, entries = entries)
        }.onEach { _state.value = it }.launchIn(scope)
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/AccountDetailViewModel.kt`

- [ ] **Step 3: `AccountDetailScreen`**

```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun AccountDetailScreen(viewModel: AccountDetailViewModel) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        state.account?.let { account ->
            Text(account.name)
            Text("Saldo: ${account.balanceCents / 100.0} ${account.currency}")
            Text("Saldo efectivo: ${account.cashBalanceCents / 100.0} ${account.currency}")
            Text("Tipo: ${account.accountType}${account.subtype?.let { " ($it)" } ?: ""}")
        }
        LazyColumn {
            items(state.entries) { entry ->
                Text("${entry.date} — ${entry.name}: ${entry.amountCents / 100.0} ${entry.currency}")
            }
        }
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/AccountDetailScreen.kt`

- [ ] **Step 4: `DashboardScreen` gana `onAccountClick` y cada fila de cuenta se vuelve clickeable**

Reemplazar el contenido completo de `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/DashboardScreen.kt`:

```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun DashboardScreen(viewModel: DashboardViewModel, onAccountClick: (String) -> Unit) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        state.balanceSheet?.let { bs ->
            Text("Patrimonio neto: ${bs.net_worth.cents ?: bs.net_worth.amount} ${bs.currency}")
        }
        Button(onClick = { viewModel.refresh() }) { Text("Actualizar") }
        if (state.isSyncing) CircularProgressIndicator()
        state.syncError?.let { Text("Error: $it") }

        Text("Cuentas")
        LazyColumn {
            items(state.accounts) { account ->
                Text(
                    "${account.name}: ${account.balanceCents / 100.0} ${account.currency}",
                    modifier = Modifier.fillMaxWidth().clickable { onAccountClick(account.id) }
                )
            }
        }

        Text("Transacciones recientes")
        LazyColumn {
            items(state.recentEntries) { entry ->
                Text("${entry.date} — ${entry.name}: ${entry.amountCents / 100.0} ${entry.currency}")
            }
        }
    }
}
```

- [ ] **Step 5: `MainActivity` construye `accountDetailViewModelFactory` y lo pasa a `App(...)`**

En `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`, dentro del bloque `setContent { App(...) }`, agregar el parámetro (los demás parámetros nuevos de Tasks 6/7 se agregan en esos Tasks — este Step deja el resto sin resolver todavía, es esperado, el build completo de `App` recién cierra en Task 7):

```kotlin
accountDetailViewModelFactory = { accountId ->
    AccountDetailViewModel(
        scope = lifecycleScope,
        accountId = accountId,
        accountDao = database.accountDao(),
        entryDao = database.entryDao()
    )
}
```

- [ ] **Step 6: Commit (sin build completo — mismo motivo que Task 4)**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): AccountDetailScreen + Dashboard clickeable (wave 1b task 5)"
git push origin main
```

---

## Task 6: `RulesListScreen` + `RuleDetailScreen` (lectura)

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RulesListViewModel.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RulesListScreen.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleDetailViewModel.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleDetailScreen.kt`
- Modify: `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`

**Interfaces:**
- Consumes: `RuleDao.observeAll()`, `RuleRunDao.observeByRuleId(ruleId)`, `FinancePyApi.deleteRule(id)` (Task 3).
- Produces: `@Composable fun RulesListScreen(viewModel: RulesListViewModel, onRuleClick: (String) -> Unit, onCreateClick: () -> Unit)`, `@Composable fun RuleDetailScreen(viewModel: RuleDetailViewModel, onEditClick: () -> Unit, onDeleted: () -> Unit)`.

- [ ] **Step 1: `RulesListViewModel`**

```kotlin
package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity

class RulesListViewModel(
    scope: CoroutineScope,
    ruleDao: RuleDao
) {
    private val _rules = MutableStateFlow<List<RuleEntity>>(emptyList())
    val rules: StateFlow<List<RuleEntity>> = _rules

    init {
        ruleDao.observeAll().onEach { _rules.value = it }.launchIn(scope)
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RulesListViewModel.kt`

- [ ] **Step 2: `RulesListScreen`**

```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun RulesListScreen(
    viewModel: RulesListViewModel,
    onRuleClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val rules by viewModel.rules.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Button(onClick = onCreateClick) { Text("Nueva regla") }
        LazyColumn {
            items(rules) { rule ->
                Text(
                    "${rule.name ?: "(sin nombre)"} — ${if (rule.active) "activa" else "inactiva"}",
                    modifier = Modifier.fillMaxWidth().clickable { onRuleClick(rule.id) }
                )
            }
        }
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RulesListScreen.kt`

- [ ] **Step 3: `RuleDetailViewModel`**

```kotlin
package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity
import py.com.cdco.financespy.db.RuleRunDao
import py.com.cdco.financespy.db.RuleRunEntity

data class RuleDetailState(
    val rule: RuleEntity? = null,
    val runs: List<RuleRunEntity> = emptyList(),
    val isDeleting: Boolean = false,
    val isTogglingActive: Boolean = false,
    val deleteError: String? = null,
    val toggleError: String? = null
)

class RuleDetailViewModel(
    private val scope: CoroutineScope,
    private val ruleId: String,
    private val api: FinancePyApi,
    ruleDao: RuleDao,
    ruleRunDao: RuleRunDao
) {
    private val _state = MutableStateFlow(RuleDetailState())
    val state: StateFlow<RuleDetailState> = _state

    init {
        combine(ruleDao.observeAll(), ruleRunDao.observeByRuleId(ruleId)) { rules, runs ->
            _state.value.copy(rule = rules.firstOrNull { it.id == ruleId }, runs = runs)
        }.onEach { _state.value = it }.launchIn(scope)
    }

    fun toggleActive() {
        val current = _state.value.rule ?: return
        scope.launch {
            _state.value = _state.value.copy(isTogglingActive = true, toggleError = null)
            runCatching {
                api.updateRule(ruleId, py.com.cdco.financespy.api.dto.UpdateRuleBody(active = !current.active))
            }
                .onSuccess { _state.value = _state.value.copy(isTogglingActive = false) }
                .onFailure { e -> _state.value = _state.value.copy(isTogglingActive = false, toggleError = e.message ?: "Error al cambiar estado") }
        }
    }

    fun delete(onDeleted: () -> Unit) {
        scope.launch {
            _state.value = _state.value.copy(isDeleting = true, deleteError = null)
            runCatching { api.deleteRule(ruleId) }
                .onSuccess { onDeleted() }
                .onFailure { e -> _state.value = _state.value.copy(isDeleting = false, deleteError = e.message ?: "Error al borrar") }
        }
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleDetailViewModel.kt`

- [ ] **Step 4: `RuleDetailScreen`**

```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun RuleDetailScreen(
    viewModel: RuleDetailViewModel,
    onEditClick: () -> Unit,
    onDeleted: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        state.rule?.let { rule ->
            Text(rule.name ?: "(sin nombre)")
            Text("Condición: ${rule.conditionType} ${rule.conditionOperator} ${rule.conditionValue}")
            Text("Acción: ${rule.actionType} → ${rule.actionValue}")
            Text("Estado: ${if (rule.active) "activa" else "inactiva"}")
            Button(onClick = { viewModel.toggleActive() }) {
                Text(if (state.isTogglingActive) "..." else if (rule.active) "Desactivar" else "Activar")
            }
            state.toggleError?.let { Text("Error: $it") }
            Button(onClick = onEditClick) { Text("Editar") }
            Button(onClick = { viewModel.delete(onDeleted) }) { Text(if (state.isDeleting) "Borrando..." else "Borrar") }
            state.deleteError?.let { Text("Error: $it") }
        }
        Text("Historial de ejecuciones")
        LazyColumn {
            items(state.runs) { run ->
                Text("${run.executedAt} — ${run.status} (${run.executionType})")
            }
        }
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleDetailScreen.kt`

- [ ] **Step 5: `MainActivity` gana `rulesListViewModelFactory` y `ruleDetailViewModelFactory`**

Agregar dentro del bloque `setContent { App(...) }` de `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`:

```kotlin
rulesListViewModelFactory = {
    RulesListViewModel(scope = lifecycleScope, ruleDao = database.ruleDao())
},
ruleDetailViewModelFactory = { ruleId ->
    RuleDetailViewModel(
        scope = lifecycleScope, ruleId = ruleId, api = api,
        ruleDao = database.ruleDao(), ruleRunDao = database.ruleRunDao()
    )
},
```
Agregar los imports correspondientes (`py.com.cdco.financespy.screens.RulesListViewModel`, `py.com.cdco.financespy.screens.RuleDetailViewModel`) al tope del archivo.

- [ ] **Step 6: Commit (sin build completo — falta `ruleFormViewModelFactory` de Task 7)**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): RulesListScreen + RuleDetailScreen (wave 1b task 6)"
git push origin main
```

---

## Task 7: `RuleFormScreen` (crear/editar) — cierra la wave, build completo + prueba en dispositivo real

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleFormViewModel.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleFormScreen.kt`
- Modify: `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`

**Interfaces:**
- Consumes: `FinancePyApi.fetchCategories()`, `.fetchMerchants()`, `.fetchTags()`, `.createRule()`, `.updateRule()` (Task 3), `RuleDao.findById()` (Task 2).
- Produces: `@Composable fun RuleFormScreen(viewModel: RuleFormViewModel, onSaved: () -> Unit)`.

- [ ] **Step 1: `RuleFormViewModel`**

```kotlin
package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ActionAttributes
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.ConditionAttributes
import py.com.cdco.financespy.api.dto.CreateRuleBody
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.TagDto
import py.com.cdco.financespy.db.RuleDao

data class RuleFormState(
    val isEditing: Boolean = false,
    val name: String = "",
    val conditionType: String = "transaction_name",
    val conditionOperator: String = "like",
    val conditionValue: String = "",
    val actionType: String = "set_transaction_category",
    val actionValue: String = "",
    val categories: List<CategoryDto> = emptyList(),
    val merchants: List<MerchantDto> = emptyList(),
    val tags: List<TagDto> = emptyList(),
    val isSaving: Boolean = false,
    val error: String? = null
)

class RuleFormViewModel(
    private val scope: CoroutineScope,
    private val ruleId: String?,
    private val api: FinancePyApi,
    private val ruleDao: RuleDao
) {
    private val _state = MutableStateFlow(RuleFormState(isEditing = ruleId != null))
    val state: StateFlow<RuleFormState> = _state

    init {
        scope.launch {
            val categories = runCatching { api.fetchCategories() }.getOrDefault(emptyList())
            val merchants = runCatching { api.fetchMerchants() }.getOrDefault(emptyList())
            val tags = runCatching { api.fetchTags() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(categories = categories, merchants = merchants, tags = tags)

            if (ruleId != null) {
                ruleDao.findById(ruleId)?.let { rule ->
                    _state.value = _state.value.copy(
                        name = rule.name.orEmpty(),
                        conditionType = rule.conditionType,
                        conditionOperator = rule.conditionOperator,
                        conditionValue = rule.conditionValue,
                        actionType = rule.actionType,
                        actionValue = rule.actionValue
                    )
                }
            }
        }
    }

    fun updateName(value: String) { _state.value = _state.value.copy(name = value) }
    fun updateConditionType(value: String) { _state.value = _state.value.copy(conditionType = value) }
    fun updateConditionOperator(value: String) { _state.value = _state.value.copy(conditionOperator = value) }
    fun updateConditionValue(value: String) { _state.value = _state.value.copy(conditionValue = value) }
    fun updateActionType(value: String) { _state.value = _state.value.copy(actionType = value) }
    fun updateActionValue(value: String) { _state.value = _state.value.copy(actionValue = value) }

    fun save(onSaved: () -> Unit) {
        val s = _state.value
        if (s.conditionValue.isBlank() || s.actionValue.isBlank()) {
            _state.value = s.copy(error = "Completá la condición y la acción antes de guardar")
            return
        }
        scope.launch {
            _state.value = s.copy(isSaving = true, error = null)
            val body = CreateRuleBody(
                name = s.name.ifBlank { null },
                conditions_attributes = listOf(ConditionAttributes(s.conditionType, s.conditionOperator, s.conditionValue)),
                actions_attributes = listOf(ActionAttributes(s.actionType, s.actionValue))
            )
            val result = if (ruleId != null) {
                runCatching { api.updateRule(ruleId, py.com.cdco.financespy.api.dto.UpdateRuleBody(name = body.name)) }
            } else {
                runCatching { api.createRule(body) }
            }
            result
                .onSuccess { onSaved() }
                .onFailure { e -> _state.value = _state.value.copy(isSaving = false, error = e.message ?: "Error al guardar") }
        }
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleFormViewModel.kt`

Nota real sobre `update`: `UpdateRuleBody` (Task 3) solo soporta `active`/`name` — no `conditions_attributes`/`actions_attributes`. Esto es una limitación intencional para mantener 1b acotado: **editar una regla existente en 1b solo permite cambiar el nombre** (el toggle de `active` se maneja aparte, ver Step 3 de `RuleDetailScreen` — ya cubierto en Task 6 si se agrega un botón de toggle ahí, o se puede agregar en este Task si no se hizo). Cambiar condición/acción de una regla ya creada requiere borrarla y crear una nueva — documentado acá explícitamente para que no se lea como un bug si `RuleFormScreen` en modo edición no aplica los cambios de condición/acción.

- [ ] **Step 2: `RuleFormScreen`**

```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun RuleFormScreen(viewModel: RuleFormViewModel, onSaved: () -> Unit) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text(if (state.isEditing) "Editar regla" else "Nueva regla")

        TextField(value = state.name, onValueChange = viewModel::updateName, label = { Text("Nombre (opcional)") })

        Text("Condición: ${state.conditionType}")
        TextField(
            value = state.conditionValue,
            onValueChange = viewModel::updateConditionValue,
            label = { Text("Valor de la condición (texto, id de comercio o id de categoría según el tipo)") }
        )

        Text("Acción: ${state.actionType}")
        TextField(
            value = state.actionValue,
            onValueChange = viewModel::updateActionValue,
            label = { Text("Valor de la acción (id de categoría o de tag)") }
        )

        if (state.categories.isNotEmpty()) {
            Text("Categorías disponibles: ${state.categories.joinToString { "${it.name} (${it.id})" }}")
        }
        if (state.tags.isNotEmpty()) {
            Text("Tags disponibles: ${state.tags.joinToString { "${it.name} (${it.id})" }}")
        }
        if (state.merchants.isNotEmpty()) {
            Text("Comercios disponibles: ${state.merchants.joinToString { "${it.name} (${it.id})" }}")
        }

        Button(onClick = { viewModel.save(onSaved) }) { Text(if (state.isSaving) "Guardando..." else "Guardar") }
        state.error?.let { Text("Error: $it") }
    }
}
```
Archivo: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/RuleFormScreen.kt`

Nota UI: esta versión usa listas de texto plano para categorías/tags/comercios en vez de un dropdown/picker real — coherente con el resto de 1a/1b (toda la UI es texto plano, sin diseño, ya señalado como pendiente de pulido visual, no forma parte de esta wave). El usuario copia el id manualmente al campo de valor. Feo pero funcional para probar el flujo end-to-end; un picker real es candidato a una pasada de pulido de UI posterior, no de esta wave.

- [ ] **Step 3: `MainActivity` gana `ruleFormViewModelFactory` — cierra todos los parámetros de `App(...)`**

Agregar dentro del bloque `setContent { App(...) }` de `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`:

```kotlin
ruleFormViewModelFactory = { ruleId ->
    RuleFormViewModel(scope = lifecycleScope, ruleId = ruleId, api = api, ruleDao = database.ruleDao())
}
```
Agregar el import `py.com.cdco.financespy.screens.RuleFormViewModel`. En este punto `App(...)` en `MainActivity.kt` debe tener los 8 parámetros completos: `isLoggedIn`, `onLoginClick`, `dashboardViewModelFactory`, `transactionsViewModelFactory`, `rulesListViewModelFactory`, `ruleDetailViewModelFactory`, `ruleFormViewModelFactory`, `accountDetailViewModelFactory`.

- [ ] **Step 4: Build completo**

Run: `cd native/financespy-kmp && ANDROID_HOME=/home/fabrizio/Android/Sdk ./gradlew clean :androidApp:assembleDebug --no-daemon`
Expected: `BUILD SUCCESSFUL`. Si falla, resolver antes de seguir — este es el primer punto desde Task 4 donde el proyecto completo debe compilar.

- [ ] **Step 5: Instalar y probar en el dispositivo físico real (obligatorio — ver nota al principio del plan)**

```bash
# desde la Mac, con el telefono conectado por USB
adb devices   # confirmar que aparece
```
Bajar el APK del host (`scp fabrizio@100.105.31.71:~/financespy/native/financespy-kmp/androidApp/build/outputs/apk/debug/androidApp-debug.apk .`), instalar (`adb install -r androidApp-debug.apk`), abrir la app.

Probar en persona, en este orden:
1. Dashboard → tocar una cuenta → confirmar que abre `AccountDetailScreen` con las transacciones de esa cuenta nomás.
2. Volver, ir a tab "Reglas" → confirmar que lista las reglas reales de la familia (si hay alguna preexistente con más de 1 condición/acción, confirmar que NO aparece en la lista — `toEntityOrNull()` de Task 3 la filtra a propósito, no debería crashear).
3. Tocar "Nueva regla" → crear una regla de prueba real (ej. condición `transaction_name`/`like`/"uber", acción `set_transaction_category` con un id de categoría real tomado de la lista que se muestra en el form) → Guardar → confirmar que vuelve a la lista y la regla nueva aparece.
4. Tocar la regla recién creada → confirmar el detalle muestra la condición/acción correctas.
5. Borrar esa regla de prueba → confirmar que desaparece de la lista.
6. Confirmar en la web real (`https://finance.cd-co.com.py/rules`, logueado como el usuario) que la regla de prueba efectivamente se creó y se borró en el server — no solo en la caché local de Room.

Si cualquiera de estos 6 puntos falla, diagnosticar con `adb logcat` (mismo patrón usado para depurar los 5 bugs de 1a) antes de dar la wave por cerrada — no alcanza con "compila".

- [ ] **Step 6: Commit final**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): RuleFormScreen, cierra wave 1b (build + prueba en dispositivo real)"
git push origin main
```

---

## Cierre de wave 1b

Con las 7 tasks mergeadas: backend con create/update/destroy real para reglas simples, cliente nativo con detalle de cuenta, gestión de reglas (lectura completa + creación/edición/borrado acotado a 1 condición + 1 acción), y navegación real entre pantallas (ya no son solo 2 tabs planos). Todo probado en dispositivo físico contra producción, no solo compilado.

**Pendiente explícito para una wave futura, no de 1b**: picker real (dropdown) para categoría/comercio/tag en `RuleFormScreen` en vez de texto plano con el id a mano; soporte de edición completa de condición/acción (hoy `update` en 1b solo cambia el nombre); condiciones múltiples/compuestas si algún día se necesitan. 1c sigue siendo Presupuestos/Metas/Cuentas a Cobrar (necesitan API nueva, no arrancada todavía).
