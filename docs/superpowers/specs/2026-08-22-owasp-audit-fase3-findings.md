# Informe de Auditoría de Seguridad OWASP Top 10 — Fase 3

**Fecha:** 22 de agosto de 2026
**Alcance:** Toda la aplicación (Web Controllers, Admin Controllers, API v1, Concerns, Jobs, Models, Views y Stimulus Controllers).
**Propósito:** Diagnóstico completo de vulnerabilidades reales (OWASP Top 10) en todo el sistema. No se aplican cambios de código en producción en esta fase.

---

## Resumen Ejecutivo

Se realizó un barrido exhaustivo de seguridad OWASP Top 10 sobre la totalidad del código fuente de la aplicación FinancePY / CD-CO-ERP. Se identificaron 5 hallazgos reales y confirmados (no teóricos), ordenados a continuación por severidad decreciente.

---

## Hallazgo 1: Inyección DOM XSS y Redirección Abierta mediante parámetro `return_to` en `StoreLocation` y `_settings_nav.html.erb`

* **Severidad:** Alta (High)
* **Categoría OWASP:** A03:2021 – Injection / A01:2021 – Broken Access Control
* **Archivo y Línea:**
  * `app/controllers/concerns/store_location.rb:27-29`
  * `app/views/settings/_settings_nav.html.erb:62, 99`

### Descripción y Escenario Concreto de Explotación
El concern `StoreLocation` se encuentra incluido globalmente en `ApplicationController` y ejecuta un callback `before_action :store_return_to` en cada petición. Si la petición incluye el parámetro `params[:return_to]`, este valor se almacena directamente en la sesión del usuario (`session[:return_to] = params[:return_to]`) sin ninguna validación de esquema, host o sanitización de caracteres.

Posteriormente, en la vista de navegación de ajustes (`app/views/settings/_settings_nav.html.erb`), el helper `previous_path` (que retorna `session[:return_to]`) se utiliza directamente como atributo `href` en los enlaces de retorno y botones con acceso rápido (`data-controller="hotkey"` en la tecla `Esc`):
```erb
<%= render DS::Link.new(
  text: t("settings.settings_nav_link_large.previous"),
  icon: "chevron-left",
  href: previous_path,
  variant: "ghost",
) %>
<%= link_to previous_path, class: "...", data: { controller: "hotkey", hotkey: "Escape" } do %>
  <kbd>esc</kbd>
<% end %>
```

**Escenario de Ataque:**
1. Un atacante envía a una víctima autenticada un enlace fabricado:
   `https://app.com/settings/preferences?return_to=javascript:alert(document.cookie)` (o un payload para exfiltración de tokens de sesión).
2. La víctima abre el enlace. `StoreLocation` guarda `javascript:alert(document.cookie)` en `session[:return_to]`.
3. El HTML renderizado contiene `<a href="javascript:alert(document.cookie)">`.
4. Cuando la víctima hace clic en el botón "Volver" o presiona la tecla `Escape`, el navegador ejecuta el script JavaScript en el contexto de la sesión activa de la víctima (DOM XSS / Robo de sesión).
5. Alternativamente, si el parámetro es `return_to=https://sitio-phishing-malicioso.com`, el usuario es redirigido a una página externa sin confirmación (Open Redirect).

---

## Hallazgo 2: Invocación Insegura de Constantes (`constantize`) con Parámetros No Controlados en `Import::MappingsController`

* **Severidad:** Alta (High)
* **Categoría OWASP:** A03:2021 – Injection / A01:2021 – Broken Access Control
* **Archivo y Línea:**
  * `app/controllers/import/mappings_controller.rb:37, 41`

### Descripción y Escenario Concreto de Explotación
En `Import::MappingsController`, las funciones `mappable_class` y `mapping_class` ejecutan `.constantize` sobre parámetros enviados directamente por el cliente (`mapping_params[:mappable_type]` y `mapping_params[:type]`) sin aplicar ninguna lista blanca (whitelist) de clases autorizadas:
```ruby
def mappable_class
  mapping_params[:mappable_type]&.constantize
end

def mapping_class
  mapping_params[:type]&.constantize
end
```

Posteriormente se ejecuta:
`@mappable ||= mappable_class.find_by(id: mapping_params[:mappable_id], family: Current.family)`

**Escenario de Ataque:**
1. Un usuario autenticado envía una petición HTTP `PATCH /imports/:import_id/mappings/:id` manipulando el parámetro `import_mapping[mappable_type]`.
2. El atacante puede enviar nombres de clases internas del sistema (por ejemplo `User`, `SsoProvider`, `Doorkeeper::AccessToken`, `ActiveStorage::Blob`).
3. El método `.constantize` instanciará dinámicamente cualquier constante/clase Ruby cargada en memoria.
4. Además de permitir la consulta o vinculación no autorizada de modelos sensibles que no forman parte del flujo de mapeo de importaciones, el envío de constantes sin el método `.find_by` (como `Object`, `File`, `Kernel`) provoca excepciones no capturadas (`NoMethodError` / `NameError`) resultando en denegación de servicio (DoS) o fugas de traza de pila (stacktrace).

---

## Hallazgo 3: Ausencia de Control de Frecuencia (Rate Limiting) en la Verificación de Códigos TOTP 2FA (`MfaController#verify_code`)

* **Severidad:** Alta (High)
* **Categoría OWASP:** A07:2021 – Identification and Authentication Failures
* **Archivo y Línea:**
  * `app/controllers/mfa_controller.rb:24-33`
  * `config/initializers/rack_attack.rb:25-30`

### Descripción y Escenario Concreto de Explotación
El controlador `MfaController#verify_code` procesa la verificación del código de 6 dígitos TOTP durante el proceso de autenticación de dos factores (2FA).

En `config/initializers/rack_attack.rb`, se definen reglas de limitación de tasa para inicio de sesión web (`/sessions`), login API (`/api/v1/auth/login`), y autenticación WebAuthn (`/mfa/webauthn_options`, `/mfa/verify_webauthn`). Sin embargo, el endpoint `/mfa/verify_code` **NO** está incluido en la configuración de `Rack::Attack`, ni tampoco el controlador `MfaController` implementa un contador de intentos fallidos o bloqueo temporal.

**Escenario de Ataque:**
1. Un atacante obtiene o adivina las credenciales primarias (email y contraseña) de una víctima que tiene 2FA (TOTP) activado.
2. Al iniciar sesión, la aplicación autentica las credenciales primarias y establece `session[:mfa_user_id]`, redirigiendo a la pantalla de verificación 2FA.
3. El código TOTP de 6 dígitos posee un espacio de búsqueda de exactamente 1,000,000 de combinaciones posibles (000000 al 999999) y permanece válido durante una ventana de tiempo de 30 a 60 segundos.
4. Al carecer de limitación de frecuencia por IP o usuario, el atacante ejecuta un script automatizado enviando miles de peticiones HTTP `POST /mfa/verify_code` por segundo.
5. El atacante logra adivinar el código válido dentro del rango de tiempo sin ser bloqueado, derivando en un bypass completo de la protección de segundo factor (2FA).

---

## Hallazgo 4: Búsqueda de Registros Sin Aislamiento de Inquilino (IDOR) en Controladores de Integración Bancaria

* **Severidad:** Media (Medium)
* **Categoría OWASP:** A01:2021 – Broken Access Control
* **Archivo y Línea:**
  * `app/controllers/plaid_items_controller.rb:72`
  * `app/controllers/simplefin_items_controller.rb:388`
  * `app/controllers/enable_banking_items_controller.rb:487`

### Descripción y Escenario Concreto de Explotación
En los métodos `link_existing_account` de varios controladores de integración bancaria (`PlaidItemsController`, `SimplefinItemsController`, `EnableBankingItemsController`), la consulta del registro del proveedor se realiza directamente sobre el modelo global usando el ID recibido en los parámetros HTTP sin acoplarlo inicialmente a la familia actual (`Current.family`):

* En `PlaidItemsController:72`: `plaid_account = PlaidAccount.find(params[:plaid_account_id])`
* En `SimplefinItemsController:388`: `simplefin_account = SimplefinAccount.find(params[:simplefin_account_id])`
* En `EnableBankingItemsController:487`: `enable_banking_account = EnableBankingAccount.find(params[:enable_banking_account_id])`

**Escenario de Ataque:**
1. Un usuario autenticado de la Familia A envía una petición `POST /plaid_items/link_existing_account` pasando un `plaid_account_id` perteneciente a la Familia B.
2. Aunque existe una validación posterior en el código que impide completar la vinculación si el elemento padre no pertenece a `Current.family`, el uso de `.find` global expone la aplicación a ataques de enumeración de IDs entre inquilinos (IDOR / Tenant Leak).
3. El atacante puede diferenciar entre IDs existentes en otras familias y no existentes observando la respuesta HTTP (`ActiveRecord::RecordNotFound` de Rails resulta en 404 instantáneo vs. fallos de validación con mensajes alternativos), violando las directrices de aislamiento estricto por inquilino (`Current.family`).

---

## Hallazgo 5: Alteración de Estado de Interfaz y Fuga de Configuración Super-Admin mediante Cookie No Autenticada

* **Severidad:** Baja (Low)
* **Categoría OWASP:** A05:2021 – Security Misconfiguration / A07:2021 – Identification and Authentication Failures
* **Archivo y Línea:**
  * `app/helpers/application_helper.rb:114-118`

### Descripción y Escenario Concreto de Explotación
El helper `show_super_admin_bar?` contiene la siguiente lógica:
```ruby
def show_super_admin_bar?
  if params[:admin].present?
    cookies.permanent[:admin] = params[:admin]
  end

  cookies[:admin] == "true"
end
```

**Escenario de Ataque:**
1. Cualquier usuario (incluso no autenticado o no super-admin) puede realizar una petición GET a cualquier página de la aplicación incluyendo `?admin=true` o `?admin=false`.
2. Esto modifica de forma permanente la cookie `admin` en el navegador del usuario.
3. Si bien las acciones administrativas reales en los controladores dentro del namespace `/admin` requieren el callback `before_action :require_super_admin!`, la verificación condicional en las vistas compartidas (`render "impersonation_sessions/super_admin_bar" if Current.true_user&.super_admin? && show_super_admin_bar?`) confía en el estado manipulable de la cookie.
4. Esto permite a un usuario no autorizado alterar persistentemente el comportamiento de la interfaz o manipular banderas de estado en cookies sin pasar por flujos de autenticación o autorización.
