---
type: session
title: "Sesión 2026-07-22/23 — FinancePY ventas, CSP bug, seguridad agente, migración"
created: 2026-07-23
tags: [session, financespy, agente-ia-cdco, seguridad, hosting]
---

# Sesión 2026-07-22/23

## Feature shipped: Nota de venta + Nota de entrega (FinancePY)

- `SalesController#print` / `#delivery_note`, layout reutiliza `layouts/print` (mismo patrón que Reports, auto `window.print()`)
- Campos nuevos en `Sale`: `delivery_address`, `delivery_date`, `carrier`
- Rediseño visual tipo Shopify packing-slip a pedido del usuario (sin alterar datos, solo formato)
- Sección de firmas removida del remito a pedido (no se usa)

## Bug real: CSP enforce rompía navegación de tablas

4 vistas (`sales/products/purchase_orders/fleet_vehicles` index) usaban `onclick="window.location='...'"` inline para navegar al click en fila. El CSP enforce (activado en el audit de julio) lo bloqueaba silenciosamente — nonces no cubren atributos de evento inline, solo tags `<script>`/`<style>`. Fix: `row_click_controller.js` (Stimulus) en las 4 vistas.

**Lección:** cualquier `onclick=`/`style=""` inline es candidato a romperse bajo CSP enforce. Grep proactivo si aparecen más reportes de "no funciona" sin error visible.

## Decisión de hosting — corte definitivo

Ver [[FinancePY - Hosting fase prueba (PC local)]] para el detalle completo. Motivado por crédito GCP que vence, no solo por latencia:

- **FinancePY → PC local** (Docker + Cloudflare Tunnel). Archivos listos: `compose.local.yml`, `Caddyfile.local`, `docs/cloudflared-config.yml.example`. DB sigue en Supabase (nunca hubo Postgres local).
- **Agentes → Railway.** Cloud Run descartado por precio (~$57/mes solo openwa-api always-on vs ~$10-27/mes stack completo en Railway).
- **VM GCP se desactiva por completo** una vez migrado todo.
- Fix operativo: disco de la VM se llenaba en cada build fallido (BuildKit cache no liberado por `docker system prune` normal) — **redimensionado 30GB→50GB** (no destructivo, resize en caliente).
- **Migración a la PC no se ejecutó esta sesión** — Claude no tiene acceso a esa máquina Windows. Estimado: ~60-90 min (WSL2+Docker 10-20min, copiar repo+.env.local 5-10min, primer build 5-15min, Cloudflare Tunnel+DNS 10-15min, verificación 5-10min).

## Hallazgo de seguridad real: alejandro-agent (bot WhatsApp)

Security-review pre-migración encontró que `/webhook` (callback interno openwa→agente) y `/health/reconnect` estaban **sin autenticación**, expuestos en el mismo puerto público que el callback OAuth de Shopify. Cualquiera en internet podía inyectar mensajes falsos de WhatsApp al pipeline de leads/ventas, o forzar reconexiones de la sesión real.

Fix: `/webhook` verifica `X-OpenWA-Signature` (HMAC-SHA256, mecanismo nativo de openwa-api); `/health/reconnect` usa secreto estático via header. Fail-closed si el secreto no está seteado. Deployado y verificado con curl real (403 sin firma, 200 con firma correcta). Detalle completo en `project_agente_ia_cdco.md` (memoria).

Descubrimiento colateral: esta memoria estaba muy desactualizada (describía fase de planning) — el agente es un producto real en prod con dashboard, Shopify, Instagram, GA4, leads/funnel, n8n-router, Hermes. Corregida.

## Aprendizajes de proceso

- Repos de código en `/Users/Fabrizio/code/` (financespy, alejandro-agent) tienen remote real y CI/CD — el vault (`02 Sistema`) no tiene remote, es local puro. No confundir al correr comandos que asumen `origin/HEAD`.
- Un "worktree borrado" que reporta el sistema puede seguir existiendo físicamente en disco — verificar antes de asumir que el trabajo se perdió (`git worktree list`, `ls` directo).
- `docker system prune -af` no libera cache de BuildKit — usar `docker buildx prune -af` específicamente.
- Antes de editar un `docker-compose.yml` para agregar una env var, confirmar que el servicio realmente arranca desde ese archivo — alejandro-agent se levanta con `docker run` directo en un script, no via compose, pese a que el compose file existe (stale).
