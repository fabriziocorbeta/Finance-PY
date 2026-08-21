---
type: project-note
title: "CD&Co ERP - Módulo de Exportación"
project: cdco-erp
created: 2026-05-06
updated: 2026-05-06T18:00:00
status: implementado
tags: [cdco, erp, exportación, supabase, vercel, financepy, backend]
---

# CD&Co ERP — Módulo de Exportación de Datos

## Qué se construyó

Módulo completo para exportar datos del ERP en dos formatos:
1. **JSON completo** — backup de todas las tablas de Supabase
2. **CSV para FinancePY** — importación directa a FinancePY (formato estricto)

Funciona en dos entornos: servidor de desarrollo local (`simple-server.js`) y producción en Vercel (Serverless Functions en `api/`).

---

## Archivos creados

| Archivo | Tipo | Propósito |
|---------|------|-----------|
| `data-exporter.js` | CJS módulo | Exporta 20 tablas Supabase → JSON estructurado |
| `sure-csv-exporter.js` | CJS módulo | Exporta txs + sales → CSV formato FinancePY |
| `api/export-data.js` | Vercel fn (ESM) | Endpoint `/api/export-data?user_id=...` |
| `api/export-sure-csv.js` | Vercel fn (ESM) | Endpoint `/api/export-sure-csv?user_id=...` |

---

## Endpoints

| Método | URL | Respuesta |
|--------|-----|-----------|
| `GET` | `/api/export-data?user_id=<uuid>` | JSON attachment (todas las tablas) |
| `GET` | `/api/export-data?user_id=<uuid>&meta=1` | JSON metadatos solamente |
| `GET` | `/api/export-sure-csv?user_id=<uuid>` | CSV attachment formato FinancePY |

---

## Arquitectura de data-exporter.js

- **20 tablas** exportadas: profiles, contacts, accounts, cards, products, txs, sales, orders, budgets, subscriptions, debts, metas, vehicles, fuel_logs, fleet_statistics, maintenance_alerts, prestamos, cuotas_prestamos, rule_alerts, rule_runs
- `Promise.all()` — fetch paralelo de todas las tablas (vs el upstream que usa `find_each` secuencial)
- **Aislamiento por tabla**: cada fetch retorna `{ data, error }`, nunca lanza excepción
- Envelope `_meta` con version, exported_at, total_rows, row_counts, tables_with_errors
- `profiles` usa filtro `id=eq.${userId}`; todas las demás usan `user_id=eq.${userId}`

---

## Arquitectura de sure-csv-exporter.js

### Formato CSV requerido por FinancePY
```
date*,amount*,name,currency,category,tags,account,notes
```

### Fuentes de datos
- `txs` → movimientos financieros (amounts ya firmados en DB: negativos=gastos)
- `sales` → ventas (always positive, ingreso)
- `contacts` → para resolver `client_id` → nombre del cliente
- `accounts` → para resolver `account_id` → nombre de cuenta bancaria

### Transformaciones clave
| Campo FinancePY | Fuente | Transformación |
|------------|--------|----------------|
| `date` | `t.date` (YYYY-MM-DD) | → MM/DD/YYYY |
| `amount` | `t.amount` / `s.total` | txs: as-is (firmado); sales: positivo |
| `currency` | `t.cur` ('$'/'₲'/'€') | → 'USD'/'PYG'/'EUR' |
| `account` | `t.account_id` | join `accounts` → `.name` |
| `name` (sales) | `s.client_id` | join `contacts` → `.name` |
| `notes` (sales) | `nro_factura \| notes \| id` | concatenado con ` \| ` |

---

## Patrón Vercel (importante)

Los archivos en `api/` usan **ESM** (`export default`), igual que los existentes (`api/business.js`).
Los módulos del servidor usan **CJS** (`module.exports`).

Importar CJS desde ESM:
```javascript
// ESM puede importar CJS via default import
import dataExporter from '../data-exporter.js';
const { exportUserData, exportFilename } = dataExporter;
```

Named imports desde CJS en ESM son poco fiables en Node.js → siempre usar default import.

---

## Frontend (Seguridad & Respaldos)

**`index.html`** — tres botones en el panel:
1. `💾 Generar Backup Ahora` (`btn-backup-now`) — backup server-side
2. `📥 Descargar Backup Completo (JSON)` (`btn-export-full`) — exporta JSON
3. `⬇️ Exportar CSV para FinancePY` (`btn-export-sure-csv`) — exporta CSV. **Nota**: el texto real del botón en `index.html` todavía nombra la marca upstream, no "FinancePY" — pendiente de corregir en código junto al resto de identificadores (ver nota de renombrado abajo)

**`js/backup-ui.js`** — funciones:
- `downloadFullExport()` — llama `/api/export-data`
- `downloadSureCsv()` — llama `/api/export-sure-csv`
- Ambas: fetch → blob → `URL.createObjectURL` → `<a>.click()` → toast con conteo

---

## Decisiones de diseño

- **Un solo URL para dev y prod**: `/api/export-sure-csv` funciona en simple-server y en Vercel (mismo path gracias al alias en simple-server).
- **No npm deps**: usa `fetch` nativo — consistente con el resto del servidor.
- **Per-table error isolation**: export continúa aunque una tabla no exista (tablas nuevas de migraciones futuras).
- **Inspirado en**: `Family::DataExporter` + `FamilyDataExportJob` del repo upstream (Rails, slug `we-promise/sure` — identificador literal, no marca comercial de FinancePY). Node.js version usa paralelismo donde Ruby usaba `find_each` secuencial.

---

## Variables de entorno requeridas en Vercel

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
```

Agregar en: Vercel Dashboard → Project → Settings → Environment Variables.

---

## Bug: listeners nunca se conectaban

**Síntoma:** botón visible en producción, clic sin efecto, sin errores de consola.

**Causa raíz:** `initBackupUI()` definida en `backup-ui.js` pero **nunca llamada**. Sin llamada = sin `addEventListener` = silencio total.

**Fix (`f3c1f94`):** `renderPageData('plan')` en `nav.js` ahora llama `initBackupUI()`:
```javascript
else if(pg==='plan'){
  buildPlanCards();
  loadEmpresaForm();
  if(typeof loadAdminUsers==='function') loadAdminUsers();
  if(typeof initBackupUI==='function') initBackupUI();   // ← agregado
}
```

**Fix 2 (`b612ddb`):** Aún con el fix anterior, si Vercel renderiza el HTML diferente o el orden de scripts varía, el binding puede fallar. Solución definitiva: **event delegation** en `document`:

```javascript
document.addEventListener('click', function(e) {
  const id = (e.target.closest('button') || e.target).id;
  if (id === 'btn-backup-now')      { triggerBackupNow();   return; }
  if (id === 'btn-export-full')     { downloadFullExport(); return; }
  if (id === 'btn-export-sure-csv') { downloadSureCsv();    return; }
});
```

Wired una vez al cargar el script → inmune a orden de render, inyección dinámica, SPA navigation.

**Regla aprendida:** En SPAs, usar event delegation en `document` para botones cuya aparición en el DOM no está garantizada en tiempo de init. `addEventListener` directo solo es seguro si el elemento existe antes de que el script corra.

---

## Commits relacionados

| Hash | Descripción |
|------|-------------|
| `b007df2` | feat: add GET /api/export/data endpoint |
| `253baa1` | feat: full data export download button + Vercel serverless |
| `19f30e4` | feat: CSV export para FinancePY — GET /api/export-sure-csv (mensaje real del commit todavía nombra la marca upstream, pendiente de squash/reescritura si se decide limpiar el historial) |
| `f3c1f94` | fix: wire initBackupUI() into renderPageData('plan') |
