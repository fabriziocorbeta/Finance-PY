---
type: emprendimiento
status: activo
created: 2026-07-07
updated: 2026-07-07
tags: [saas, fintech, paraguay, rails]
---

# FinancePY

SaaS fintech para Paraguay, fork del proyecto upstream open-source.

## Stack
- Rails 7.2, desplegado en VM de GCP
- Comparte repo con [[CD & Co ERP]] vía branch `version-1.1.0`

## Estado
- Family nativo funcionando
- Business Mode Toggle: shipped
- Módulos premium ERP en spec: inventario, ventas/facturación, órdenes de compra, flota (FleetVehicle renombrado para evitar colisión con Vehicle nativo del upstream)

## Consideraciones Paraguay
- Guaraní (PYG) sin decimales — cuidar redondeos y formateo
- Facturación: régimen local (timbrado, RUC) a considerar en módulo de ventas

## Relacionado
- [[CD & Co ERP]], [[fable-clon-skill]] (checklist SaaS)
