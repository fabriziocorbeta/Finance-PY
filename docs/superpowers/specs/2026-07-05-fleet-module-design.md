---
title: "Módulo Flota — FinancePY Premium (Sub-proyecto 5)"
created: 2026-07-05
status: approved
---

# Módulo Flota — Sub-proyecto 5

Parte de la iniciativa "Business Mode Toggle" (ver `2026-07-03-business-mode-toggle-design.md`). Último de los 4 módulos premium. El ERP tiene un módulo Flota "enterprise" (vehicles, fuel_logs, maintenance_alerts, fleet_statistics, settle_batches) — este sub-proyecto porta solo el núcleo (FleetVehicle + FuelLog), dejando fuera alertas de mantenimiento, estadísticas y settlement batches como posible expansión futura, no parte de este MVP.

**⚠️ Colisión de nombres (detectada 2026-07-05):** El proyecto upstream ya tiene un modelo nativo `Vehicle < ApplicationRecord` (incluye `Accountable`, tabla `vehicles`) usado como tipo de cuenta para patrimonio neto (como Property/Investment). Un primer intento de Jules nombró el modelo de este sub-proyecto `Vehicle` y pisó/hubiera roto el original. **El modelo de este sub-proyecto se llama `FleetVehicle` (tabla `fleet_vehicles`)**, sin relación con el `Vehicle` nativo del upstream.

## Modelo `FleetVehicle`

`belongs_to :family`, `has_many :fuel_logs, dependent: :destroy`

| Campo | Tipo | Notas |
|---|---|---|
| plate | string | patente, única por family |
| brand | string | marca |
| model | string | modelo |
| year | integer | nullable |
| status | enum | `active` (default) / `maintenance` / `inactive` |
| notes | text | nullable |

Validaciones: `plate` presente y único scoped a family, `brand`/`model` presentes.

## Modelo `FuelLog`

`belongs_to :fleet_vehicle`

| Campo | Tipo | Notas |
|---|---|---|
| liters | decimal | > 0 |
| cost | decimal | >= 0 |
| odometer | integer | >= 0, nullable |
| currency | enum | `pyg` (default) / `usd` |
| logged_at | date | fecha de la carga |
| notes | string | nullable |

Sin lógica de negocio compleja (no toca stock, no hay ciclo de vida de status) — es un registro histórico simple, a diferencia de Sale/PurchaseOrder. `FuelLog` no tiene transiciones ni congelamiento; siempre editable directamente (no hay motivo de negocio para bloquearlo, es solo un log de carga de combustible).

## Acceso

Igual que los otros 3 módulos: gateado por `RequireBusinessMode`, cualquier miembro de la family.

## Vistas

CRUD `index`/`show`/`new`/`edit` de `FleetVehicle` con el patrón visual ya establecido (`DS::Button`, `DS::Link`, `DS::Menu`, `styled_form_with`). En `show`, tabla embebida de `fuel_logs` del vehículo con acción rápida para agregar una carga nueva (form simple, no nested attributes — es una tabla independiente sin ciclo de vida compartido).

## Fuera de alcance (explícito)

- `maintenance_alerts`, `fleet_statistics`, `settle_batches` del ERP — no se portan en este sub-proyecto
- Reportes de consumo/eficiencia
- Notificaciones de service/mantenimiento programado

## Testing

Model tests para `FleetVehicle` (unicidad de `plate` por family) y `FuelLog` (validaciones de campos). Controller tests: CRUD de vehículos, CRUD de fuel_logs anidados bajo un vehículo, scoping entre families, gate de `business_mode_enabled`.
