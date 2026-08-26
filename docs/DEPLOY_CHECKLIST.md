# Checklist y Guía de Deploy a Producción (Notebook Local)

Este documento detalla el procedimiento oficial para desplegar actualizaciones de **FinancePY** en la notebook de producción local vía SSH/Tailscale.

---

## ⚠️ Incidente Histórico & Requisito Crítico

> **CRÍTICO:** Cada vez que se compilan o recrean los contenedores `web` o `worker`, Docker asigna nuevas direcciones IP internas a los contenedores. Caddy mantiene en cache la IP previa del contenedor `web`. **SIEMPRE** se debe ejecutar `docker restart financespy-caddy-1` (o `docker compose -f compose.prod.yml restart caddy`) al finalizar el deploy para evitar errores **502 Bad Gateway** en vivo.

---

## 🚀 Opciones de Deploy

### Opción 1: Ejecución con Script de Un Solo Comando (Recomendado)

Desde tu Mac conectada vía Tailscale, podés ejecutar todo el proceso de deploy con una sola línea de SSH:

```bash
ssh <usuario>@<ip-notebook> "cd ~/financespy && ./bin/deploy_notebook.sh"
```

El script `bin/deploy_notebook.sh` automatiza exactos los siguientes pasos:
1. `git pull --ff-only`
2. `BUILD_COMMIT_SHA=$(git rev-parse HEAD) docker compose -f compose.prod.yml build web worker`
3. `docker compose -f compose.prod.yml up -d web worker`
4. `docker restart financespy-caddy-1` *(Limpieza de caché IP en Caddy)*
5. Verificación de salud: `curl http://localhost/up` y chequeo de `/internal/version` contra el commit HEAD.

---

### Opción 2: Procedimiento Manual Paso a Paso

Si necesitás realizar el deploy manualmente desde la terminal de la notebook:

1. **Ingresá al directorio del proyecto:**
   ```bash
   cd ~/financespy
   ```

2. **Obtené los últimos cambios de `main`:**
   ```bash
   git pull --ff-only
   ```

3. **Reconstruí los contenedores `web` y `worker` pasando el commit SHA actual:**
   ```bash
   BUILD_COMMIT_SHA=$(git rev-parse HEAD) docker compose -f compose.prod.yml build web worker
   ```

4. **Levantá los contenedores actualizados en segundo plano:**
   ```bash
   docker compose -f compose.prod.yml up -d web worker
   ```

5. **CRÍTICO: Reiniciá Caddy para refrescar la IP proxy:**
   ```bash
   docker restart financespy-caddy-1
   # O alternativamente:
   # docker compose -f compose.prod.yml restart caddy
   ```

6. **Verificá el estado del servicio:**
   ```bash
   curl -I http://localhost/up
   # Debe responder HTTP/1.1 200 OK

   curl -s -H "X-Internal-Token: $INTERNAL_VERSION_TOKEN" http://localhost/internal/version
   # Debe retornar {"commit_sha":"<commit_hash>","version":"..."}
   ```

---

## 🔒 Configuración de Tokens e Integración CI

Para que el workflow de GitHub Actions (`.github/workflows/notify-deploy-pending.yml`) pueda verificar automáticamente si producción está al día:

1. Definí la variable `INTERNAL_VERSION_TOKEN` en tu archivo `.env` de producción en la notebook, con un valor aleatorio propio (no un ejemplo de este documento).
2. Agregá los siguientes Secrets en el repositorio de GitHub (Settings -> Secrets and variables -> Actions):
   - `INTERNAL_VERSION_TOKEN`: mismo valor configurado en el `.env` de producción.
   - `PROD_URL`: URL pública o accesible del entorno (ej. `https://finance.cd-co.com.py`).

---

## 🔍 Diagnóstico de Problemas Frecuentes

- **502 Bad Gateway tras deploy:**
  Ejecutá `docker restart financespy-caddy-1` inmediatamente.
- **El endpoint `/internal/version` devuelve 503 Service Unavailable:**
  Asegurate de que `INTERNAL_VERSION_TOKEN` esté configurado en el archivo `.env` y que el contenedor haya sido reiniciado.
