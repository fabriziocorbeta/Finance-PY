---
type: guia
title: "FinancePY — Arranque automático y fallback (notebook WSL2)"
status: lista-para-ejecutar
created: 2026-08-06
updated: 2026-08-06
tags: [financespy, infraestructura, wsl2, fallback, alta-disponibilidad]
---

# FinancePY — Arranque automático y fallback (notebook WSL2)

Guía ejecutable para que FinancePY se recupere solo tras un corte, y para tener una red de seguridad cuando no se recupere.

Notas relacionadas: [[FinancePY - Hosting fase prueba (PC local)]] · [[FinancePY — Guía paso a paso migración VM a notebook Windows]] · [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]]

**Convención de marcas usada en todo el documento:**

| Marca | Significado |
|---|---|
| `[V]` | **Verificado** contra código, documentación oficial o el repo `/Users/Fabrizio/code/financespy` |
| `[R]` | **Recomendación** — criterio, no doctrina |
| `[C]` | **A confirmar en la notebook** — no se puede saber desde la Mac; hay comando exacto |

**Regla de seguridad:** ningún comando de esta guía imprime secretos. Si en alguna salida ves algo tipo `--token ey...`, `SECRET_KEY_BASE=...` o `DATABASE_URL=...`, no lo copies, no lo pegues en ningún chat.

---

## 1. Qué pasó hoy (2026-08-06)

Hecho, en orden:

1. Hubo un corte (luz y/o internet) en la casa donde está la notebook que sirve FinancePY.
2. `finance.cd-co.com.py` empezó a devolver **Cloudflare Error 1033 / HTTP 530** — que significa exactamente: *la red de Cloudflare no encuentra una instancia sana de `cloudflared`* `[V]`.
3. Se reinició la notebook y el servicio **no volvió solo** después de varios minutos.

**Causa raíz (diagnóstico verificado):** la cadena de arranque tiene 4 eslabones y sólo el último está resuelto.

| Eslabón | ¿Arranca solo hoy? | Por qué |
|---|---|---|
| Windows bootea | Sí | — |
| WSL2 arranca la distro | **No** `[V]` | WSL **no tiene ninguna función de arranque al boot de Windows**. Revisados todos los releases de `microsoft/WSL` hasta 2.9.4: no existe. La opción `[wsl2] autostart=true` que circula por internet **es falsa, no existe** — no usarla. |
| Daemon de Docker | **No** | Depende de que la distro esté viva. Y si es **Docker Desktop**, además depende de que un usuario **inicie sesión en Windows** — bloqueante duro confirmado por Docker (`docker/roadmap#515`, abierto) `[V]`. |
| `cloudflared` | **No** `[V]` | Quedó instalado como servicio **SysV** (`/etc/init.d/cloudflared`). En WSL sin systemd, PID 1 es `/init` de Microsoft y **no procesa runlevels**: los symlinks `/etc/rcN.d/` existen pero nadie los mira. Además el script SysV lanza el proceso con `&` y **no tiene supervisor**: si muere, nadie lo levanta. |
| Contenedores Docker | **Sí** `[V]` | Los 4 servicios de `compose.local.yml` ya tienen `restart: unless-stopped` (líneas 38, 55, 75, 92). **Esto no hay que tocarlo.** |

**Conclusión:** el incidente no fue un problema de failover ni de red. Fue un problema de arranque. El único origen volvió, el stack no.

Dato adicional `[V]`: aun con todo bien configurado, cuando vuelve internet `cloudflared` puede tardar **hasta ~5 minutos** en reconectar por su backoff exponencial (`retry/backoffhandler.go`: espera aleatoria entre 0 y `10s × 2^retries`, con `retries` default = 5 → hasta 320 s). Eso es comportamiento normal, no una falla.

---

## 2. Verificar primero — antes de tocar nada

Varias decisiones de la sección 3 dependen de estos resultados. **Correr todo esto y anotar las respuestas antes de cambiar una sola cosa.**

### 2.1 Forense: ¿qué pasó realmente hoy?

Esto decide si el problema fue la luz, el internet o Windows Update. Sin este dato, cualquier arreglo es a ciegas.

**PowerShell como Administrador:**

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,42,105,107,109,1074,6006,6008} -MaxEvents 60 |
  Select-Object TimeCreated, Id, ProviderName,
    @{n='Msg';e={ ($_.Message -replace "`r`n",' ').Substring(0,[Math]::Min(160,$_.Message.Length)) }} |
  Format-Table -Wrap
```

Lectura de los IDs `[V]`:

| ID | Significa | Qué concluir |
|---|---|---|
| **105** | Cambió la fuente de alimentación (AC ↔ batería) | Si hay un 105 justo antes de la caída → **sí hubo corte de luz**. Si no hay ninguno → **no lo hubo**, fue internet u otra cosa. |
| **41** | Reinicio sin apagado limpio (Kernel-Power) | Corte duro, cuelgue o apagón térmico |
| **6008** | Apagado inesperado + hora exacta | Confirma el momento |
| **1074** | Apagado/reinicio iniciado por un proceso o usuario | Si el mensaje dice "Windows Update" → **no fue la luz** |
| **109** | El kernel inició el apagado | Típico de batería crítica |
| **42 / 107** | Entró/salió de suspensión | La máquina se durmió → el Paso 8 de la guía de migración no estaba aplicado |
| **6006** | Log de eventos detenido | Apagado limpio |

### 2.2 Salud de la batería

```powershell
powercfg /batteryreport /output "$env:USERPROFILE\Desktop\battery-report.html" /duration 14
```

Abrir el HTML del Escritorio. Qué mirar:

- **Installed batteries** → `DESIGN CAPACITY` vs `FULL CHARGE CAPACITY`. Salud = FCC/DC. **>80%** sana · **50–80%** degradada pero sirve de buffer · **<50%** casi sin autonomía · **sin batería listada / FCC en 0** = batería muerta, la notebook se comporta como un escritorio.
- **Recent usage** → columna `SOURCE` (AC/Battery) con timestamps. **Este es el dato forense clave**: si alrededor de la hora de la caída no hay transición a `Battery`, no hubo corte de luz.

Chequeo rápido sin abrir el HTML:

```powershell
Get-CimInstance Win32_Battery | Select-Object Name, EstimatedChargeRemaining, BatteryStatus
```

Si no devuelve nada → **no hay batería detectada**, y eso solo explica la caída. `[C]`

### 2.3 Windows: versión, energía, Fast Startup, hardware

```powershell
# Version de Windows y edicion (Home ignora casi todas las politicas de Windows Update)
[System.Environment]::OSVersion.Version
(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
(Get-ComputerInfo).WindowsProductName

# Marca/modelo (decide si la BIOS puede tener "Wake on AC" - ver seccion 9)
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, SystemFamily

# Fast Startup activo? 1 = si (rompe el trigger "Al iniciar el sistema")
(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power").HiberbootEnabled

# Que hace la tapa hoy? AMBOS indices deben ser 0x00000000 (= No hacer nada)
powercfg /query SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936

# Procesadores logicos (para dimensionar .wslconfig)
(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
```

> El Paso 8 de [[FinancePY — Guía paso a paso migración VM a notebook Windows]] ("Que la notebook no se duerma ni se apague sola") **quedó sin tildar en el checklist** `[V]`. O sea: no hay registro escrito de que la configuración de energía se haya aplicado. Hasta que el comando de arriba muestre `0x00000000` en AC **y** DC, tratalo como no aplicado.

### 2.4 WSL: versión y si systemd está activo

```powershell
wsl --version      # si responde "Invalid command line option" -> WSL "inbox" viejo, hay que actualizar
wsl -l -v          # NOMBRE EXACTO de la distro (Ubuntu / Ubuntu-22.04 / Ubuntu-24.04...) + si existe "docker-desktop"
```

`[V]` systemd en WSL requiere **WSL ≥ 0.67.6**, que sólo existe en la **versión Store**. El release estable actual es 2.7.11 (2026-07-24), así que cualquier WSL actualizado lo cumple. Si `wsl --version` no responde: `wsl --update` o instalar WSL desde Microsoft Store primero.

**Dentro de WSL (bash):**

```bash
ps -p 1 -o comm=              # "systemd" = activo | "init" = NO activo
cat /etc/wsl.conf 2>/dev/null # ya tiene [boot] systemd=true?
systemctl is-system-running 2>&1
```

### 2.5 ⚠️ Docker Desktop o Docker Engine — la pregunta que decide todo

**Si es Docker Desktop, nada más de esta guía sirve hasta migrar.** Docker Desktop **no puede arrancar sin que un usuario inicie sesión en Windows** — confirmado por un mantenedor de Docker en `docker/roadmap#515` (2023-08-11, issue todavía abierto) `[V]`. El comentario de la línea 5 de `compose.local.yml` dice literalmente "dentro de WSL2/Ubuntu con **Docker Desktop**" `[V]`, pero eso es documentación, no evidencia.

**PowerShell:**

```powershell
Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Get-Service com.docker.service -ErrorAction SilentlyContinue
```

**Dentro de WSL (bash):**

```bash
docker context ls                    # "desktop-linux" activo => Docker Desktop
readlink -f "$(command -v docker)"   # si apunta a /mnt/wsl/docker-desktop/... => Docker Desktop
dpkg -l | grep -E 'docker-ce|containerd'   # si hay docker-ce => Docker Engine nativo (bien)
ls -l /var/run/docker.sock
```

### 2.6 cloudflared: cómo quedó instalado y dónde busca su config

**Dentro de WSL (bash):**

```bash
ls -l /etc/systemd/system/cloudflared.service 2>/dev/null   # unit systemd?
ls -l /etc/init.d/cloudflared 2>/dev/null                   # script SysV? (esperado: existe)
ls -l /etc/rc?.d/*et 2>/dev/null                            # symlinks de runlevel
ls -la ~/.cloudflared/ /etc/cloudflared/ 2>/dev/null
cloudflared --version
cloudflared tunnel list        # estado: Healthy / Degraded / Down / Inactive
```

`[V]` `cloudflared` **sólo autodetecta archivos llamados `config.yml` o `config.yaml`**, y sólo en: `~/.cloudflared`, `~/.cloudflare-warp`, `~/cloudflare-warp`, `/etc/cloudflared`, `/usr/local/etc/cloudflared` (`config/configuration.go`). Un archivo llamado `financespy-notebook-config.yml` **nunca** se autodetecta — sólo funciona pasándolo con `--config`.

> ⚠️ Si al inspeccionar `/etc/init.d/cloudflared` aparece un `--token ey...`, **no lo copies ni lo pegues en ningún lado.**

### 2.7 Dónde vive el repo dentro de WSL

```bash
ls -d ~/financespy 2>/dev/null; find / -name compose.local.yml -not -path '*/node_modules/*' 2>/dev/null | head
```

`[V]` Microsoft recomienda explícitamente **no** tener archivos de proyecto en `/mnt/c/...`: el acceso Windows→Linux va por 9p y es órdenes de magnitud más lento, y al boot depende de que el automount haya terminado. Si el repo está bajo `/mnt/c`, `[R]` moverlo a `~/` dentro de la distro.

### 2.8 Checklist de resultados

Anotar antes de seguir:

- [ ] ¿Hubo evento 105 cerca de la caída? (¿corte de luz sí/no?)
- [ ] ¿Hubo evento 1074 con "Windows Update"?
- [ ] Salud de batería (FCC/DC en %): ______
- [ ] Fast Startup (HiberbootEnabled): ______
- [ ] Tapa: índices AC/DC: ______
- [ ] Edición de Windows (Home/Pro): ______
- [ ] `wsl --version` responde: sí / no
- [ ] Nombre exacto de la distro: `<NOMBRE_DISTRO>` = ______
- [ ] `ps -p 1 -o comm=` devuelve: ______
- [ ] Docker: **Desktop** / **Engine nativo**
- [ ] cloudflared: SysV / systemd; ruta del config: ______
- [ ] Repo en `~/` o en `/mnt/c`: ______

---

## 3. Paso a paso: arranque automático

Ejecutar en este orden. Cada paso tiene su verificación; no pasar al siguiente si la verificación falla.

En todos los bloques, reemplazar:
- `<NOMBRE_DISTRO>` → el nombre exacto de `wsl -l -v` (típicamente `Ubuntu`)
- `<RUTA_COMPOSE>` → el directorio dentro de WSL donde está `compose.local.yml` (de 2.7)
- `<TUNNEL_ID>` → `3c395573-45f7-4313-8c8b-a37e924517e6`

---

### Paso 0 — [Sólo si 2.5 dio "Docker Desktop"] Migrar a Docker Engine

**Sin esto, ningún otro paso importa.** `[V]` Docker Desktop es una herramienta de desarrollo que requiere sesión interactiva; Docker Engine es un daemon Linux dentro de la distro que no la requiere.

Antes de descartar el daemon viejo, **verificar si hay adjuntos en el volumen local** `[C]`:

```bash
docker volume ls
docker run --rm -v financespy_app-storage:/data alpine du -sh /data
```

Migración (**bash dentro de WSL**):

```bash
# 1. En Windows: desactivar la integracion WSL de Docker Desktop y quitarlo del arranque
#    (Docker Desktop -> Settings -> Resources -> WSL Integration -> desactivar <NOMBRE_DISTRO>;
#     Settings -> General -> destildar "Start Docker Desktop when you log in")

# 2. Instalar Docker Engine oficial dentro de la distro
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. Permitir usar docker sin sudo
sudo usermod -aG docker $USER
```

Cerrar y reabrir la shell de WSL. **Verificación:**

```bash
docker context ls          # el contexto activo NO debe ser desktop-linux
docker info --format '{{.ServerVersion}}'
```

Re-levantar el stack (después del Paso 1, cuando systemd ya esté activo):

```bash
cd <RUTA_COMPOSE>
docker compose -f compose.local.yml --env-file .env.local up -d --build
```

---

### Paso 1 — Activar systemd en WSL

**Por qué systemd y no `[boot] command`** `[R]`: `[boot] command` ejecuta un solo comando, una sola vez, **sin supervisión**. Si `dockerd` se cae a las 3 AM, nadie lo levanta. Acá hay dos servicios (`dockerd` y `cloudflared`) que necesitan orden de arranque, reinicio automático y logs. systemd da las tres cosas.

**Bash dentro de WSL:**

```bash
sudo apt-get update -y && sudo apt-get install -y systemd systemd-sysv
sudo tee -a /etc/wsl.conf >/dev/null <<'EOF'

[boot]
systemd=true
EOF
cat /etc/wsl.conf
```

**PowerShell:**

```powershell
wsl --shutdown
Start-Sleep -Seconds 15
wsl -d <NOMBRE_DISTRO> -e true   # relanza la distro
```

> `[V]` **Regla de los 8 segundos:** los cambios en `wsl.conf` / `.wslconfig` sólo se aplican tras el apagado completo del subsistema. Siempre: editar → `wsl --shutdown` → esperar → relanzar.

**Verificación (bash):**

```bash
ps -p 1 -o comm=            # esperado: systemd
systemctl is-system-running # esperado: running  (degraded => revisar lo de abajo)
systemctl --failed
```

`[V]` Nota Windows 10: la doc marca la sección `[boot]` de `.wslconfig` como "sólo Windows 11", pero la página de systemd **no** menciona requisito de Windows 11 — sólo WSL ≥ 0.67.6 Store. En la práctica funciona en Win10 21H2+. `[C]` — si `ps -p 1` sigue diciendo `init`, esta guía no aplica tal cual y hay que replantear con `[boot] command`.

---

### Paso 2 — Habilitar Docker al boot de la distro

**Bash dentro de WSL:**

```bash
sudo systemctl enable --now docker.service containerd.service
```

**Verificación:**

```bash
systemctl is-enabled docker containerd   # esperado: enabled  enabled
systemctl is-active docker               # esperado: active
cd <RUTA_COMPOSE> && docker compose -f compose.local.yml ps   # los 4 servicios en Up
```

`[V]` En Debian/Ubuntu el paquete `docker-ce` ya deja `docker.service` habilitado, pero si se instaló **antes** de que la distro tuviera systemd, el enable pudo no aplicarse. Por eso se verifica explícitamente.

> `[V]` Ojo: `restart: unless-stopped` **no** reinicia contenedores que fueron detenidos a mano (`docker compose stop/down`). Si en algún momento se pararon manualmente, no vuelven solos aunque la política esté. Verificar siempre con `docker compose ps`.

---

### Paso 3 — Migrar cloudflared de SysV a systemd

**Orden importa.** `[V]` `cloudflared service uninstall` usa el **mismo switch de detección** que `install`: si primero activás systemd y después desinstalás, entra por la rama systemd y **deja huérfano** `/etc/init.d/cloudflared` — riesgo de dos instancias del mismo túnel en el mismo host.

> Como en el Paso 1 ya activamos systemd, hacé el 3.1 igual: limpia explícitamente lo de SysV sin depender de la autodetección.

**3.1 — Limpiar el servicio SysV (bash):**

```bash
sudo service cloudflared stop 2>/dev/null
sudo rm -f /etc/init.d/cloudflared
sudo rm -f /etc/rc[2345].d/S50et /etc/rc[016].d/K02et
ls -l /etc/init.d/cloudflared /etc/rc?.d/*et 2>/dev/null   # esperado: No such file
pgrep -af cloudflared                                       # esperado: nada
```

**3.2 — Dejar config y credenciales donde el servicio los espera (bash):**

`[V]` `cloudflared service install` **copia el `config.yml`** a `/etc/cloudflared/` pero **NO copia el JSON de credenciales**: la ruta de `credentials-file:` tiene que seguir siendo válida y legible por root (el servicio corre como root).

```bash
sudo install -d -m 0755 /etc/cloudflared
sudo install -m 0600 -o root -g root ~/.cloudflared/<TUNNEL_ID>.json /etc/cloudflared/<TUNNEL_ID>.json
sudo cp ~/.cloudflared/<NOMBRE_ACTUAL_DEL_CONFIG>.yml /etc/cloudflared/config.yml
sudo nano /etc/cloudflared/config.yml
```

Contenido objetivo de `/etc/cloudflared/config.yml`:

```yaml
tunnel: 3c395573-45f7-4313-8c8b-a37e924517e6
credentials-file: /etc/cloudflared/3c395573-45f7-4313-8c8b-a37e924517e6.json

no-autoupdate: true
loglevel: info
metrics: 127.0.0.1:20241

ingress:
  - hostname: finance.cd-co.com.py
    service: http://localhost:8080
  - service: http_status:404
```

Por qué cada línea `[V]`:
- `no-autoupdate: true` — el auto-update **reinicia el proceso** para actualizar. En producción, actualizar a mano.
- `metrics: 127.0.0.1:20241` — fija el puerto (por default toma el primer libre entre 20241–20245, o uno aleatorio). Sin puerto fijo no se puede monitorear `/ready` de forma confiable.
- `tunnel` + `credentials-file` son **obligatorios**: sin ambos, `service install` aborta.

**3.3 — Instalar como servicio systemd (bash):**

```bash
sudo cloudflared --config /etc/cloudflared/config.yml service install
```

`[V]` Esto genera `/etc/systemd/system/cloudflared.service` con `Type=notify`, `After=network-online.target`, `Restart=on-failure`, `RestartSec=5s`, y corre `systemctl enable`.

**3.4 — Cerrar el hueco de `Restart=on-failure`** `[R]`:

Con la plantilla de Cloudflare, si `cloudflared` sale con **código 0** (por ejemplo tras un SIGTERM limpio), systemd **no lo reinicia**.

```bash
sudo systemctl edit cloudflared
```

Pegar:

```ini
[Service]
Restart=always
RestartSec=5s
```

```bash
sudo systemctl daemon-reload && sudo systemctl restart cloudflared
```

**Verificación:**

```bash
systemctl is-enabled cloudflared    # esperado: enabled
systemctl is-active cloudflared     # esperado: active
curl -s http://127.0.0.1:20241/ready   # esperado: {"status":200,"readyConnections":4}
journalctl -u cloudflared -n 20 --no-pager
```

`[V]` `/ready` devuelve 200 **sólo si hay conexión activa con la red de Cloudflare** — es el mismo endpoint que Cloudflare usa como `livenessProbe` en su guía de Kubernetes. Es la señal local más confiable de que el túnel está arriba.

---

### Paso 4 — `.wslconfig`: que la distro no se apague sola y tenga RAM suficiente

**El bloqueante más subestimado** `[V]`: aunque systemd corra y `dockerd` esté activo, **WSL termina la instancia de la distro** a los ~15–20 segundos de cerrarse la última terminal (`microsoft/WSL#9968`, abierto desde 2023; confirmado en 2.4.13, 2.5.10 y 2.6.1 con contenedores `unless-stopped` corriendo).

`[V]` `vmIdleTimeout=-1` **no alcanza**: mantiene viva la VM, no la distro. La opción correcta es `general.instanceIdleTimeout`, introducida en **WSL 2.5.4** y **todavía sin documentar en learn.microsoft.com** (un ingeniero de WSL la indicó en `microsoft/WSL#13291`).

**En Windows**, editar `%UserProfile%\.wslconfig`:

```ini
[general]
instanceIdleTimeout=-1

[wsl2]
memory=5GB
swap=4GB
processors=4
vmIdleTimeout=-1
guiApplications=false
nestedVirtualization=false

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
```

Justificación `[V]` / `[R]`:
- **`memory=5GB`** `[R]` — el default es **50% de la RAM** = ~4 GB en esta notebook de 8 GB. `compose.local.yml` ya documenta ~3,1 GB entre los 4 servicios, dejando ~900 MB para kernel + dockerd + systemd + cloudflared. Muy justo, sobre todo con `web` en `mem_limit: 2g`.
- **`processors=4`** — ajustar al resultado de `NumberOfLogicalProcessors` de 2.3. Un i5 de 7ma suele ser 2c/4t.
- **`guiApplications=false`** `[R]` — apaga WSLg. Ahorra RAM y evita el bug de `msrdc` en Session 0 (`microsoft/WSL#41110`, afecta 2.7.11 y 2.9.x). En un servidor headless no perdés nada.
- **`vmIdleTimeout`** `[V]` es sólo Windows 11. En Win10 se ignora (inofensivo) y quedás dependiendo de `instanceIdleTimeout` + el `sleep infinity` del Paso 6.
- **`autoMemoryReclaim=gradual`** — el default `dropCache` tira el page cache de golpe. Es experimental.

**Aplicar (PowerShell):**

```powershell
wsl --shutdown
Start-Sleep -Seconds 15
wsl -d <NOMBRE_DISTRO> -e true
```

**Verificación (bash):**

```bash
free -h | head -2      # el total debe reflejar ~5GB
nproc
```

`[V]` WSL 2.7+ avisa sobre claves desconocidas en `.wslconfig` al siguiente `wsl -l -v`, así que un typo se detecta solo.

---

### Paso 5 — Energía de Windows: nunca dormir, nunca hibernar, apagado limpio por batería

**PowerShell como Administrador.** Todo por comando y no por UI, para que quede asentado con qué valores quedó.

```powershell
# --- Nunca suspender, nunca hibernar, nunca apagar disco (AC y bateria) ---
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0
powercfg /change disk-timeout-ac 0
powercfg /change disk-timeout-dc 0

# La pantalla SI puede apagarse: no afecta contenedores ni AnyDesk, y baja consumo/temperatura
powercfg /change monitor-timeout-ac 10
powercfg /change monitor-timeout-dc 5

# --- Desactivar hibernacion por completo ---
powercfg /hibernate off

# --- Tapa: no hacer nada. Boton de encendido: apagar (nunca suspender) ---
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS PBUTTONACTION 3
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION 0

# --- Bateria: aguantar lo maximo y, cuando ya no da, APAGAR LIMPIO ---
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BATTERY BATACTIONLOW 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BATTERY BATACTIONCRITICAL 3
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BATTERY BATLEVELCRITICAL 5
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BATTERY BATLEVELLOW 10

# --- Red: que no se suspenda el bus USB, el link PCIe ni la radio WiFi ---
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setdcvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0
powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0

# --- Aplicar al esquema activo (sin esto varios /setXvalueindex no toman efecto) ---
powercfg /setactive SCHEME_CURRENT
```

Por qué `powercfg /hibernate off` `[V]` / `[R]`:
1. Apaga también **Fast Startup**, que hace que el arranque desde apagado **no sea un boot real** — hay múltiples reportes de que con Fast Startup activo las tareas con trigger *Al iniciar el sistema* **no se disparan**. (Reportado y ampliamente observado, no documentado por MS — lo confirma o descarta la Prueba C de la sección 4.)
2. Evita el bug `microsoft/WSL#12747`: *"WSL2 loses networking after resume from hibernate"* (abierto). Es exactamente el síntoma Error 1033 con todo aparentemente "Up".
3. Libera el `hiberfil.sys` (~3 GB).

**Contrapartida honesta:** desactiva también la hibernación por batería crítica. Por eso arriba se pone `BATACTIONCRITICAL = 3` (apagar) al 5% — un apagado limpio es mucho mejor que un corte duro para la integridad del `ext4.vhdx`.

**Extra** `[R]` — sacar Suspender/Hibernar del menú de inicio, para que un clic mal dado por AnyDesk no tumbe el servidor:

```powershell
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowSleepOption /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowHibernateOption /t REG_DWORD /d 0 /f
```

**Verificación (y dejarla asentada):**

```powershell
powercfg /query SCHEME_CURRENT SUB_BUTTONS   # LIDACTION: AC y DC deben ser 0x00000000
powercfg /query SCHEME_CURRENT SUB_SLEEP
powercfg /query SCHEME_CURRENT SUB_BATTERY
powercfg /a                                   # hibernacion NO debe estar disponible
powercfg /query SCHEME_CURRENT > "$env:USERPROFILE\Desktop\powercfg-actual.txt"
```

Mapeo de LIDACTION `[V]`: `0` = No hacer nada · `1` = Suspender · `2` = Hibernar · `3` = Apagar. **Ambos** índices (AC y DC) tienen que ser `0x00000000`: con la tapa cerrada y en batería —justo el escenario de un corte— el que manda es el DC.

---

### Paso 6 — Tarea Programada: arrancar WSL al boot y mantenerla viva

Esta es **la única vía nativa** para que WSL arranque sin login. `[V]`

**Dos trampas de identidad, críticas:**
1. `[V]` Las distros de WSL están registradas **por usuario de Windows** (`HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss`). Una tarea corriendo como **`SYSTEM` no encuentra la distro**. Lo mismo aplica a servicios envueltos con NSSM/WinSW como LocalSystem. La tarea **debe correr como el usuario dueño de la distro**.
2. El trigger tiene que ser **"Al iniciar el sistema" + "Ejecutar tanto si el usuario inició sesión como si no"**, nunca "Al iniciar sesión": el escenario a eliminar es justamente "la notebook se reinicia de madrugada y nadie se loguea".

`[V]` Session 0 funciona hoy: hubo un período en 2022 (`microsoft/WSL#8835`) en que la versión Store no arrancaba desde Session 0, pero el issue `#41110` (2026-07-17) reproduce WSL corriendo en Session 0 y lo único que falla es **WSLg** — que ya apagamos en el Paso 4.

**PowerShell como Administrador:**

```powershell
$distro = '<NOMBRE_DISTRO>'
$task   = 'WSL-Autostart-FinancePY'

$action = New-ScheduledTaskAction `
  -Execute 'C:\Windows\System32\wsl.exe' `
  -Argument "-d $distro -u root --exec /usr/bin/sleep infinity"

# Tres disparadores: boot, logon (por si Fast Startup se come el de boot)
# y repeticion cada 5 min como watchdog (si el proceso muere, vuelve).
$tBoot  = New-ScheduledTaskTrigger -AtStartup
$tBoot.Delay = 'PT30S'
$tLogon = New-ScheduledTaskTrigger -AtLogOn
$tRep   = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
            -RepetitionInterval (New-TimeSpan -Minutes 5)

$settings = New-ScheduledTaskSettingsSet `
  -MultipleInstances IgnoreNew `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -DontStopOnIdleEnd `
  -StartWhenAvailable `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -RestartInterval (New-TimeSpan -Minutes 1) -RestartCount 10

# S4U = "Ejecutar aunque el usuario no haya iniciado sesion" SIN guardar contrasena
$principal = New-ScheduledTaskPrincipal `
  -UserId "$env:USERDOMAIN\$env:USERNAME" `
  -LogonType S4U -RunLevel Highest

Register-ScheduledTask -TaskName $task -Action $action `
  -Trigger @($tBoot,$tLogon,$tRep) -Settings $settings -Principal $principal -Force
```

**Los flags de `$settings` son la parte que casi todos omiten y es la que rompe justo en una notebook** `[V]`:
- Por default toda tarea nueva viene con **"Iniciar sólo si está conectado a la corriente alterna" activado** y **"Detener si cambia a batería" activado**. En un corte de luz eso significa: **la tarea no arranca, y si estaba corriendo la matan.** → `-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries`.
- Por default: **"Detener la tarea si se ejecuta durante más de 3 días"**. Con `sleep infinity`, al tercer día Windows la mata y WSL se apaga. → `-ExecutionTimeLimit ([TimeSpan]::Zero)`.

**Por qué `sleep infinity`:** ese proceso cumple **dos funciones a la vez** `[R]` — dispara el arranque de la distro al boot **y** la mantiene viva. Es el cinturón que complementa a los tiradores (`instanceIdleTimeout=-1` del Paso 4): uno depende de una opción no documentada, el otro de que el proceso siga vivo. Que fallen los dos a la vez es mucho menos probable.

**Si S4U falla** (la tarea arranca pero `wsl.exe` da error): registrarla **desde la UI de Task Scheduler** con "Almacenar contraseña", donde Windows la pide en su propio diálogo. **No pongas la contraseña en un script ni la pegues en ningún chat.**

**Verificación previa (comprobar la trampa de identidad):**

```powershell
# Confirmar que /usr/bin/sleep existe en la distro
wsl -d <NOMBRE_DISTRO> -e sh -c 'command -v sleep'   # esperado: /usr/bin/sleep
```

**Habilitar el log del Programador de tareas antes de probar** `[V]` — está **deshabilitado por defecto**: Visor de eventos → Registros de aplicaciones y servicios → Microsoft → Windows → TaskScheduler → Operational → botón derecho → **Habilitar registro**.

---

### Paso 7 — Windows Update: acotar los reinicios sorpresa

`[R]` No hay que bloquear updates (la máquina está expuesta a internet vía túnel, dejarla sin parchear es peor riesgo). El arreglo real es que el stack sobreviva un reinicio no anunciado — que es todo lo anterior. Esto sólo baja la probabilidad de que pase en horario ciego.

**PowerShell como Administrador:**

```powershell
$k = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
New-Item -Path $k -Force | Out-Null
Set-ItemProperty $k -Name SmartActiveHoursState -Type DWord -Value 0
Set-ItemProperty $k -Name ActiveHoursStart -Type DWord -Value 6
Set-ItemProperty $k -Name ActiveHoursEnd   -Type DWord -Value 23
Set-ItemProperty $k -Name IsExpedited -Type DWord -Value 0
```

(El rango máximo de horas activas permitido es de 18 h.)

**Sólo si la edición es Pro/Enterprise** (de 2.3 — **Windows Home ignora estas políticas**, es una limitación real):

```powershell
$p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
New-Item -Path $p -Force | Out-Null
Set-ItemProperty $p -Name NoAutoUpdate -Type DWord -Value 0
Set-ItemProperty $p -Name AUOptions -Type DWord -Value 3
Set-ItemProperty $p -Name NoAutoRebootWithLoggedOnUsers -Type DWord -Value 1
gpupdate /force
```

**Verificación:**

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" |
  Select-Object ActiveHoursStart, ActiveHoursEnd, SmartActiveHoursState
```

---

### Paso 8 — Backup del `ext4.vhdx`

`[V]` En `microsoft/WSL#40638` un usuario terminó con **corrupción de filesystem ext4** en el VHD de la distro tras un apagado inesperado; la recuperación exige montar el `ext4.vhdx` desde otra distro y correr `e2fsck`. La base está en Supabase, así que esto no protege datos de negocio — protege **la máquina de compute**, o sea el tiempo de recuperación.

```powershell
# Ubicar el VHD
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss |
  ForEach-Object { Get-ItemProperty $_.PSPath } |
  Where-Object { $_.DistributionName -and $_.BasePath } |
  Select-Object DistributionName, @{N='Vhd';E={Join-Path ($_.BasePath -replace '^\\\\\?\\','') 'ext4.vhdx'}}

# Backup (repetir periodicamente; ajustar la ruta de destino)
wsl --shutdown
wsl --export <NOMBRE_DISTRO> "D:\backup\wsl-<NOMBRE_DISTRO>-$(Get-Date -Format yyyyMMdd).tar"
```

`[R]` Regla operativa: **`wsl --shutdown` antes de todo apagado planificado.**

---

## 4. Prueba de fuego

Configurar no es lo mismo que funcionar. **Ninguna prueba vale si te logueás en Windows durante la prueba.** Correr en orden, anotando el tiempo hasta que el servicio responde — ese número es el **RTO real** del setup.

### Test 0 — La tarea funciona (sin reiniciar Windows)

```powershell
wsl --shutdown
Start-Sleep -Seconds 15
wsl -l -v                                    # todas deben decir Stopped
Start-ScheduledTask -TaskName 'WSL-Autostart-FinancePY'
Start-Sleep -Seconds 90
wsl -l -v                                    # la distro debe decir Running
Get-ScheduledTaskInfo -TaskName 'WSL-Autostart-FinancePY' |
  Select-Object LastRunTime, LastTaskResult, NumberOfMissedRuns
# LastTaskResult 267009 = "corriendo ahora" -> correcto para una tarea de larga duracion
wsl -d <NOMBRE_DISTRO> -e docker compose -f <RUTA_COMPOSE>/compose.local.yml ps
(Invoke-WebRequest http://localhost:8080 -UseBasicParsing).StatusCode   # esperado 200/30x
```

### Test 1 — Inactividad (no se apaga sola)

Después del Test 0: **cerrar todas las terminales de WSL** y no tocar nada 15 minutos.

```powershell
wsl -l -v          # debe seguir Running
(Invoke-WebRequest http://localhost:8080 -UseBasicParsing).StatusCode
```

Si acá pasa a `Stopped` → falló la combinación `instanceIdleTimeout` + `sleep infinity` del Paso 4/6. Revisar la versión de WSL (≥ 2.5.4).

### Test 2 — Crash de cloudflared (reconexión)

**Bash dentro de WSL:**

```bash
sudo pkill -9 -f 'cloudflared tunnel'      # -9 a proposito: simula crash
sleep 15 && systemctl is-active cloudflared    # esperado: active
journalctl -u cloudflared -n 30 --no-pager
curl -s http://127.0.0.1:20241/ready
```

`[V]` Con `pkill` **sin** `-9` (SIGTERM) `cloudflared` sale con código 0 y `Restart=on-failure` **no lo reinicia**. Ese es el hueco que cierra el drop-in `Restart=always` del Paso 3.4. Vale probar ambos para ver la diferencia.

### Test 3 — Pérdida de red

```bash
journalctl -u cloudflared -f     # dejar corriendo
```

Apagar el router / desconectar el WiFi de Windows **3 a 5 minutos** y volver a conectar. Esperado en el log: `Unregistered tunnel connection` → reintentos → `Registered tunnel connection`. **Cronometrar desde que vuelve la red hasta el primer `Registered`**: hasta ~5 min es normal por el backoff `[V]`. Si tarda más, bajar `retries` a `3` en el config (peor caso: 10 s × 2³ = 80 s) — **subirlo no ayuda, agranda la ventana de espera**.

### Test 4 — Reinicio (`Restart` siempre hace boot completo)

```powershell
shutdown /r /t 0
```

**No iniciar sesión.** Esperar 5 minutos. Desde el **celular con datos móviles** (no el WiFi de casa) abrir `https://finance.cd-co.com.py`. Si carga sin haberte logueado → la parte de arranque está resuelta para el caso "Windows Update reinició".

### Test 5 — Apagado completo ⚠️ el que la mayoría se saltea

```powershell
shutdown /s /t 0
```

Prender con el botón. **No iniciar sesión.** Esperar 5 minutos. Probar de nuevo desde el celular.

**Este es el test que más se parece a lo que pasó hoy.** Si el Test 4 pasa y el Test 5 falla, el culpable es Fast Startup — verificar que `powercfg /a` ya no liste hibernación (Paso 5).

### Test 6 — Corte de AC real

Con la notebook encendida y desatendida, **desenchufar el cargador**. Dejarla 20–30 min con la tapa cerrada y verificar desde la Mac:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://finance.cd-co.com.py/up
```

- Si se apaga al instante al desenchufar → **batería muerta, confirmado empíricamente**.
- Si aguanta pero el sitio igual se cae → el problema fue el **router/ONU**, no la notebook (ver sección 9).

### Diagnóstico si algo falla

```powershell
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 40 |
  Where-Object { $_.Message -like '*WSL-Autostart*' } | Format-List TimeCreated, Id, Message
query session      # confirma que NO hay sesion interactiva abierta
wsl -l --running
```

Y dentro de WSL: `systemctl --failed`, `systemctl status docker cloudflared`, `docker compose -f compose.local.yml ps`.

**Regla: no declarar resuelto hasta que el Test 5 pase.**

### Registro de tiempos (completar)

| Test | Fecha | Resultado | Tiempo hasta 200 |
|---|---|---|---|
| 0 — tarea | | | |
| 1 — inactividad 15 min | | | |
| 2 — crash cloudflared | | | |
| 3 — pérdida de red | | | |
| 4 — reinicio | | | |
| 5 — apagado completo | | | |
| 6 — corte de AC | | | |

---

## 5. Monitoreo — enterarte antes que el usuario

Tres capas, todas gratis. Con las tres, el escenario "un usuario me avisa" desaparece.

### Capa A — Cloudflare Notifications (cero infraestructura)

Dashboard → **Notifications** → Add → producto **Cloudflare Tunnel** → **Tunnel Health Alert**. `[V]` Disponible en *"all Cloudflare Zero Trust plans"*.

Estados del túnel `[V]`: `Healthy` (4 conexiones) · `Degraded` (corriendo con al menos una conexión caída — **señal temprana**) · `Down` (estaba conectado y el proceso paró) · `Inactive` (nunca conectó).

`[V]` **Caveat:** el destino **webhook** de Notifications requiere plan **Pro o superior** en al menos una zona. En Free tenés **email**, que alcanza. `[C]` — confirmar en qué plan está `cd-co.com.py`.

### Capa B — Chequeo externo desde la VM GCP + Telegram `[R]`

La mejor opción acá: ya hay VM encendida, bot Hermes y n8n. Rails expone `/up` de fábrica `[V]` (`config/routes.rb:606` → `rails/health#show`).

`/opt/scripts/check_financespy.sh` en la VM (chmod 700, root):

```bash
#!/usr/bin/env bash
set -uo pipefail
source /etc/financespy-monitor.env   # define TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID (chmod 600)

URL="https://finance.cd-co.com.py/up"
STATE="/var/tmp/financespy_health.state"
CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$URL" || echo 000)
PREV=$(cat "$STATE" 2>/dev/null || echo OK)

notify() {
  curl -sS --max-time 15 -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode chat_id="${TELEGRAM_CHAT_ID}" \
    --data-urlencode text="$1" >/dev/null
}

if [ "$CODE" = "200" ]; then
  [ "$PREV" != "OK" ] && notify "FinancePY RECUPERADO (HTTP 200)"
  echo OK > "$STATE"
else
  [ "$PREV" = "OK" ] && notify "FinancePY CAIDO - HTTP ${CODE} en ${URL}"
  echo FAIL > "$STATE"
fi
```

```cron
*/2 * * * * /opt/scripts/check_financespy.sh
```

- El token va en un archivo con `chmod 600`, **nunca inline en el cron ni en el script**.
- El patrón con `STATE` evita spam: avisa sólo en la transición.
- `[R]` Para saber **qué origen** respondió el día que haya standby, agregar `X-Origin "notebook"` en el bloque `header { }` del `Caddyfile.local` (y `"vm"` en el de la VM). Después: `curl -sI https://finance.cd-co.com.py/up | grep -i x-origin`.

### Capa C — Dead-man's switch (detecta corte total de luz/internet)

Las capas A y B fallan en un escenario: si la casa entera está sin luz **y** el que chequea es un servicio externo, te enterás igual — pero si querés distinguir "la app murió" de "la casa murió", hace falta un heartbeat inverso. La notebook pinga cada 5 min; si **deja** de pingar, el servicio alerta.

Cron **en la notebook (dentro de WSL)**, condicionado a que el túnel esté realmente sano:

```bash
*/5 * * * * curl -sf --max-time 5 http://127.0.0.1:20241/ready >/dev/null && curl -fsS -m 10 https://hc-ping.com/<UUID-DEL-CHECK> >/dev/null
```

`[R]` Proveedor recomendado: **Healthchecks.io** — está hecho exactamente para esto. Tier gratuito y límites **a confirmar en https://healthchecks.io/pricing/** (cambian seguido).

> `[V]` **UptimeRobot: no usarlo.** Desde fines de 2024 su ToS prohíbe uso comercial. Sirve hoy en fase de prueba, pero vas a tener que migrarlo cuando FinancePY sea comercial — mejor no atarse.

### Capa D — Chequeo local, para debugging

```bash
curl -s http://127.0.0.1:20241/ready        # {"status":200,"readyConnections":4}
curl -s http://127.0.0.1:20241/metrics | grep -E 'cloudflared_tunnel_ha_connections|cloudflared_tunnel_timer_retries'
```

`cloudflared_tunnel_ha_connections` debería ser **4**.

---

## 6. Fallback

Dos capas independientes. La A es lo que ve el usuario cuando el servicio está caído; la B es tener un segundo origen.

### 6.1 Capa A — Offline en el cliente (PWA)

Alcance real, honesto `[V]` — es **mucho más chico** de lo que "PWA offline" sugiere:

**Funciona sin red:**
- **Crear una venta nueva** — único flujo con cola offline real (`offline_sale_form_controller.js` → IndexedDB + Background Sync). Salvedad: el controller se engancha **sólo si `sale.new_record?`** (`app/views/sales/_form.html.erb:3`). **Editar una venta existente no tiene soporte offline.**
- **Ver pantallas ya visitadas**, y sólo esas URLs exactas (`/transactions?page=2` es una entrada de caché distinta de `/transactions`).
- Ver la cola de pendientes.

**NO funciona sin red:** transacciones, cuentas, presupuestos, holdings, imports, chat IA, reportes. Nada tiene persistencia offline; los datos viven en Supabase. Dispositivo nuevo o caché limpia → `offline.html` y nada más.

`[V]` **Background Sync es sólo Chromium** (Chrome/Edge/Android). En Safari/iOS y Firefox el fallback es el evento `online`, que sólo dispara **si la app está abierta**. Un usuario de iPhone que carga una venta offline y cierra la app deja la venta dormida en IndexedDB.

**Los 6 arreglos pendientes, por prioridad** (todos en `/Users/Fabrizio/code/financespy`):

| # | Ítem | Severidad | Esfuerzo |
|---|---|---|---|
| 1 | **El replay borra ventas si la sesión no verifica.** `authenticate_user!` (`app/controllers/concerns/authentication.rb:18-27`) **siempre redirige**, sin rama JSON. Cadena: sesión expirada → `POST /sales` devuelve 302 → `fetch` sigue el redirect → 200 con el HTML del login → `response.ok === true` → `deletePendingSaleRecord()` **borra la venta que nunca se guardó**. Sin error, sin rastro. | **Alta — pérdida de datos** | ~30 min |
| 2 | **El SW no cubre las navegaciones de Turbo.** `isOriginUnreachable()` vive sólo dentro de la rama `request.mode === 'navigate'` (`app/views/pwa/service-worker.js:82`), pero FinancePY es app Turbo: después de la primera carga los clicks son `fetch` con `mode: 'cors'`. El usuario ve el **"Error 1033" de Cloudflare pintado adentro de la app**. | **Alta** | ~20 min |
| 3 | `public/offline.html`: dice **`<title>Offline - Sure</title>`** (línea 7) — nunca debe mostrar la marca del upstream, debe decir FinancePY; está en inglés con usuarios paraguayos; culpa al usuario ("chequeá *tu* conexión") cuando el caído es el servidor; no menciona la cola de pendientes; y su auto-recovery escucha el evento `online` del browser, que **nunca dispara** cuando la notebook está caída y el internet del usuario anda bien. Reemplazar por **poll a `/up` cada 15 s**. | Media | ~1 h |
| 4 | `RUNTIME_CACHE = 'runtime-v1'` está hardcodeado y **excluido del borrado** en `activate`. Cachea HTML **autenticado** de una app financiera indefinidamente y **no se limpia en el logout** — y `compose.local.yml` documenta que es una **PC compartida**. Versionar junto a `CACHE_VERSION` y purgar en logout. | Media-alta | ~1 h |
| 5 | `cache.put` se llama también para POST (submits no-Turbo) → la Cache API lanza `TypeError` en una promesa sin `.catch()`. Guardar con `event.request.method === 'GET'`. | Baja | 5 min |
| 6 | `Caddyfile.local`: el matcher `@sw path /service-worker.js` **nunca matchea** — la ruta real es `/service-worker` sin `.js`. Config muerta (impacto bajo: Rails ya manda `must-revalidate`). Corregir a `path /service-worker /service-worker.js`. | Baja | 2 min |

**Los ítems 1 y 2 son los que convierten esto de "PWA decorativa" a "el usuario no ve una pantalla de error". Juntos suman menos de una hora.**

`[V]` **Advertencia de alcance:** el browser sólo actualiza el service worker cuando logra descargar `/service-worker`. Si el origen está caído, esa descarga falla. **Estos arreglos no ayudan durante la caída actual — ayudan a partir de la próxima**, y sólo para clientes que hayan cargado la app con éxito al menos una vez después del deploy.

### 6.2 Capa B — Failover de infraestructura

**Los tres bloqueantes** — hay que resolverlos ANTES de cualquier arquitectura multi-origen `[V]`:

| # | Bloqueante | Qué rompe |
|---|---|---|
| 1 | **`SECRET_KEY_BASE` distinto** entre notebook y VM. `authentication.rb:31` usa `cookies.signed[:session_token]`; Rails firma con `SECRET_KEY_BASE`. | Deslogueos intermitentes **y**, por el bug 6.1-#1, **borrado silencioso de ventas encoladas**. Ver sección 7. |
| 2 | **Active Storage en disco local.** `production.rb:39` → `ENV.fetch("ACTIVE_STORAGE_SERVICE", "local")`, y `compose.local.yml` **no define esa variable** → servicio `Disk` en el volumen `app-storage`. | Los adjuntos subidos a la notebook (fotos de comprobantes) **no existen en la VM** → 404 que parece corrupción de datos. **La solución ya está preconfigurada**: `config/storage.yml` tiene un servicio `cloudflare` (R2) completo. Setear `ACTIVE_STORAGE_SERVICE=cloudflare` + las 4 vars de R2. |
| 3 | **Idempotencia de ventas en Redis por-máquina.** `sales_controller.rb:27-45` deduplica por `client_request_id` con `Rails.cache` = Redis (`production.rb:78`), y **cada compose corre su propio Redis**. | La venta se crea en la notebook, la clave queda en su Redis; el reintento cae en la VM → **venta duplicada**. En facturación eso es un problema contable. Arreglo: mover a una columna `client_request_id` con **índice único** en Supabase — el único estado ya compartido. |

`[V]` Agravante: la imagen es `redis:latest` con volumen pero **sin `appendonly`**. Con los defaults RDB, un corte sin apagado limpio puede perder hasta **~60 s de escrituras** — no sólo idempotencia, también **la cola de jobs de Sidekiq**. `[C]` — el corte de hoy pudo llevarse jobs encolados.

**Además: doble Sidekiq.** `[V]` `config/schedule.yml` define cron jobs, entre ellos `InactiveFamilyCleanerJob` (*"Archives and destroys families that expired their trial"*, diario 04:00) y `DataCleanerJob` (diario 03:00). Dos stacks = **dos schedulers independientes ejecutando jobs destructivos contra la misma base de Supabase**. Mitigación si algún día hay dos orígenes vivos: en el standby correr sólo `web` + `caddy` con el worker apagado (`--scale worker=0`).

**Las cuatro opciones:**

| Opción | Costo | Veredicto |
|---|---|---|
| **(a) Réplicas del mismo túnel** — mismo UUID en varios hosts, hasta 25 réplicas / 100 conexiones `[V]` | **$0** | `[V]` *"Replicas do not support traffic steering… forwarded to the geographically closest replica… no guarantee about which one is chosen."* **No hay modo activo/pasivo real.** La notebook (Paraguay) se llevaría casi todo por proximidad, pero "casi todo" no es "todo": cada request desviado a la VM = un deslogueo, un 404 o una venta duplicada. **Viable sólo con los 3 bloqueantes resueltos.** |
| **(b) Cloudflare Load Balancer** — health check HTTPS sobre `/up`, primario + fallback con prioridad | *"Starting at $5/mo"* según cloudflare.com/plans `[V]`. El desglose por origen adicional **a confirmar en el dashboard de la cuenta** | Única opción con failover **determinístico**: el standby no recibe nada mientras el primario esté sano, lo que convierte los 3 bloqueantes de "problema permanente" a "problema sólo durante el failover". `[V]` **Excluyente con (a)**: *"A single origin pool cannot reference the same tunnel UUID twice"* → cada máquina necesita **su propio túnel**. |
| **(c) Standby en Railway** | `[V]` Hobby $5/mes incluye $5 de uso; RAM $10/GB/mes, CPU $20/vCPU/mes, egreso $0.05/GB (docs.railway.com/pricing/plans). `[R]` **Estimación mía**, no cifra oficial: ~$14–17/mes always-on (web ~1 GB + Redis) | **Trampa importante** `[R]`: *"standby dormido"* y *"LB con health checks"* son **incompatibles** — cada health check despierta el servicio, así que nunca duerme y pagás always-on igual. Elegí: always-on + LB (~$20/mes total) **o** dormido sin failover automático (~$5–7/mes, con cold boot). `[C]` el cold boot real de esta imagen hay que **medirlo**, no asumirlo. |
| **(d) Volver a cloud con SLA** | `[C]` costo actual de `alejandro-vm` a confirmar en la consola de GCP | Destino final. `[V]` Nota: **Cloudflare no da SLA de uptime en Free ni Pro** — recién desde Business ($200/mes anual, $250 mensual). Pero lo relevante es el SLA del **origen**, no el de Cloudflare. |

### 6.3 Recomendación para AHORA (fase de prueba)

**No montar failover multi-origen todavía.** Fundamento, no pereza: con los tres bloqueantes sin resolver, un failover a medias **corrompe datos en silencio** (deslogueos, ventas duplicadas, adjuntos 404, ventas encoladas borradas). En fase de prueba, el costo de una caída de horas es bajo; el costo de datos corruptos que descubrís tres semanas después es alto.

Y sobre todo: **el incidente de hoy no fue un problema de failover, fue de arranque.** Un segundo origen no habría hecho falta si el primero se levantaba solo.

Orden de trabajo:

| # | Acción | Costo | Resuelve |
|---|---|---|---|
| 1 | **Sección 3 completa** (arranque automático) + Test 5 en verde | $0 | La causa real del incidente de hoy |
| 2 | **Capa A ítems 1 y 2** | $0, <1 h | No perder ventas; que el usuario no vea el Error 1033 de Cloudflare |
| 3 | **Alinear `SECRET_KEY_BASE`** (sección 7) | $0, 15 min | Prerequisito de todo failover futuro — hacerlo ya, aunque no haya failover |
| 4 | **Monitoreo Capas A + B** (sección 5) | $0 | Enterarte antes que los usuarios |
| 5 | **Capa A ítems 3 y 4** | $0, ~2 h | UX honesta + cerrar la fuga de privacidad en PC compartida |
| 6 | **Active Storage → R2** | $0 (tier free R2: 10 GB, **a confirmar en https://developers.cloudflare.com/r2/pricing/**) | Prerequisito de failover; además saca archivos del disco de una notebook |
| 7 | **Idempotencia → columna única en Supabase** | $0 | Prerequisito de failover; además sobrevive cortes de luz |
| 8 | **VM como failover MANUAL documentado** mientras siga prendida | $0 marginal | Red de seguridad con RTO ~5 min, **sin riesgo de doble-origen** |

**Costo total: $0/mes.**

El punto 8 es la respuesta honesta a "quiero una red de seguridad ya": un **runbook** que movés a mano cuando decidís que la caída va para largo. `[R]` En la VM, dejar preparado `/etc/cloudflared/financespy-standby.yml` (mismo tunnel ID, ingress al Caddy local de la VM en `:80`) con `cloudflared` **instalado pero deshabilitado**, y levantarlo con un comando. No es automático, pero **no puede corromper nada**, porque nunca hay dos orígenes sirviendo a la vez.

> ⚠️ Si vas a apagar la VM, apagala **después** de completar los puntos 3, 6 y 7 — necesitás leer el `SECRET_KEY_BASE` original de ahí, y es el origen de referencia. Ver también [[Migración hosting FinancePY — análisis Cloudflare vs alternativas]].

### 6.4 Recomendación para cuando sea COMERCIAL

Premisa del usuario: *"cuando sea público el usuario no debe pasar por ello"*. Eso descarta la notebook como origen de producción — no por el software, sino porque **el SLA de una notebook en una casa es la luz y el internet de esa casa**.

1. **Origen primario en cloud con SLA** (Railway Pro / Hetzner / GCP). La notebook sale de producción y queda como entorno de desarrollo, que es para lo que sirve.
2. **Estado 100% compartido y externo**, como precondición de arquitectura y no como parche: `SECRET_KEY_BASE` gestionado como secreto (no un `.env` copiado a mano) · Active Storage en **R2** · idempotencia en Supabase con índice único · Redis con **persistencia AOF** para no perder jobs de Sidekiq.
3. **Cloudflare Load Balancer** con **dos túneles separados** (no réplicas del mismo UUID), health check HTTPS sobre `/up`, primario + fallback con prioridad.
4. **Segundo origen always-on** en otra región/proveedor.
5. Alertas (Sentry ya está integrado — `authentication.rb:56` lo referencia) + página de status pública.

**Costo estimado del par LB + standby: ~$20–25/mes**, más el origen primario. `[R]` estimación, con las cifras de la tabla de 6.2 — confirmar en los dashboards antes de comprometerse.

**Regla de decisión:** el LB de $5 recién vale la pena cuando el estado compartido esté resuelto. Antes de eso, ese dinero compra failover que corrompe datos.

---

## 7. Prerequisito del failover: alinear `SECRET_KEY_BASE`

**Por qué** `[V]`: `app/controllers/concerns/authentication.rb:31` usa `cookies.signed[:session_token]`. Rails firma esa cookie con `SECRET_KEY_BASE` (inyectado en `compose.local.yml:19`). Si el origen A firma y el origen B no puede verificar, `find_session_by_cookie` devuelve `nil` → redirect al login.

**Y no es sólo un deslogueo.** Encadenado con el bug 6.1-#1: cookie no verificable → `POST /sales` devuelve 302 → el replay recibe 200 con el HTML del login → `response.ok` → **borra la venta encolada**. El `SECRET_KEY_BASE` desalineado **destruye datos**.

**Hacerlo ahora aunque no haya failover todavía**, y mientras la VM siga encendida (después no vas a poder leer el valor original).

**Regla: el valor nunca se imprime en pantalla, ni se pega en un chat, email o nota.**

```bash
# 1. En la VM GCP: extraer la linea a un archivo, NO a stdout
ssh alejandro-vm
grep '^SECRET_KEY_BASE=' /ruta/al/.env > /tmp/skb.env
wc -l /tmp/skb.env        # esperado: 1  (verifica que salio, sin mostrar el valor)
exit

# 2. Transferir por canal cifrado
scp alejandro-vm:/tmp/skb.env ./skb.env

# 3. En la notebook (WSL): reemplazar SOLO la linea SECRET_KEY_BASE de .env.local
#    por la de skb.env, dejando el resto del archivo intacto.
#    Hacerlo con un editor (nano/vim), no con un one-liner que pueda romper el archivo.

# 4. Borrar las copias temporales en ambos lados
ssh alejandro-vm 'shred -u /tmp/skb.env'
shred -u ./skb.env

# 5. Recrear los contenedores para que tomen el env nuevo
cd <RUTA_COMPOSE>
docker compose -f compose.local.yml --env-file .env.local up -d --force-recreate web worker
```

**Verificación sin imprimir el valor** — correr en cada máquina y comparar los hashes:

```bash
grep '^SECRET_KEY_BASE=' .env.local | sha256sum
```

Deben dar **exactamente el mismo hash**.

**Efecto secundario esperado y aceptable:** al cambiar el `SECRET_KEY_BASE` de la notebook, **todas las sesiones firmadas con el valor viejo se invalidan** → todos los usuarios se desloguean una vez. Hacerlo en horario de bajo uso y avisar. Es un evento único a cambio de eliminar los deslogueos intermitentes para siempre.

**Además** `[R]`: mismo commit en ambos orígenes, siempre. Si difieren, los digests de assets de Propshaft difieren y un HTML servido por un origen pide un `/assets/foo-<digest>.js` que el otro no tiene → 404 de assets y service worker desincronizado.

---

## 8. Comandos pendientes de correr en la notebook

No se pueden responder desde la Mac. **No asumir ninguno.**

```bash
# 1. Archivos ya en disco local que habria que migrar a R2
docker compose -f compose.local.yml exec web sh -c 'du -sh /rails/storage; find /rails/storage -type f | wc -l'

# 2. Confirmar que Active Storage esta en 'local' (esperado: local)
docker compose -f compose.local.yml exec web sh -c 'echo ${ACTIVE_STORAGE_SERVICE:-local}'

# 3. Redis perdio datos en el corte? Jobs de Sidekiq encolados y ultima persistencia
docker compose -f compose.local.yml exec redis redis-cli info persistence | grep -E 'rdb_last_save_time|aof_enabled'
docker compose -f compose.local.yml exec redis redis-cli -n 0 llen queue:default

# 4. Region real de la VM GCP (afecta el analisis de proximidad de replicas)
gcloud compute instances list --filter="name=alejandro-vm" --format="value(name,zone,status)"

# 5. Cuantas replicas del tunel estan corriendo ahora mismo
cloudflared tunnel info <NOMBRE_DEL_TUNEL>
```

Y en el browser, para confirmar el hueco de Turbo (6.1-#2), 2 minutos: abrir la app → navegar 2-3 pantallas → parar el stack (`docker compose -f compose.local.yml down`) → sin recargar, click en un link del menú. **Si aparece la pantalla de Cloudflare, el hueco está confirmado.**

---

## 9. Límites honestos — lo que esto NO resuelve

**1. Una notebook no se enciende sola después de un apagón total.** `[V]` No existe configuración de Windows que arranque una máquina sin corriente. La opción de BIOS que hace eso ("Restore on AC Power Loss") es estándar en **escritorios**, y en notebooks **normalmente no existe**: el fabricante asume que la batería es el buffer, así que "pérdida de AC" no es un evento de pérdida de energía.

Excepciones a chequear en gama business `[C]` — **requiere estar físicamente frente a la notebook** (en la BIOS, AnyDesk deja de funcionar):
- Lenovo ThinkPad: Config → Power → **"Power On with AC Attach"**
- Dell Latitude/Precision: Power Management → **"Wake on AC"**
- Algunos HP EliteBook/ProBook y notebooks gamer

```powershell
shutdown /r /fw /t 0     # reinicia directo a la BIOS
```

Si es Lenovo, se puede consultar sin reiniciar:

```powershell
Get-CimInstance -Namespace root\wmi -ClassName Lenovo_BiosSetting |
  ForEach-Object { $_.CurrentSetting } | Where-Object { $_ -match 'AC|Wake|Power' }
```

**2. Wake-on-LAN NO sirve para esto.** `[V]` Requiere que el NIC tenga energía en standby; tras un corte total la máquina está en G3 y no hay nada escuchando. Además, durante un apagón el router y la ONU también están caídos: no hay quién mande el paquete ni por dónde. WoL sirve para despertar una máquina dormida **con corriente presente**, desde la misma LAN.

**3. La batería es el único respaldo real, y sólo si está sana.** Con Docker + WSL corriendo, esperá **1–3 horas**, no más. Si el reporte de 2.2 muestra FCC muy baja o batería ausente → **reemplazarla** es el arreglo más barato y el que ataca la causa raíz.

**4. Aunque la notebook sobreviva, el router y la ONU también tienen que sobrevivir.** El Cloudflare Tunnel es una conexión **saliente**: sin internet en la casa, el servicio está caído aunque la máquina esté perfecta. **Un UPS que cubra sólo la notebook no arregla el problema.** `[R]` Un UPS chico (~500–800VA) sobre **el cargador de la notebook Y el router + ONU** es lo que realmente cierra este escenario — precio a confirmar en el mercado local.

**5. Internet residencial no tiene SLA.** Ni la luz. Para la fase pública, hospedar en una casa un servicio del que dependen usuarios pagos es aceptar una disponibilidad que **ninguna configuración de Windows puede levantar** por encima de la del suministro eléctrico y del ISP domiciliario. Ver 6.4.

**6. Los arreglos de PWA no ayudan durante la caída actual.** `[V]` Un service worker nuevo sólo llega cuando el origen está arriba. Ayudan a partir de la próxima caída, y sólo a clientes que cargaron la app al menos una vez después del deploy.

**7. La reconexión de cloudflared puede tardar hasta ~5 min** por diseño `[V]`. Eso no se puede eliminar, sólo acotar bajando `retries` a 3 (peor caso ~80 s).

**8. Los contenedores parados a mano no vuelven.** `[V]` `restart: unless-stopped` **no** reinicia lo que fue detenido con `docker compose stop/down`. Si tocaste eso, hay que levantarlo a mano.

**9. Si el disco tiene BitLocker con PIN al arranque, nada de esto arranca desatendido.** `[C]`

```powershell
Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, KeyProtector
```

**10. Auto-login: evitarlo.** Si la sección 3 se ejecuta completa (Docker Engine + systemd + tarea programada), **no hace falta**. `[R]` Si por algún motivo hubiera que usarlo, tener claro el costo: cualquiera que encienda la notebook queda dentro de una sesión activa con acceso a `.env.local` (que contiene `DATABASE_URL` y `SECRET_KEY_BASE` de la base productiva), a las sesiones del navegador, a `gh auth` y a AnyDesk. Y **nunca** configurar `DefaultPassword` a mano en el registro — eso deja la contraseña en **texto plano**; si hiciera falta, usar **Sysinternals Autologon** (de Microsoft), que la guarda cifrada en LSA.

---

## 10. Pendientes / a decidir

**Bloqueantes de decisión — dependen de los resultados de la sección 2:**

- [ ] **¿Docker Desktop o Docker Engine?** Si es Desktop, el Paso 0 es obligatorio y hay que agendar la ventana de migración. Decide si el resto de la guía aplica tal cual.
- [ ] **¿Hubo corte de luz o de internet?** (evento 105). Si fue **internet**, toda la parte de batería/UPS-notebook es secundaria y el foco es el **router + ONU**.
- [ ] **¿Está viva la batería?** Si FCC/DC < 50% o no hay batería: decidir **reemplazo** vs **UPS**. El UPS es superior porque cubre también el router.
- [ ] **¿Windows Home o Pro?** Si es Home, las políticas de Windows Update del Paso 7 no aplican y hay que convivir con reinicios.
- [ ] **¿La BIOS tiene "Wake on AC" / "Wake Up on Alarm"?** Requiere ir físicamente a la notebook. Si tiene "Wake Up on Alarm", programar un encendido diario (ej. 06:00) es una red de seguridad barata.

**Decisiones de arquitectura, para tomar después de que los Tests 4 y 5 pasen:**

- [ ] ¿Meter **cloudflared dentro de `compose.local.yml`** con `restart: unless-stopped`? `[R]` Ventaja: el túnel pasa a depender de **una sola cosa** (el daemon de Docker) en vez de dos. Requiere cambiar el ingress a `http://caddy:8080`, usar la ruta del credentials-file dentro del contenedor, y **desinstalar el servicio del host** (si no, dos instancias del mismo túnel). Trade-off: si Docker no arranca no arranca nada — pero eso ya es el caso hoy, porque sin app el túnel devolvería 502 igual.
- [ ] ¿Se apaga la VM GCP? **No antes** de completar 6.3 puntos 3, 6 y 7. Costo actual de `alejandro-vm` `[C]` a confirmar en la consola de GCP.
- [ ] ¿Se compra el **Cloudflare Load Balancer** ($5/mo base, desglose a confirmar en el dashboard)? Sólo cuando el estado compartido esté resuelto.
- [ ] ¿UPS sobre router + ONU? Definir presupuesto.
- [ ] ¿Mover el repo de `/mnt/c` a `~/` dentro de la distro? (si 2.7 dio `/mnt/c`)

**Deuda técnica identificada, sin fecha:**

- [ ] Redis sin `appendonly` → puede perder ~60 s de escrituras y **jobs de Sidekiq** en un corte.
- [ ] `authenticate_user!` debería responder **401** en peticiones JSON en vez de redirigir (corrección de raíz del bug de borrado de ventas).
- [ ] Editar una venta existente no tiene soporte offline (sólo `new_record?`).
- [ ] Plan de Cloudflare de `cd-co.com.py` `[C]` — determina si el webhook de Notifications está disponible o hay que quedarse con email.

---

## Fuentes principales

**Microsoft / WSL:** [systemd en WSL](https://github.com/MicrosoftDocs/wsl/blob/main/WSL/systemd.md) · [wsl-config](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) · [filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems) · issues [#9968](https://github.com/microsoft/WSL/issues/9968) (la distro se apaga sola), [#13291](https://github.com/microsoft/WSL/issues/13291) (`instanceIdleTimeout`, respuesta de ingeniero MS), [#41110](https://github.com/microsoft/WSL/issues/41110) (WSL sí corre en Session 0), [#40638](https://github.com/microsoft/WSL/issues/40638) (corrupción ext4 + ubicación del VHD), [#12747](https://github.com/microsoft/WSL/issues/12747) (pierde red tras hibernar), [#14261](https://github.com/microsoft/WSL/discussions/14261) (**contiene la receta falsa `autostart=true`**)

**Docker:** [roadmap#515 — Docker Desktop no arranca sin login (abierto)](https://github.com/docker/roadmap/issues/515) · [Engine post-install: start on boot](https://docs.docker.com/engine/install/linux-postinstall/)

**Cloudflare:** [Run as a service on Linux](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/as-a-service/linux/) · [Run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/) · [Tunnel availability and failover](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-availability/) · [Deploy replicas](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-availability/deploy-replicas/) · [Notifications](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/monitor-tunnels/notifications/) · [Metrics](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/monitor-tunnels/metrics/) · [Common errors / 1033](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/troubleshoot-tunnels/common-errors/) · [Public load balancers](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/public-load-balancers/) · [Plans](https://www.cloudflare.com/plans/) · código fuente: `cmd/cloudflared/linux_service.go`, `config/configuration.go`, `supervisor/supervisor.go`, `retry/backoffhandler.go`

**Railway:** [Pricing plans](https://docs.railway.com/pricing/plans) · [App sleeping](https://docs.railway.com/reference/app-sleeping)

**Repo verificado** (`/Users/Fabrizio/code/financespy`): `compose.local.yml`, `Caddyfile.local`, `app/views/pwa/service-worker.js`, `public/offline.html`, `app/controllers/concerns/authentication.rb`, `app/controllers/sales_controller.rb`, `app/javascript/controllers/offline_sale_form_controller.js`, `app/javascript/controllers/pending_sales_controller.js`, `config/routes.rb`, `config/schedule.yml`, `config/storage.yml`, `config/environments/production.rb`, `docs/cloudflared-config.yml.example`
