# CD & Co Product Page Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a trust/guarantee block, a specs icon row (Estado/Diámetro/Mecanismo), and an
accordion (Descripción/Envío/Cómo pagar) to CD & Co's product page template, per
`docs/superpowers/specs/2026-08-01-cdco-product-page-redesign-design.md`.

**Architecture:** All changes are via the Shopify Admin GraphQL API (same tools as the
prior restyle plan: `mcp__ef2de246-b606-4ccc-8d2b-e3d5862f7aaa__graphql_query` /
`graphql_mutation`), on the same `UNPUBLISHED` duplicate theme. Two independent pieces:
(1) product metafields (`estado`/`diametro`/`mecanismo`) set once per product via
`metafieldsSet`, read by the template with Liquid; (2) a `templates/product.json` edit
that applies to all products automatically since it's one shared template. No git repo
involvement, no code tests — verification is read-back assertions plus a browser
screenshot, same pattern as the restyle plan.

**Tech Stack:** Shopify Admin GraphQL API (`metafieldsSet`, `themeFilesUpsert`), Bash +
Python for local JSON transforms, Browser pane for visual verification.

## Global Constraints

- `THEME_ID` = `gid://shopify/OnlineStoreTheme/146834129072` (same UNPUBLISHED restyle
  theme from the prior plan — do not touch the live theme
  `gid://shopify/OnlineStoreTheme/144698048688`).
- Working directory: `/private/tmp/cdco-theme-restyle/` (already exists from prior work).
- **Never invent a diámetro or mecanismo value.** Task 1's table below is the complete,
  final list — it was built by reading each of the 12 active products' actual
  `descriptionHtml` and copying the exact "Ficha Técnica" table values. Where a product's
  table has no "Movimiento" row, its `mecanismo` metafield is intentionally omitted, not
  filled with a guess (only 3 of 12 products have a stated mechanism).
- Payment/shipping/guarantee copy is exact and final (verified against the spec, which
  was itself corrected against the user's real business policy, not copied from a
  competitor): garantía = 6 meses por defecto de fábrica (no cubre agua/pila), pago =
  al recibir si es entrega en mano, transferencia por adelantado si es por transportadora.
  Do not alter this copy.
- `metafieldsSet` accepts at most 25 metafields per call — Task 1 is split into two
  batches for this reason, not for any other.

---

### Task 1: Set product metafields (Estado / Diámetro / Mecanismo)

**Files:** none (Shopify resource only — product metafields).

**Interfaces:**
- Produces: metafields `custom.estado`, `custom.diametro`, `custom.mecanismo`
  (type `single_line_text_field`) on each of the 12 active products. Task 3's Liquid
  reads these as `product.metafields.custom.estado.value` etc.

- [ ] **Step 1: Batch 1 — set metafields for 8 products**

Call `graphql_mutation`:

```graphql
mutation MetafieldsSet($metafields: [MetafieldsSetInput!]!) {
  metafieldsSet(metafields: $metafields) {
    metafields { key namespace value ownerId }
    userErrors { field message code }
  }
}
```

Variables:
```json
{
  "metafields": [
    {"ownerId": "gid://shopify/Product/7983248834736", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/7983248834736", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "38mm"},

    {"ownerId": "gid://shopify/Product/7983250309296", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/7983250309296", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "28 × 21 mm"},

    {"ownerId": "gid://shopify/Product/8010150084784", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8010150084784", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "46.6 × 39.9 mm"},
    {"ownerId": "gid://shopify/Product/8010150084784", "namespace": "custom", "key": "mecanismo", "type": "single_line_text_field", "value": "Cuarzo Japonés"},

    {"ownerId": "gid://shopify/Product/8012744818864", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8012744818864", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "37.7 × 20.7 mm"},

    {"ownerId": "gid://shopify/Product/8013642858672", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8013642858672", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "32.6 × 21 mm"},

    {"ownerId": "gid://shopify/Product/8022105161904", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8022105161904", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "32.6 × 21 mm"},

    {"ownerId": "gid://shopify/Product/8027004666032", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8027004666032", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "32.6 × 21 mm"},

    {"ownerId": "gid://shopify/Product/8048181870768", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8048181870768", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "30.3 × 24.6 mm"}
  ]
}
```

Expected: `userErrors` is `[]`, 17 metafields returned.

- [ ] **Step 2: Batch 2 — set metafields for remaining 4 products**

Same mutation, variables:
```json
{
  "metafields": [
    {"ownerId": "gid://shopify/Product/8049169072304", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8049169072304", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "30.3 × 24.6 mm"},

    {"ownerId": "gid://shopify/Product/8058993115312", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8058993115312", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "38 mm"},
    {"ownerId": "gid://shopify/Product/8058993115312", "namespace": "custom", "key": "mecanismo", "type": "single_line_text_field", "value": "Automático (Calibre 7S26, 21 rubíes)"},

    {"ownerId": "gid://shopify/Product/8058993541296", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8058993541296", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "32.6 × 21 mm"},

    {"ownerId": "gid://shopify/Product/8063576506544", "namespace": "custom", "key": "estado", "type": "single_line_text_field", "value": "Nuevo"},
    {"ownerId": "gid://shopify/Product/8063576506544", "namespace": "custom", "key": "diametro", "type": "single_line_text_field", "value": "38 mm"},
    {"ownerId": "gid://shopify/Product/8063576506544", "namespace": "custom", "key": "mecanismo", "type": "single_line_text_field", "value": "Automático (Calibre 7S26)"}
  ]
}
```

Expected: `userErrors` is `[]`, 10 metafields returned.

- [ ] **Step 3: Verify**

Call `graphql_query`:
```graphql
query CheckMetafields($id: ID!) {
  product(id: $id) {
    title
    metafields(namespace: "custom", first: 5) { edges { node { key value } } }
  }
}
```
Run once with `{"id": "gid://shopify/Product/8058993115312"}` (Seiko — expect all 3 keys:
`estado`, `diametro`, `mecanismo`) and once with
`{"id": "gid://shopify/Product/7983248834736"}` (Casio MTP V002L 2B3 — expect only
`estado` and `diametro`, no `mecanismo`). Both results matching this is the pass
condition — a product silently getting a `mecanismo` it shouldn't have is a bug, not a
bonus.

---

### Task 2: Add trust block, specs row, and accordion to `templates/product.json`

**Files:** Shopify theme file `templates/product.json` on `THEME_ID`.

**Interfaces:**
- Consumes: metafields from Task 1 (`product.metafields.custom.estado/diametro/mecanismo`).
- Produces: three new blocks inside the `main` section's `product-details` block,
  inserted between the existing `custom_liquid_rt7TrH` (WhatsApp button) and the point
  where `text_aEtTtq` (flat description) used to be — `text_aEtTtq` is removed and
  replaced by an accordion block containing the same description content.

- [ ] **Step 1: Fetch current `templates/product.json`**

```graphql
query GetProduct($id: ID!) {
  theme(id: $id) {
    files(first: 1, filenames: ["templates/product.json"]) {
      edges { node { body { ... on OnlineStoreThemeFileBodyText { content } } } }
    }
  }
}
```
Variables: `{"id": "gid://shopify/OnlineStoreTheme/146834129072"}`. Save the `content` to
`/private/tmp/cdco-theme-restyle/product.raw.json`.

- [ ] **Step 2: Transform the file**

Write this script to `/private/tmp/cdco-theme-restyle/transform_product.py` and run it
with `python3`:

```python
import re, json

RAW_PATH = "/private/tmp/cdco-theme-restyle/product.raw.json"
OUT_PATH = "/private/tmp/cdco-theme-restyle/product.new.json"

with open(RAW_PATH) as f:
    raw = f.read()

clean = re.sub(r"^\s*/\*.*?\*/\s*", "", raw, flags=re.S)
data = json.loads(clean)

details = data["sections"]["main"]["blocks"]["product-details"]
blocks = details["blocks"]
order = details["block_order"]

def text_block(text_html, type_preset="paragraph", font_size="0.95rem"):
    return {
        "type": "text",
        "settings": {
            "text": text_html,
            "width": "100%",
            "max_width": "normal",
            "alignment": "left",
            "type_preset": type_preset,
            "font": "var(--font-body--family)",
            "font_size": font_size,
            "line_height": "normal",
            "letter_spacing": "normal",
            "case": "none",
            "wrap": "pretty",
            "color": "",
            "background": False,
            "background_color": "#00000026",
            "corner_radius": 0,
            "padding-block-start": 0,
            "padding-block-end": 0,
            "padding-inline-start": 0,
            "padding-inline-end": 0
        },
        "blocks": {}
    }

def group_block(name, gap, child_ids, children):
    return {
        "type": "group",
        "name": name,
        "settings": {
            "content_direction": "column",
            "vertical_on_mobile": True,
            "horizontal_alignment": "flex-start",
            "vertical_alignment": "center",
            "align_baseline": False,
            "horizontal_alignment_flex_direction_column": "flex-start",
            "vertical_alignment_flex_direction_column": "center",
            "gap": gap,
            "width": "fill",
            "custom_width": 100,
            "width_mobile": "fill",
            "custom_width_mobile": 100,
            "height": "fit",
            "custom_height": 100,
            "inherit_color_scheme": True,
            "color_scheme": "",
            "background_media": "none",
            "video_position": "cover",
            "background_image_position": "cover",
            "border": "none",
            "border_width": 1,
            "border_opacity": 100,
            "border_radius": 0,
            "toggle_overlay": False,
            "overlay_color": "#00000026",
            "overlay_style": "solid",
            "gradient_direction": "to top",
            "link": "",
            "open_in_new_tab": False,
            "placeholder": "",
            "padding-block-start": 0,
            "padding-block-end": 0,
            "padding-inline-start": 0,
            "padding-inline-end": 0
        },
        "blocks": children,
        "block_order": child_ids
    }

# --- 1. Trust / guarantee block ---
trust_children = {
    "text_trust_heading": text_block("<h4>Compra segura, sin sorpresas</h4>", "h4"),
    "text_trust_body": text_block(
        "<p>Confirmamos tu pedido por WhatsApp antes de cualquier pago. Según cómo se "
        "entregue, pagás al recibir (Asunción y Gran Asunción) o por transferencia por "
        "adelantado (envío por transportadora a otras ciudades).</p>"
    ),
    "text_trust_row": text_block(
        "<p>✅ Confirmación por WhatsApp antes de coordinar el pago<br>"
        "✅ Atención directa, sin intermediarios</p>"
    ),
    "text_trust_guarantee": text_block(
        "<p>🛡️ <strong>Garantía de 6 meses por defecto de fábrica.</strong><br>"
        "<small>No cubre daños por agua ni cambio de pila.</small></p>"
    ),
}
trust_block = group_block(
    "Bloque de confianza",
    12,
    ["text_trust_heading", "text_trust_body", "text_trust_row", "text_trust_guarantee"],
    trust_children,
)

# --- 2. Specs row (reads metafields set in Task 1) ---
specs_children = {
    "text_specs_row": text_block(
        "<p>"
        "<strong>Estado:</strong> {{ closest.product.metafields.custom.estado.value }}"
        "{% if closest.product.metafields.custom.diametro.value != blank %}"
        " &nbsp;·&nbsp; <strong>Diámetro:</strong> {{ closest.product.metafields.custom.diametro.value }}"
        "{% endif %}"
        "{% if closest.product.metafields.custom.mecanismo.value != blank %}"
        " &nbsp;·&nbsp; <strong>Mecanismo:</strong> {{ closest.product.metafields.custom.mecanismo.value }}"
        "{% endif %}"
        "</p>"
    ),
}
specs_block = group_block("Fila de specs", 0, ["text_specs_row"], specs_children)

# --- 3. Accordion (replaces the flat description block) ---
description_text = blocks["text_aEtTtq"]["settings"]["text"]

accordion_block = {
    "type": "accordion",
    "name": "Info del producto",
    "settings": {
        "icon": "caret",
        "dividers": True,
        "type_preset": "h5",
        "inherit_color_scheme": True,
        "color_scheme": "",
        "border": "none",
        "border_width": 1,
        "border_opacity": 100,
        "border_radius": 0,
        "padding-block-start": 0,
        "padding-block-end": 0,
        "padding-inline-start": 0,
        "padding-inline-end": 0
    },
    "blocks": {
        "accordion_row_descripcion": {
            "type": "_accordion-row",
            "settings": {
                "heading": "Descripción del producto",
                "open_by_default": True,
                "icon": "none",
                "width": 200
            },
            "blocks": {
                "text_descripcion": text_block(description_text, "rte"),
            },
            "block_order": ["text_descripcion"]
        },
        "accordion_row_envio": {
            "type": "_accordion-row",
            "settings": {
                "heading": "Envío",
                "open_by_default": False,
                "icon": "none",
                "width": 200
            },
            "blocks": {
                "text_envio": text_block(
                    "<p>Llegamos a todos los rincones del país, con un tiempo estimado "
                    "de 3 a 7 días hábiles una vez procesado tu pedido. Por compras de "
                    "+500.000gs el delivery es gratis.</p>"
                ),
            },
            "block_order": ["text_envio"]
        },
        "accordion_row_pago": {
            "type": "_accordion-row",
            "settings": {
                "heading": "Cómo pagar",
                "open_by_default": False,
                "icon": "none",
                "width": 200
            },
            "blocks": {
                "text_pago": text_block(
                    "<p>Elegí tus productos y confirmá tu pedido. Dentro de un día "
                    "hábil te contactamos por WhatsApp (+595 994702933) para confirmar "
                    "disponibilidad. Si la entrega es en mano (Asunción y Gran "
                    "Asunción), pagás al recibir tu pedido. Si el envío es por "
                    "transportadora a otras ciudades, el pago se realiza por "
                    "transferencia bancaria por adelantado, dentro de un plazo de 24 "
                    "horas.</p>"
                ),
            },
            "block_order": ["text_pago"]
        },
    },
    "block_order": ["accordion_row_descripcion", "accordion_row_envio", "accordion_row_pago"]
}

# --- Splice into product-details: remove text_aEtTtq, insert the 3 new blocks in its place ---
insert_at = order.index("text_aEtTtq")
new_order = order[:insert_at] + ["group_trust", "group_specs", "accordion_info"] + order[insert_at + 1:]

del blocks["text_aEtTtq"]
blocks["group_trust"] = trust_block
blocks["group_specs"] = specs_block
blocks["accordion_info"] = accordion_block

details["block_order"] = new_order

with open(OUT_PATH, "w") as f:
    json.dump(data, f, separators=(",", ":"))

print("wrote", OUT_PATH)
print("new block_order:", new_order)
```

Expected output: `wrote /private/tmp/cdco-theme-restyle/product.new.json` followed by a
`new block_order` line showing `group_icgrde`, `divider_VJhene`, `variant_picker_R3rGDr`,
`buy_buttons_eYQEYi`, `custom_liquid_rt7TrH`, `group_trust`, `group_specs`,
`accordion_info` (in that order, `text_aEtTtq` gone). If the printed order doesn't match,
stop and check the script — don't push a mis-ordered file.

- [ ] **Step 3: Read the transformed file and push it**

Read `/private/tmp/cdco-theme-restyle/product.new.json` fully (one line — don't
truncate) and call:

```graphql
mutation ThemeFilesUpsert($themeId: ID!, $files: [OnlineStoreThemeFilesUpsertFileInput!]!) {
  themeFilesUpsert(themeId: $themeId, files: $files) {
    upsertedThemeFiles { filename }
    userErrors { field message }
  }
}
```
Variables:
```json
{
  "themeId": "gid://shopify/OnlineStoreTheme/146834129072",
  "files": [
    {
      "filename": "templates/product.json",
      "body": { "type": "TEXT", "value": "<contents of product.new.json>" }
    }
  ]
}
```
Expected: `userErrors` is `[]`.

- [ ] **Step 4: Verify by reading the file back**

Re-run Step 1's query, save to `/private/tmp/cdco-theme-restyle/product.verify.json`,
strip the comment, `json.loads` it, and assert:

```python
import re, json

with open("/private/tmp/cdco-theme-restyle/product.verify.json") as f:
    raw = f.read()
clean = re.sub(r"^\s*/\*.*?\*/\s*", "", raw, flags=re.S)
data = json.loads(clean)

details = data["sections"]["main"]["blocks"]["product-details"]
assert "text_aEtTtq" not in details["blocks"]
assert "group_trust" in details["blocks"]
assert "group_specs" in details["blocks"]
assert "accordion_info" in details["blocks"]
assert details["blocks"]["accordion_info"]["block_order"] == [
    "accordion_row_descripcion", "accordion_row_envio", "accordion_row_pago"
]
assert "Garantía de 6 meses" in details["blocks"]["group_trust"]["blocks"]["text_trust_guarantee"]["settings"]["text"]
assert "{{ closest.product.metafields.custom.estado.value }}" in details["blocks"]["group_specs"]["blocks"]["text_specs_row"]["settings"]["text"]

print("OK: product.json trust/specs/accordion verified")
```
Expected: prints `OK: product.json trust/specs/accordion verified`.

---

### Task 3: Visual verification

**Files:** none (read-only).

**Interfaces:**
- Consumes: Task 1 (metafields) and Task 2 (template) must both be complete.

- [ ] **Step 1: Open a product with mecanismo set**

Preview URL pattern: `https://y04ir1-ag.myshopify.com/products/<handle>?preview_theme_id=146834129072`.
Use handle `seiko-5-automatico-snkl45k1` (product `8058993115312`, has all 3 metafields).
Screenshot. Check:
- Trust block renders below the WhatsApp button, readable against the Marfil/Noir
  color scheme (not clashing, not invisible).
- Specs row shows all three: Estado, Diámetro, Mecanismo, separated by " · ".
- Accordion shows 3 collapsed/expanded rows: "Descripción del producto" (open by
  default, same content as before), "Envío", "Cómo pagar" — clicking a closed row
  expands it.

- [ ] **Step 2: Open a product without mecanismo set**

Use handle `casio-mtp-v002l-2b3` (product `7983248834736`, only `estado` + `diametro`).
Screenshot. Check: specs row shows only "Estado: Nuevo · Diámetro: 38mm" — no dangling
" · " or empty "Mecanismo:" label. If a stray separator or empty label shows up, the
Liquid `{% if %}` guards in Task 2 Step 2 need fixing before this task is done.

- [ ] **Step 3: Report**

If both checks pass, the plan is complete. If either fails, fix the specific template
block (not a rewrite) and repeat Task 2 Steps 3–4 and this task.
