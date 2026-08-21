---
title: "Módulo Inventario y Productos — FinancePY Premium (Sub-proyecto 2)"
created: 2026-07-03
status: approved
---

# Módulo Inventario y Productos — Sub-proyecto 2

Parte de la iniciativa "Business Mode Toggle" (ver `2026-07-03-business-mode-toggle-design.md`). Porta el módulo Inventario del CD & Co ERP a FinancePY como feature premium, con el formato visual nativo de FinancePY.

## Alcance

CRUD básico de productos, gateado por `business_mode_enabled` de la family. Alertas de stock bajo/agotado y panel de valor total quedan para una iteración siguiente (fuera de alcance aquí).

## Modelo `Product`

`belongs_to :family`

| Campo | Tipo | Notas |
|---|---|---|
| name | string | requerido |
| sku | string | único por family, opcional |
| category | string | texto libre |
| supplier | string | texto libre (Supplier real llega en sub-proyecto 4) |
| buy_price | decimal | |
| sell_price | decimal | |
| currency | enum | `pyg` (default) / `usd` |
| stock | integer | default 0 |
| min_stock | integer | default 0, solo dato — sin lógica de alerta aún |
| description | text | opcional |

Validaciones: `name` presente, `sku` único por family si presente, `buy_price`/`sell_price`/`stock`/`min_stock` >= 0.

## Modelo `ProductStockMovement`

`belongs_to :product`. Historial de entradas/salidas, **no** ligado a `Transaction`.

| Campo | Tipo | Notas |
|---|---|---|
| quantity_delta | integer | positivo = entrada, negativo = salida |
| reason | enum | `entrada` / `salida` / `ajuste` |
| note | string | opcional |

Crear un movimiento actualiza `product.stock` (`quantity_delta` sumado), dentro de una transacción DB.

## Acceso

- Gateado por `RequireBusinessMode` (ya existe, `app/controllers/concerns/require_business_mode.rb`)
- Cualquier miembro de la family (`member`/`admin`, no solo `super_admin`) puede gestionar productos — el toggle admin ya restringe el acceso a nivel family
- Nueva sección de nav visible solo si `Current.family.business_mode_enabled?`

## Vistas

CRUD estándar `index` / `show` / `new` / `edit` con el formato visual de FinancePY (mismos componentes DS:: usados en el resto de la app — `DS::Button`, tablas existentes, etc.). Sin alertas visuales ni panel de valor total en esta iteración.

## Fuera de alcance (explícito)

- Alertas de stock bajo/agotado
- Panel de valor total en ₲/$
- Modelo Supplier propio (texto libre por ahora)
- Categorías como modelo (texto libre por ahora)
- Integración con Transaction

## Testing

Model tests (`Product`, `ProductStockMovement`), controller tests (CRUD + gate de `business_mode_enabled` + gate de family scoping — un usuario no puede ver/editar productos de otra family).
