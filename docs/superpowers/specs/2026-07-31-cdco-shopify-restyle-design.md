# CD & Co Shopify — Restyle estético completo

Status: approved
Created: 2026-07-31

## Contexto

Tienda Shopify de CD & Co (relojes: Casio, Seiko, G-Shock, Citizen, Michael Kors), dominio
`www.cd-co.com.py`, plan Basic, moneda PYG. Objetivo: modificación estética completa,
visualmente atractiva, para atrapar cliente. Sin restricción de paleta/logo previa (libertad
total de diseño, logo actual se mantiene).

## Estado actual (verificado vía Admin API)

- Tema publicado (`MAIN`): **"Copia actualizada de Rebel"** — familia Horizon de Shopify,
  100% restyleable vía `settings_data.json` (color schemes + typography), sin necesidad de
  tocar Liquid.
- Otros temas sin publicar en la cuenta: `Rebel`, `Copia actualizada de Copia actualizada de
  Rebel`, `Trade`, `CD&Co - Preview fotos uniformes`.
- Paleta actual: scheme-1 navy/blanco corporativo (`#232743` / `#ffffff`), sin relación con
  identidad de lujo/vintage. Ya existe un scheme-4 tostado/dorado (`#c8b69a`) cargado pero sin
  uso real en el homepage.
- Tipografía actual: Barlow (heading) + Inter (body) — genérica, sin carácter.
- Logo: `CD_CO2.png`, ya cargado, altura 50px. Se mantiene sin cambios.
- Homepage (`templates/index.json`), orden de secciones:
  1. `hero`
  2. `slideshow`
  3. `product-list`
  4. `section` (genérica)
  5. `media-with-content` (x2)
  6. `collection-list`
  7. `marquee`
- Colecciones sin imagen de portada: Home page, Para Dama, Para Caballero, Seiko Caballero,
  Seiko Dama — inconsistencia visual notada, pero fuera de alcance de este spec (ver
  "Fuera de alcance").

## Objetivo del restyle

Estilo: **mix lujo minimalista + vintage retro**. Fondo claro/cálido con espacio generoso,
tipografía serif con carácter para encabezados, acentos dorados envejecidos, contraste
dramático en hero/footer con un scheme oscuro.

## Alcance

Duplicar el tema publicado, aplicar todos los cambios sobre la copia (`UNPUBLISHED`),
revisar en preview, y publicar solo con aprobación explícita del usuario. El tema en vivo
no se toca hasta el momento de publicar.

### 1. Paleta de colores (reemplaza schemes actuales en la copia)

**Scheme "Marfil"** (contenido general: product-list, sections, media, footer si aplica):
- `background`: `#f5f1e8`
- `foreground_heading`: `#1c1a17`
- `foreground`: `#1c1a17`
- `primary` / `primary_button_background` / `border acentos`: `#b08d57` (dorado envejecido)
- `primary_button_text`: `#f5f1e8`
- `primary_hover` / `primary_button_hover_background`: `#8f6f42` (dorado más oscuro)
- `secondary_button_*`: transparente con borde `#1c1a17`, texto `#1c1a17`
- Inputs, variantes, badges: neutros claros derivados de la misma paleta (crema/carbón),
  sin colores saturados ajenos a la paleta.

**Scheme "Noir"** (hero + marquee, para contraste dramático):
- `background`: `#14120f`
- `foreground_heading` / `foreground`: `#f5f1e8`
- `primary` / acentos: `#b08d57` (mismo dorado, consistencia de marca)
- `primary_button_background`: `#b08d57`, `primary_button_text`: `#14120f`
- `secondary_button_*`: transparente con borde marfil

Los 4 color schemes existentes (`scheme-1..4`) se reemplazan por estos 2, reasignados a las
secciones del homepage según corresponda (Noir en `hero` y `marquee`, Marfil en el resto).

### 2. Tipografía

- `type_heading_font`: Fraunces (serif con carácter, vintage-editorial) — id `fraunces_n4`.
  Si el id no está disponible en el font picker de la cuenta, fallback a `playfair_display_n4`.
- `type_body_font` / `type_subheading_font`: Jost — id `jost_n4`. Fallback a `work_sans_n4`
  si no disponible.
- `type_font_button_primary`: se mantiene heredado de `body`.

Verificar disponibilidad real de los ids contra el theme editor antes de aplicar; si un id
no resuelve, usar el fallback indicado sin bloquear el resto del restyle.

### 3. Forma / detalles

- `button_border_radius_primary` y `button_border_radius_secondary`: mantener en `0`
  (filo recto, ya está así — coherente con el estilo).
- `badge_corner_radius`: bajar de `40` a `4` (menos "pill" de app, más sobrio).

### 4. Homepage — contenido

- **Hero**: nuevo copy (español, tono cálido/directo para mercado paraguayo) + imagen de
  producto existente de buena calidad (ej. Casio Dama LTP-1235SG-7, ya tiene foto de portada
  decente). Scheme Noir.
- **Marquee**: texto rotativo tipo "Envío a todo Paraguay · Relojes originales · Garantía".
  Scheme Noir.
- Resto de secciones (slideshow, product-list, section genérica, media-with-content x2,
  collection-list): scheme Marfil, sin cambios estructurales — solo heredan la paleta/tipografía
  nueva.

## Fuera de alcance (flag, no bloquea este trabajo)

- Imágenes de portada faltantes en colecciones (Home page, Para Dama, Para Caballero, Seiko
  Caballero, Seiko Dama) — requiere curar/generar imágenes nuevas, se resuelve en un pase
  aparte si el usuario lo pide.
- Cambio de tema base (evaluado y descartado: restyle del tema actual es suficiente y de
  menor riesgo que migrar a `Trade` u otro tema desde cero).

## Plan de ejecución (alto nivel)

1. Duplicar tema publicado (`themeDuplicate` o equivalente) → nueva copia `UNPUBLISHED`.
2. Sobre la copia: actualizar `config/settings_data.json` con los 2 nuevos color schemes,
   tipografía, `badge_corner_radius`.
3. Sobre la copia: actualizar `templates/index.json` — asignar scheme Noir a `hero` y
   `marquee`, scheme Marfil al resto; actualizar copy del hero y texto del marquee.
4. Preview de la copia en navegador (desktop + mobile) — verificar contraste, legibilidad,
   que el dorado no choque con fotos de producto.
5. Ajustes si algo no funciona visualmente.
6. Publicar la copia como tema principal — **requiere confirmación explícita del usuario**
   antes de este paso (acción visible en la tienda real).

## Riesgos / notas

- Cambiar el tema en vivo es una acción visible públicamente — se hace únicamente al final,
  sobre una copia ya revisada, y con aprobación explícita antes de publicar.
- Si algún id de fuente no resuelve en el font picker de esta cuenta, se usa el fallback
  indicado en la sección de tipografía sin detener el resto del trabajo.
