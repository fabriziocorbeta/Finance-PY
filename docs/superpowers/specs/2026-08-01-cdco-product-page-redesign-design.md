# CD & Co Shopify — Rediseño de página de producto

Status: approved
Created: 2026-08-01

## Contexto

Sigue al restyle estético de la tienda (ver [2026-07-31-cdco-shopify-restyle-design.md](2026-07-31-cdco-shopify-restyle-design.md)). El usuario compartió capturas de la página de producto de un competidor (Zarate Watches) como referencia de qué tan completa/persuasiva quiere que se vea la página de cada producto propio.

Comparación contra la plantilla actual (`templates/product.json` en el tema restyle
`gid://shopify/OnlineStoreTheme/146834129072`) mostró que ya existen: galería de medios,
título, precio, selector de variante, botones de compra, y un botón verde de WhatsApp
("Terminar compra en WhatsApp", bloque `custom-liquid`) — la referencia y la tienda ya
coinciden bastante ahí. La descripción del producto hoy es un solo bloque de texto plano
(`text_aEtTtq`, contenido = `{{ closest.product.description }}`).

## Alcance decidido con el usuario

Se prioriza todo lo que se puede construir **sin fotos ni testimonios nuevos** (esos
requieren material que el usuario no tiene todavía). Quedan fuera de este spec:

- Banner de fecha de entrega estimada por ciudad — depende de un sistema logístico real
  que la tienda no tiene; no se simula.
- Grid de fotos de estilo de vida (pareja/deporte/oficina/noche) — necesita fotos nuevas.
- Testimonios con foto + cita — **no se inventan reseñas falsas de clientes**; si el
  usuario junta testimonios reales más adelante, es un spec aparte.

## Corrección importante sobre el mensaje de confianza

La referencia dice "Paga solo al Recibir" y "Sin Pagos por Adelantado" (contra-entrega).
La política real de CD & Co (confirmada por el usuario) tiene dos modalidades, ninguna
igual a la de la referencia: si la entrega es en mano (Asunción y Gran Asunción), el
cliente paga al recibir; si el envío es por transportadora a otras ciudades, el pago es
por transferencia bancaria por adelantado. Copiar el mensaje de la referencia (que asume
contra-entrega siempre) sería impreciso para la mitad de los casos. El bloque de
confianza de este spec no afirma una sola modalidad — dice que la forma de pago se
confirma por WhatsApp según cómo se entregue.

## Diseño

### 1. Bloque de confianza (a nivel de plantilla — aplica a los 12 productos activos
automáticamente, un solo cambio en `templates/product.json`)

Se inserta después del botón de WhatsApp existente (`custom_liquid_rt7TrH`) y antes del
acordeón (ítem 3):

- **Heading:** "Compra segura, sin sorpresas"
- **Texto:** "Confirmamos tu pedido por WhatsApp antes de cualquier pago. Según cómo se
  entregue, pagás al recibir (Asunción y Gran Asunción) o por transferencia por
  adelantado (envío por transportadora a otras ciudades)."
- **Fila de 2 íconos:**
  - "Confirmación por WhatsApp antes de coordinar el pago"
  - "Atención directa, sin intermediarios"
- **Badge de garantía:** ícono de escudo + "Garantía de 6 meses por defecto de fábrica"
  con nota chica: "No cubre daños por agua ni cambio de pila."

Todo el texto es verificado contra la política real de la tienda (FAQ existente +
confirmación explícita del usuario sobre la garantía) — nada copiado de la competencia
sin chequear.

### 2. Fila de especificaciones (Estado / Diámetro / Mecanismo)

- **Estado:** fijo "Nuevo" para los 12 productos (no requiere extracción).
- **Diámetro:** extraído por script de la descripción de cada producto, buscando el
  patrón `\d{2}(\.\d+)?\s?mm` (ej. "38 mm", "42.5mm").
- **Mecanismo:** extraído buscando "Automático" o "Cuarzo"/"Quartz" (case-insensitive)
  en la descripción.
- Los 3 valores se guardan como metafields del producto (namespace `custom`, keys
  `estado`, `diametro`, `mecanismo`) y la plantilla los renderiza como fila de íconos.
- Si un producto no tiene un patrón reconocible para diámetro o mecanismo, ese campo se
  omite para ese producto (metafield queda sin setear) — la fila de íconos sale más corta
  para ese producto, no rompe el layout ni se inventa un valor.
- Alcance: los 12 productos con `status:active` al momento de este spec. Productos
  nuevos que se agreguen después no tienen estos metafields hasta correr el script de
  nuevo (fuera de alcance de este pase — nota para el usuario, no bloqueante).

### 3. Acordeón (reemplaza el bloque de texto plano `text_aEtTtq`)

Usa el mismo tipo de bloque `accordion` / `_accordion-row` que ya existe en la sección de
FAQ del homepage (`section_9GaLYJ`) — no es un componente nuevo para el tema, es reutilizar
uno ya probado.

Tres ítems, mismo para los 12 productos (a nivel de plantilla):

1. **"Descripción del producto"** — contenido: `{{ closest.product.description }}` (el
   mismo texto que ya existe hoy, ahora colapsable, abierto por defecto).
2. **"Envío"** — texto estático tomado literalmente del FAQ real ya publicado en el
   homepage: "Llegamos a todos los rincones del país, con un tiempo estimado de 3 a 7
   días hábiles una vez procesado tu pedido. Por compras de +500.000gs el delivery es
   gratis." (combina las respuestas ya existentes de envío + la promo del marquee,
   sin inventar información nueva.)
3. **"Cómo pagar"** — texto basado en el FAQ real más la política de pago confirmada por
   el usuario (dos modalidades según tipo de entrega, no una sola): "Elegí tus productos
   y confirmá tu pedido. Dentro de un día hábil te contactamos por WhatsApp
   (+595 994702933) para confirmar disponibilidad. Si la entrega es en mano (Asunción y
   Gran Asunción), pagás al recibir tu pedido. Si el envío es por transportadora a otras
   ciudades, el pago se realiza por transferencia bancaria por adelantado, dentro de un
   plazo de 24 horas."

## Plan de ejecución (alto nivel)

Todo sobre el mismo tema `UNPUBLISHED` de restyle (`gid://shopify/OnlineStoreTheme/146834129072`) — no toca el tema publicado hasta que el usuario decida publicar (mismo patrón que el spec anterior).

1. Modificar `templates/product.json`: insertar bloque de confianza + fila de specs +
   reemplazar el bloque de texto plano por el acordeón de 3 ítems.
2. Script de extracción: leer las descripciones de los 12 productos activos, extraer
   diámetro/mecanismo, y escribir los 3 metafields (`estado`, `diametro`, `mecanismo`)
   por producto vía `metafieldsSet`.
3. Verificación: re-fetch de `templates/product.json` y de los metafields de al menos 2
   productos (uno donde la extracción debería funcionar, uno donde probablemente no) para
   confirmar el comportamiento de "campo faltante = fila más corta, no error".
4. Verificación visual: abrir 2-3 páginas de producto en el preview del tema y
   screenshot — confirmar que el acordeón colapsa/expande, que el bloque de confianza y
   la garantía se leen bien con la paleta Marfil/Noir, y que la fila de specs no rompe
   layout en el producto sin diámetro/mecanismo detectado.

## Riesgos / notas

- La extracción de diámetro/mecanismo es best-effort sobre texto libre — se acepta que
  algunos de los 12 productos queden sin esos dos campos. No se debe inventar un valor
  para completar la fila.
- Publicar el tema sigue siendo una acción aparte, gateada por confirmación explícita del
  usuario (igual que en el spec de restyle) — este spec no publica nada por sí solo.
