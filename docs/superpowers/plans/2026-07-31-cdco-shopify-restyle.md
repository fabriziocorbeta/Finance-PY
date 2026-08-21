# CD & Co Shopify Restyle — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the "lujo minimalista + vintage retro" restyle (spec:
`docs/superpowers/specs/2026-07-31-cdco-shopify-restyle-design.md`) to CD & Co's Shopify
storefront, entirely on a duplicated theme, publishing only after explicit user approval.

**Architecture:** All changes are made via the Shopify Admin GraphQL API (tools prefixed
`mcp__ef2de246-b606-4ccc-8d2b-e3d5862f7aaa__`), not via a local codebase. There is no git
repo for the theme and no test runner — "tests" in this plan are read-back assertions
(fetch the file after writing it, assert the values landed) plus a visual check via the
Browser pane. There are no git commits in this plan; the only durable artifacts are the
Shopify theme resource and, at the end, this plan file's checkboxes.

**Tech Stack:** Shopify Admin GraphQL API (theme + theme-files mutations), `graphql_query` /
`graphql_mutation` MCP tools, Bash + Python for local JSON transforms, Browser pane for
visual verification.

## Global Constraints

- Live theme (`gid://shopify/OnlineStoreTheme/144698048688`, "Copia actualizada de Rebel")
  must NOT be modified directly. All writes target the duplicate created in Task 1.
- Publishing the duplicate (Task 5) is a publicly-visible action on a live store —
  **do not run Task 5 without an explicit new "sí, publicá" from the user in this
  conversation**, even if earlier tasks were approved.
- Store domain: `www.cd-co.com.py`, myshopify domain `y04ir1-ag.myshopify.com`, currency
  PYG, plan Basic.
- Working directory for temp files: `/private/tmp/cdco-theme-restyle/` (create with
  `mkdir -p` if missing before Task 1).
- Color values, font ids, and copy below are exact and final — do not invent alternatives
  mid-task. If a step's verification fails, follow that step's stated fallback, don't
  improvise a new one.

---

### Task 1: Duplicate the live theme

**Files:** none (Shopify resource only)

**Interfaces:**
- Produces: `NEW_THEME_ID` (a `gid://shopify/OnlineStoreTheme/...` string) — every
  subsequent task's mutations target this id, not the live theme id.

- [ ] **Step 1: Create working directory**

Run: `mkdir -p /private/tmp/cdco-theme-restyle`

- [ ] **Step 2: Duplicate the theme**

Call `graphql_mutation` with:

```graphql
mutation ThemeDuplicate($id: ID!, $name: String) {
  themeDuplicate(id: $id, name: $name) {
    newTheme { id name role }
    userErrors { field message }
  }
}
```

Variables:
```json
{
  "id": "gid://shopify/OnlineStoreTheme/144698048688",
  "name": "CD&Co - Restyle Lujo Vintage"
}
```

Expected: `userErrors` is `[]`, `newTheme.role` is `"UNPUBLISHED"`. Record `newTheme.id` as
`NEW_THEME_ID`.

- [ ] **Step 3: Verify the duplicate exists and is unpublished**

Call `graphql_query`:

```graphql
query { themes(first: 10) { edges { node { id name role } } } }
```

Expected: the list contains an entry with `id == NEW_THEME_ID`, `name == "CD&Co - Restyle
Lujo Vintage"`, `role == "UNPUBLISHED"`.

---

### Task 2: Restyle colors, typography, and badge shape

**Files:** Shopify theme file `config/settings_data.json` on `NEW_THEME_ID`.

**Interfaces:**
- Consumes: `NEW_THEME_ID` from Task 1.
- Produces: `scheme-1` = "Marfil" palette, `scheme-2` = "Noir" palette, heading font
  `fraunces_n4`, body/subheading font `jost_n4`, `badge_corner_radius = 4`. Task 3 does not
  depend on this file's content, but both tasks touch the same theme and must not clobber
  each other's files (they touch different filenames, so order between them doesn't matter).

- [ ] **Step 1: Fetch current settings_data.json from the duplicate**

Call `graphql_query`:

```graphql
query GetSettingsData($id: ID!) {
  theme(id: $id) {
    files(first: 1, filenames: ["config/settings_data.json"]) {
      edges { node { filename body { ... on OnlineStoreThemeFileBodyText { content } } } }
    }
  }
}
```

Variables: `{"id": "NEW_THEME_ID"}` (substitute the real id).

Save the returned `content` string verbatim to
`/private/tmp/cdco-theme-restyle/settings_data.raw.json` (e.g. via the Write tool).

- [ ] **Step 2: Transform the file**

Write this script to `/private/tmp/cdco-theme-restyle/transform_settings.py` and run it with
`python3 /private/tmp/cdco-theme-restyle/transform_settings.py`:

```python
import re, json

RAW_PATH = "/private/tmp/cdco-theme-restyle/settings_data.raw.json"
OUT_PATH = "/private/tmp/cdco-theme-restyle/settings_data.new.json"

with open(RAW_PATH) as f:
    raw = f.read()

# Shopify prefixes generated theme files with a /* ... */ comment block that isn't valid
# to leave in when round-tripping through json.loads.
clean = re.sub(r"^\s*/\*.*?\*/\s*", "", raw, flags=re.S)
data = json.loads(clean)
current = data["current"]

current["color_schemes"]["scheme-1"]["settings"] = {
    "background": "#f5f1e8",
    "foreground_heading": "#1c1a17",
    "foreground": "#1c1a17",
    "primary": "#b08d57",
    "primary_hover": "#8f6f42",
    "border": "#e3dbc8",
    "shadow": "#000000",
    "primary_button_background": "#b08d57",
    "primary_button_text": "#f5f1e8",
    "primary_button_border": "#b08d57",
    "primary_button_hover_background": "#8f6f42",
    "primary_button_hover_text": "#f5f1e8",
    "primary_button_hover_border": "#8f6f42",
    "secondary_button_background": "rgba(0,0,0,0)",
    "secondary_button_text": "#1c1a17",
    "secondary_button_border": "#1c1a17",
    "secondary_button_hover_background": "#1c1a17",
    "secondary_button_hover_text": "#f5f1e8",
    "secondary_button_hover_border": "#1c1a17",
    "input_background": "#ffffff",
    "input_text_color": "#1c1a17",
    "input_border_color": "#b08d57",
    "input_hover_background": "#f0ead9",
    "variant_background_color": "#ffffff",
    "variant_text_color": "#1c1a17",
    "variant_border_color": "#e3dbc8",
    "variant_hover_background_color": "#f0ead9",
    "variant_hover_text_color": "#1c1a17",
    "variant_hover_border_color": "#b08d57",
    "selected_variant_background_color": "#1c1a17",
    "selected_variant_text_color": "#f5f1e8",
    "selected_variant_border_color": "#1c1a17",
    "selected_variant_hover_background_color": "#b08d57",
    "selected_variant_hover_text_color": "#1c1a17",
    "selected_variant_hover_border_color": "#b08d57",
}

current["color_schemes"]["scheme-2"]["settings"] = {
    "background": "#14120f",
    "foreground_heading": "#f5f1e8",
    "foreground": "#f5f1e8",
    "primary": "#b08d57",
    "primary_hover": "#cba876",
    "border": "#2a2620",
    "shadow": "#000000",
    "primary_button_background": "#b08d57",
    "primary_button_text": "#14120f",
    "primary_button_border": "#b08d57",
    "primary_button_hover_background": "#cba876",
    "primary_button_hover_text": "#14120f",
    "primary_button_hover_border": "#cba876",
    "secondary_button_background": "rgba(0,0,0,0)",
    "secondary_button_text": "#f5f1e8",
    "secondary_button_border": "#f5f1e8",
    "secondary_button_hover_background": "#f5f1e8",
    "secondary_button_hover_text": "#14120f",
    "secondary_button_hover_border": "#f5f1e8",
    "input_background": "#201d18",
    "input_text_color": "#f5f1e8",
    "input_border_color": "#b08d57",
    "input_hover_background": "#2a2620",
    "variant_background_color": "#201d18",
    "variant_text_color": "#f5f1e8",
    "variant_border_color": "#2a2620",
    "variant_hover_background_color": "#2a2620",
    "variant_hover_text_color": "#f5f1e8",
    "variant_hover_border_color": "#b08d57",
    "selected_variant_background_color": "#b08d57",
    "selected_variant_text_color": "#14120f",
    "selected_variant_border_color": "#b08d57",
    "selected_variant_hover_background_color": "#cba876",
    "selected_variant_hover_text_color": "#14120f",
    "selected_variant_hover_border_color": "#cba876",
}

current["type_heading_font"] = "fraunces_n4"
current["type_body_font"] = "jost_n4"
current["type_subheading_font"] = "jost_n4"
current["badge_corner_radius"] = 4

data["current"] = current

with open(OUT_PATH, "w") as f:
    json.dump(data, f, separators=(",", ":"))

print("wrote", OUT_PATH)
```

Expected output: `wrote /private/tmp/cdco-theme-restyle/settings_data.new.json` with no
traceback. `scheme-3` and `scheme-4` are intentionally left untouched — Task-1-era
inspection of `sections/header-group.json`, `sections/footer-group.json`, and
`templates/index.json` confirmed only `scheme-1` and `scheme-2` are referenced anywhere
visible on the storefront (header, footer, hero, marquee, product-list, media-with-content,
collection-list). Touching the other two would be speculative risk with no observed payoff.

- [ ] **Step 3: Read the transformed file and push it**

Read `/private/tmp/cdco-theme-restyle/settings_data.new.json` (it's a single JSON line —
read it fully, don't truncate) and call `graphql_mutation`:

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
  "themeId": "NEW_THEME_ID",
  "files": [
    {
      "filename": "config/settings_data.json",
      "body": { "type": "TEXT", "value": "<contents of settings_data.new.json>" }
    }
  ]
}
```

Expected: `userErrors` is `[]`, `upsertedThemeFiles` contains `{"filename":
"config/settings_data.json"}`.

- [ ] **Step 4: Verify by reading the file back**

Re-run the Step 1 query against `NEW_THEME_ID`, save to
`/private/tmp/cdco-theme-restyle/settings_data.verify.json`, strip the comment header the
same way as Step 2, and assert with this script:

```python
import re, json

with open("/private/tmp/cdco-theme-restyle/settings_data.verify.json") as f:
    raw = f.read()
clean = re.sub(r"^\s*/\*.*?\*/\s*", "", raw, flags=re.S)
data = json.loads(clean)["current"]

assert data["color_schemes"]["scheme-1"]["settings"]["background"] == "#f5f1e8"
assert data["color_schemes"]["scheme-1"]["settings"]["primary"] == "#b08d57"
assert data["color_schemes"]["scheme-2"]["settings"]["background"] == "#14120f"
assert data["color_schemes"]["scheme-2"]["settings"]["primary"] == "#b08d57"
assert data["type_heading_font"] == "fraunces_n4"
assert data["type_body_font"] == "jost_n4"
assert data["badge_corner_radius"] == 4
print("OK: settings_data.json restyle verified")
```

Expected: prints `OK: settings_data.json restyle verified` with no `AssertionError`. If it
raises, re-check Step 3's `value` payload was the full file content (a truncated read is
the most likely cause) and retry Step 3.

---

### Task 3: Homepage copy — enable hero text/button and marquee

**Files:** Shopify theme file `templates/index.json` on `NEW_THEME_ID`.

**Interfaces:**
- Consumes: `NEW_THEME_ID` from Task 1.
- Produces: hero section (`hero_kbPLGL`) shows an enabled heading + button; marquee section
  (`marquee_KN4PYb`) is enabled (currently `disabled: true` at the section level, i.e. not
  shown on the site at all today).

- [ ] **Step 1: Fetch current templates/index.json from the duplicate**

Call `graphql_query`:

```graphql
query GetIndexTemplate($id: ID!) {
  theme(id: $id) {
    files(first: 1, filenames: ["templates/index.json"]) {
      edges { node { filename body { ... on OnlineStoreThemeFileBodyText { content } } } }
    }
  }
}
```

Variables: `{"id": "NEW_THEME_ID"}`.

Save the returned `content` to `/private/tmp/cdco-theme-restyle/index.raw.json`.

- [ ] **Step 2: Transform the file**

Write this script to `/private/tmp/cdco-theme-restyle/transform_index.py` and run it with
`python3 /private/tmp/cdco-theme-restyle/transform_index.py`:

```python
import re, json

RAW_PATH = "/private/tmp/cdco-theme-restyle/index.raw.json"
OUT_PATH = "/private/tmp/cdco-theme-restyle/index.new.json"

with open(RAW_PATH) as f:
    raw = f.read()

clean = re.sub(r"^\s*/\*.*?\*/\s*", "", raw, flags=re.S)
data = json.loads(clean)

hero = data["sections"]["hero_kbPLGL"]

hero_text_block = hero["blocks"]["text_aHNzLc"]
hero_text_block["disabled"] = False
hero_text_block["settings"]["text"] = (
    "<h1>Relojes con carácter</h1>"
    "<p>Piezas vintage y clásicas, elegidas para durar toda una vida.</p>"
)

hero_button_block = hero["blocks"]["button_LVRJMH"]
hero_button_block["disabled"] = False
hero_button_block["settings"]["label"] = "Ver Colección"
# link left unchanged (shopify://collections/entrega-inmediata) — not part of this restyle.

marquee = data["sections"]["marquee_KN4PYb"]
marquee["disabled"] = False
# marquee copy ("Por tus compras de +500.000gs el Delivery te sale gratis") is left as-is —
# it's an existing, working promo message, only the enabled state changes.

with open(OUT_PATH, "w") as f:
    json.dump(data, f, separators=(",", ":"))

print("wrote", OUT_PATH)
```

Expected output: `wrote /private/tmp/cdco-theme-restyle/index.new.json` with no traceback.

- [ ] **Step 3: Read the transformed file and push it**

Read `/private/tmp/cdco-theme-restyle/index.new.json` fully and call `graphql_mutation`:

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
  "themeId": "NEW_THEME_ID",
  "files": [
    {
      "filename": "templates/index.json",
      "body": { "type": "TEXT", "value": "<contents of index.new.json>" }
    }
  ]
}
```

Expected: `userErrors` is `[]`.

- [ ] **Step 4: Verify by reading the file back**

Re-run Step 1's query against `NEW_THEME_ID`, save to
`/private/tmp/cdco-theme-restyle/index.verify.json`, and assert:

```python
import re, json

with open("/private/tmp/cdco-theme-restyle/index.verify.json") as f:
    raw = f.read()
clean = re.sub(r"^\s*/\*.*?\*/\s*", "", raw, flags=re.S)
data = json.loads(clean)

hero = data["sections"]["hero_kbPLGL"]
assert hero["blocks"]["text_aHNzLc"]["disabled"] is False
assert "Relojes con carácter" in hero["blocks"]["text_aHNzLc"]["settings"]["text"]
assert hero["blocks"]["button_LVRJMH"]["disabled"] is False
assert hero["blocks"]["button_LVRJMH"]["settings"]["label"] == "Ver Colección"

marquee = data["sections"]["marquee_KN4PYb"]
assert marquee["disabled"] is False

print("OK: index.json homepage copy verified")
```

Expected: prints `OK: index.json homepage copy verified`.

- [ ] **Step 5 (optional): Swap hero image to a product photo**

The spec calls for swapping the hero background to an existing product photo (Casio Dama
LTP-1235SG-7). The theme's `image_1` / `image_1_mobile` settings currently point to
`shopify://shop_images/Sitio_Web.png`. The candidate replacement filename, taken from that
product's CDN URL, is `01_PORTADA_LOGO_TRANS_4x5_d14d0018-d448-4718-b85a-a390329e723f.jpg`.

This is marked optional because the `shopify://shop_images/<filename>` reference resolves
against the shop's Files library, and it's unverified whether a product-media filename
resolves the same way as a Files-uploaded one. Attempt it, but verify before moving on:

1. In `transform_index.py`, before writing `OUT_PATH`, add:
   ```python
   hero["settings"]["image_1"] = "shopify://shop_images/01_PORTADA_LOGO_TRANS_4x5_d14d0018-d448-4718-b85a-a390329e723f.jpg"
   hero["settings"]["image_1_mobile"] = "shopify://shop_images/01_PORTADA_LOGO_TRANS_4x5_d14d0018-d448-4718-b85a-a390329e723f.jpg"
   ```
2. Re-run Steps 2–4 of this task.
3. In Task 4's screenshot check, specifically confirm the hero image renders (not a broken
   image icon / blank space).
4. If it's broken: revert by setting both fields back to
   `"shopify://shop_images/Sitio_Web.png"`, redo Steps 3–4, and tell the user the image swap
   didn't resolve and the original hero image was kept — don't leave a broken image live.

---

### Task 4: Visual verification in the Browser pane

**Files:** none (read-only verification).

**Interfaces:**
- Consumes: `NEW_THEME_ID` from Task 1 (Tasks 2 and 3 must be complete first).

- [ ] **Step 1: Extract the numeric theme id and build the preview URL**

`NEW_THEME_ID` looks like `gid://shopify/OnlineStoreTheme/123456789`. Take the trailing
numeric segment (`123456789`) and build:

```
https://y04ir1-ag.myshopify.com/?preview_theme_id=123456789
```

- [ ] **Step 2: Open it and screenshot desktop**

Use `preview_start` with that URL, then `computer` (`action: "screenshot"`). Check:
- Hero shows the new heading/subheading/button (not just a bare image).
- Marquee text is visible.
- Background is warm cream (`#f5f1e8`), not white; hero/marquee are near-black
  (`#14120f`) with gold-ish (`#b08d57`) accents.
- Headings render in a serif face (Fraunces) distinct from the body text (Jost). If both
  still look like the same generic sans, the font ids likely didn't resolve — see fallback
  below.
- Badges (if any product on the page shows a sale/sold-out badge) look sharp-cornered, not
  pill-shaped.

If the page instead shows a Shopify storefront password gate: stop, don't attempt to log in
or bypass it (entering credentials is out of scope for this workflow). Tell the user the
preview needs to be checked from their own logged-in browser or with password protection
temporarily disabled, and wait for them before continuing.

- [ ] **Step 3: Resize to mobile and screenshot again**

Use `resize_window` with `preset: "mobile"`, reload, screenshot. Check the hero heading
doesn't overflow/clip and the marquee text still fits.

- [ ] **Step 4: Font fallback (only if Step 2's font check failed)**

Re-run Task 2 Step 2's transform with `type_heading_font = "playfair_display_n4"` and
`type_body_font` / `type_subheading_font = "work_sans_n4"` instead of `fraunces_n4` /
`jost_n4` (this is the fallback documented in the spec), redo Task 2 Steps 3–4 with these
values, then repeat this task's Step 2.

---

### Task 5: Publish (gated on explicit approval)

**Files:** none (Shopify resource only).

**Interfaces:**
- Consumes: `NEW_THEME_ID`, and confirmation that Task 4's visual check passed.

- [ ] **Step 1: Stop and ask**

Before doing anything else in this task, show the user the Task 4 screenshots (or a summary
of what changed) and ask explicitly: "¿Publico este tema como el tema principal de la
tienda?" Do not proceed past this point without an explicit yes in this conversation —
approval of the spec or plan earlier is not approval to publish.

- [ ] **Step 2: Publish**

Only after explicit yes, call `graphql_mutation`:

```graphql
mutation ThemePublish($id: ID!) {
  themePublish(id: $id) {
    theme { id role }
    userErrors { field message }
  }
}
```

Variables: `{"id": "NEW_THEME_ID"}`.

Expected: `userErrors` is `[]`, `theme.role` is `"MAIN"`.

- [ ] **Step 3: Verify live**

Call `graphql_query`:

```graphql
query { themes(first: 5) { edges { node { id name role } } } }
```

Expected: `NEW_THEME_ID` now has `role: "MAIN"`, and the old live theme
(`gid://shopify/OnlineStoreTheme/144698048688`) now has a role other than `"MAIN"`. Then
open `https://www.cd-co.com.py` in the Browser pane and screenshot it to confirm the
restyle is live on the real domain.
