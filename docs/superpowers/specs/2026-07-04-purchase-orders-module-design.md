---
title: "Módulo Pedidos a Proveedores — FinancePY Premium (Sub-proyecto 4)"
created: 2026-07-04
status: approved
---

# Módulo Pedidos a Proveedores — Sub-proyecto 4

Parte de la iniciativa "Business Mode Toggle" (ver `2026-07-03-business-mode-toggle-design.md`). Espejo de Ventas (sub-proyecto 3), con lógica de stock invertida: los pedidos a proveedores **suman** stock en vez de restarlo.

## Modelo `PurchaseOrder`

`belongs_to :family`, `has_many :purchase_order_items, dependent: :destroy`

| Campo | Tipo | Notas |
|---|---|---|
| order_number | integer | correlativo por family, único |
| supplier_name | string | texto libre |
| status | enum | `draft` (default) / `received` / `cancelled` |
| currency | enum | `pyg` (default) / `usd` |
| expected_date | date | nullable |
| notes | text | |

`order_number`: mismo criterio que `sale_number` — asignado en creación vía `family.purchase_orders.maximum(:order_number).to_i + 1`.

`total`: método calculado, suma de `purchase_order_items.sum { |i| i.subtotal }`.

## Modelo `PurchaseOrderItem`

`belongs_to :purchase_order`, `belongs_to :product`

| Campo | Tipo | Notas |
|---|---|---|
| quantity | integer | > 0 |
| unit_cost | decimal | snapshot al momento del pedido, no referencia dinámica a `product.buy_price` |

`subtotal` = `quantity * unit_cost`.

## Ciclo de vida de stock (invertido respecto a Sale)

- **draft**: no toca stock, items editables.
- **received**: al transicionar `draft → received` (método `receive!`), por cada item se crea un `ProductStockMovement` (`reason: entrada`, `quantity_delta: +quantity`). Items quedan congelados.
- **cancelled**: si viene de `received`, repone... resta stock (`ProductStockMovement reason: salida`, `quantity_delta: -quantity`) revirtiendo la entrada. Si viene de `draft`, no genera movimientos.

Mismo mecanismo de bloqueo de escritura directa de `status` que `Sale` (`allow_status_change` interno, transición solo vía `receive!`/`cancel!`).

## Acceso

Igual que Inventario/Ventas: gateado por `RequireBusinessMode`, cualquier miembro de la family.

## Vistas

Mismo patrón visual que `products`/`sales` ya mergeados — `DS::Button`, `DS::Link`, `DS::Menu`, `styled_form_with`, mismas clases Tailwind. CRUD `index`/`show`/`new`/`edit`, form con items vía nested attributes mientras `draft`, solo-lectura si no.

## Fuera de alcance (explícito)

- Modelo Supplier propio (texto libre, igual que en Product/Sale)
- Edición de items después de `received`
- Notificaciones/recordatorios de `expected_date`

## Testing

Mismo patrón de tests que `Sale`/`SaleItem`: `order_number` autoincrementa por family, `total` calculado, `receive!` suma stock, `cancel!` desde `received` resta stock de vuelta, `cancel!` desde `draft` no genera movimientos, items no editables fuera de `draft`.
