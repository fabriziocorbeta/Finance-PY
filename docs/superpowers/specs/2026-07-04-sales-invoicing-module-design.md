---
title: "Módulo Ventas y Facturación — FinancePY Premium (Sub-proyecto 3)"
created: 2026-07-04
status: approved
---

# Módulo Ventas y Facturación — Sub-proyecto 3

Parte de la iniciativa "Business Mode Toggle" (ver `2026-07-03-business-mode-toggle-design.md`). Porta el módulo Ventas del CD & Co ERP a FinancePY como feature premium.

## Modelo `Sale`

`belongs_to :family`, `has_many :sale_items, dependent: :destroy`

| Campo | Tipo | Notas |
|---|---|---|
| sale_number | integer | correlativo por family, único |
| client_name | string | texto libre (mismo criterio que supplier en Product) |
| status | enum | `draft` (default) / `completed` / `cancelled` |
| currency | enum | `pyg` (default) / `usd` |
| payment_method | string | texto libre |
| invoice_number | string | texto libre |
| condition | string | texto libre |
| notes | text | |

`sale_number` se asigna automáticamente en creación: `family.sales.maximum(:sale_number).to_i + 1`.

`total` es un método calculado (no columna): suma de `sale_items.sum { |i| i.subtotal }`.

## Modelo `SaleItem`

`belongs_to :sale`, `belongs_to :product`

| Campo | Tipo | Notas |
|---|---|---|
| quantity | integer | > 0 |
| unit_price | decimal | snapshot al momento de la venta, no referencia dinámica a `product.sell_price` |

`subtotal` = `quantity * unit_price` (método calculado).

## Ciclo de vida de stock

- **draft**: crear/editar/eliminar `SaleItem` **no** toca stock. Items totalmente editables mientras el Sale esté en draft.
- **completed**: al transicionar `draft → completed`, por cada `SaleItem` se crea un `ProductStockMovement` (`reason: salida`, `quantity_delta: -quantity`) en el product asociado. A partir de este punto, **los items quedan congelados** — no se puede agregar/quitar/modificar items de un Sale completed (solo campos como `client_name`, `notes`, `payment_method`, `condition`, `invoice_number` siguen editables).
- **cancelled**: si transiciona desde `completed`, por cada `SaleItem` se crea un `ProductStockMovement` (`reason: entrada`, `quantity_delta: +quantity`) reponiendo el stock. Si transiciona desde `draft`, no genera movimientos (nunca se descontó).

Transición de status vía un método explícito en el modelo (ej. `sale.complete!`, `sale.cancel!`), no vía `update` directo del campo `status`, para poder disparar la lógica de stock de forma controlada.

## Acceso

Igual que Inventario: gateado por `RequireBusinessMode`, cualquier miembro de la family puede gestionar ventas (no restringido a super_admin).

## Vistas

CRUD con el formato visual nativo de FinancePY. `index`/`show`/`new`/`edit` de Sale, con gestión de items embebida en el form de `new`/`edit` (nested attributes) mientras esté en draft. En `show`, si el Sale es `draft`, mostrar acciones para completar/cancelar; si es `completed`, mostrar acción para cancelar; si es `cancelled`, sin acciones de transición.

## Fuera de alcance (explícito)

- Modelo Client propio (texto libre, igual que Supplier)
- Edición de items después de `completed`
- Facturación electrónica / integración fiscal real (`invoice_number`/`condition` son solo campos de texto)
- Reportes o dashboards de ventas

## Testing

Model tests para `Sale` (autoincremento de `sale_number` por family, `total` calculado, transiciones `complete!`/`cancel!` y su efecto en stock) y `SaleItem` (validaciones, `subtotal`).
