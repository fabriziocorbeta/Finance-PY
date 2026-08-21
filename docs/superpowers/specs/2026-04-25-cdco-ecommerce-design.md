# CD & Co. — E-commerce Design Spec

**Date:** 2026-04-25  
**Status:** Approved  
**Brand:** CD & Co. — relojes 100% originales, Paraguay

---

## 1. Overview

Full-stack e-commerce for CD & Co., a watch retailer in Paraguay. Single product category (watches). Payment via WhatsApp + bank transfer. No Stripe or external payment gateway.

**Stack:** Next.js 15 App Router · Tailwind CSS · Supabase (DB + Auth + Storage) · Resend · Vercel

---

## 2. Routes

| Route | Description |
|-------|-------------|
| `/` | Homepage: hero, featured products, how-it-works, brand section |
| `/relojes` | Full catalog: grid + filter pills + badges |
| `/relojes/[slug]` | Product detail: gallery, variant selector (correa), qty, add to cart |
| `/carrito` | Full cart page: items + summary + checkout CTA |
| `/checkout` | Customer data form → save order → WhatsApp redirect |
| `/gracias` | Order confirmation with summary |
| `/admin` | Admin dashboard: KPIs + recent orders |
| `/admin/productos` | CRUD products + Supabase Storage image upload |
| `/admin/pedidos` | Orders list + "Marcar enviado" button |
| `/api/sync-inventory` | POST endpoint for Google Sheets/n8n integration |

---

## 3. Design Decisions

### 3.1 Visual Style
- Palette: Black `#111111` + White `#FFFFFF` + Light gray `#F5F5F5`
- Typography: Inter (system font stack fallback)
- No color accents — clean, minimal, consistent with CD & Co. logo
- Nav: white background, sticky, logo left + links center + cart button right

### 3.2 Homepage (`/`)
- Promo banner (dark) at top
- Full-height dark hero: large title, watch silhouette illustration, two CTAs (Ver Colección + WhatsApp)
- Features strip (dark): **Relojes 100% Originales · Garantía de fábrica** | Envíos a todo Paraguay | Pago por transferencia | Atención por WhatsApp
- 3 featured products grid
- "¿Cómo comprás?" — 4-step flow section
- Brand story section with logo
- Footer with WhatsApp button

### 3.3 Catalog (`/relojes`)
- Filter pills: Todos / Casio / Clásicos / Deportivos / Ofertas / Disponibles
- 3-column product grid
- Cards show: model reference, name, variant count, price, optional original price + discount badge, new badge, sold-out overlay

### 3.4 Product Page (`/relojes/[slug]`)
- Left: vertical thumbnail strip (one per variant) + large main image with "✓ 100% Original" badge
- Right panel: reference, name, stock indicator, pricing (current + original + % savings), variant selector (correa/malla cards with ref code + individual stock), quantity control, "Agregar al carrito" CTA, secondary "Consultar por WhatsApp" button, trust strip
- Below: description + spec table (marca, referencia, resistencia, movimiento, garantía, origen)

### 3.5 Cart (`/carrito`)
- Left: item list with watch thumbnail, name, variant label (e.g. "Correa Dorada · Ref. 9A"), qty controls, remove button, subtotal per item
- Right: order summary, total, "Continuar con mis datos" CTA, flow explanation box, trust strip

### 3.6 Checkout (`/checkout`)
Form fields: nombre completo, teléfono WhatsApp, email, ciudad, dirección de entrega  
On submit:
1. `POST /api/pedidos` — inserts order in Supabase with `estado = 'pendiente'`
2. Resend: confirmation email to customer
3. Redirect to: `https://wa.me/595994702933?text=...` (pre-filled message)

WhatsApp message format:
```
Hola! Hice un pedido en CD & Co. 🕐

Pedido #1042
━━━━━━━━━━━━
• Casio LTP-1169 – Correa Dorada (×1) → ₲ 280.000
• Casio MTP-1183 – Correa Negra (×2) → ₲ 700.000
━━━━━━━━━━━━
Total: ₲ 980.000

Nombre: Ana García
Teléfono: 0981 234 567
Ciudad: Asunción
Dirección: Av. España 1234

¿Me podés confirmar el número de cuenta para la transferencia?
```

### 3.7 Admin (`/admin/*`)
- Top nav: logo, sections (Pedidos / Productos / Inventario), user email
- Dashboard: 4 KPI cards (ventas semana, pedidos total, pendientes, productos activos)
- Orders table: #id, email, items, total, estado, action button
- Products: CRUD form + image upload to Supabase Storage bucket `productos`
- Protected via Supabase Auth middleware — checks `public.users.role = 'admin'`

---

## 4. Database Schema (Supabase)

### `productos`
```sql
CREATE TABLE productos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  descripcion TEXT,
  precio      INTEGER NOT NULL,           -- in PYG (guaraníes)
  precio_original INTEGER,               -- for discount display
  imagenes    TEXT[] DEFAULT '{}',        -- Supabase Storage URLs
  variantes   JSONB DEFAULT '[]',         -- see structure below
  coleccion   TEXT,
  activo      BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);
```

Variant JSON structure:
```json
[
  {
    "id": "9a",
    "nombre": "Dorada",
    "referencia": "LTP-1169-9A",
    "imagen": "https://...supabase.../dorada.jpg",
    "stock": 5
  }
]
```

### `pedidos`
```sql
CREATE TABLE pedidos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero           SERIAL UNIQUE,          -- human-readable #1042
  cliente_nombre   TEXT NOT NULL,
  cliente_email    TEXT NOT NULL,
  cliente_telefono TEXT NOT NULL,
  ciudad           TEXT NOT NULL,
  direccion        TEXT NOT NULL,
  items            JSONB NOT NULL,          -- snapshot of cart at order time
  total            INTEGER NOT NULL,        -- in PYG
  estado           TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'pagado', 'enviado', 'cancelado')),
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
);
```

Items JSON structure:
```json
[
  {
    "producto_id": "uuid",
    "slug": "casio-ltp-1169",
    "nombre": "Casio Mujer LTP-1169",
    "variante_id": "9a",
    "variante_nombre": "Dorada",
    "referencia": "LTP-1169-9A",
    "cantidad": 1,
    "precio_unitario": 280000
  }
]
```

---

## 5. Stock Logic

**Critical rule:** Stock is NOT decremented on order creation.

Stock (stored inside `variantes` JSONB array per product) is decremented **only** when an admin changes order `estado` to `pagado` or `enviado` via the admin dashboard.

Implementation: Supabase database function + trigger, or server-side API route called from the admin "Marcar enviado" action.

---

## 6. Inventory Sync API

**Endpoint:** `POST /api/sync-inventory`  
**Auth:** `Authorization: Bearer <SYNC_TOKEN>` (token from `.env.local`)

Request body:
```json
{
  "slug": "casio-ltp-1169",
  "variante_id": "9a",
  "precio": 280000,
  "precio_original": 350000,
  "stock": 5
}
```

Response:
```json
{ "ok": true, "updated": "casio-ltp-1169 / variante 9a" }
```

Use cases: Google Sheets → n8n → this endpoint, or Google Apps Script trigger.

---

## 7. Email Notifications (Resend)

**Trigger 1 — Order created:**  
To: `cliente_email`  
Subject: `Tu pedido #1042 está confirmado — CD & Co.`  
Content: order summary, total, next steps (WhatsApp payment coordination)

**Trigger 2 — Order marked as "enviado":**  
To: `cliente_email`  
Subject: `¡Tu reloj está en camino! — CD & Co.`  
Content: order number, items, shipping confirmation, WhatsApp contact

Both emails use Resend with credentials from `.env.local` (`RESEND_API_KEY`).

---

## 8. Environment Variables

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Resend
RESEND_API_KEY=
RESEND_FROM_EMAIL=pedidos@cdco.com.py

# WhatsApp
NEXT_PUBLIC_WHATSAPP_NUMBER=595994702933

# Inventory sync
SYNC_INVENTORY_TOKEN=

# App
NEXT_PUBLIC_SITE_URL=
```

---

## 9. Auth Flow (Admin)

1. Admin navigates to `/admin`
2. Next.js middleware checks Supabase session cookie
3. If no session → redirect to `/admin/login`
4. If session exists → check `public.users.role = 'admin'`
5. If not admin → redirect to `/` with error
6. Supabase Auth: `signInWithPassword` (email + password)
7. No hardcoded credentials — all managed via Supabase Auth dashboard

---

## 10. Cart State

Cart stored in `localStorage` — no server-side session required for shopping.  
Cart item structure mirrors `pedidos.items` JSONB for easy order creation.

---

## 11. Supabase Storage

Bucket: `productos` (public read, authenticated write)  
Path pattern: `productos/{slug}/{filename}`  
Admin uploads via Next.js API route using service role key (not exposed to client).
