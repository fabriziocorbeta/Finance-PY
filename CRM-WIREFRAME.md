# CRM - Wireframe de Diseño

Este documento describe la estructura inicial (wireframe) para el CRM - Dashboard según lo solicitado en el issue CDC-25.

## 1. Pantalla de Login

### Elementos Visuales:
- **Logo**: Posicionado en la esquina superior izquierda o centrado en la parte superior
- **Formulario de acceso**: Centrado en la pantalla con ancho máximo de 400px
- **Campos de entrada**:
  - Email/Usuario: Input tipo email con placeholder "Correo electrónico"
  - Contraseña: Input tipo password con placeholder "Contraseña"
- **Botón de acceso**: Botón primario ancho completo con texto "Iniciar Sesión"
- **Enlaces auxiliares**:
  - "¿Olvidó su contraseña?" (al lado o debajo del botón)
  - Versión de la aplicación (footer)

### Estilos y Colores:
- Fondo: Degradado suave o imagen corporativa de bajo contraste
- Formulario: Fondo blanco con sombra sutil para elevación
- Inputs: Borde gris claro, foco con color primario (#3498db)
- Botón: Fondo azul corporativo (#3498db), texto blanco, hover con tono más oscuro
- Tipografía: Fuente sans-serif legible (ej: Inter, Roboto, Open Sans)

### Flujo:
1. Usuario ingresa credenciales
2. Al hacer click en "Iniciar Sesión", se valida en backend
3. En caso de éxito, redirección al Dashboard principal
4. En caso de error, mensaje de alerta debajo del formulario

## 2. Panel Principal (Dashboard) con Métricas Clave de Ventas

### Layout General:
- **Sidebar izquierda** (250px width): Navegación principal
- **Main content derecha**: Área de trabajo principal

### Sidebar:
- Logo de la empresa en la parte superior
- Menú de navegación vertical:
  - Dashboard (activo)
  - Clientes
  - Ventas
  - Reportes
  - Configuración
- Cada ítem con ícono y texto
- Estado activo resaltado con color primario

### Header (en main content):
- Título de la página: "Panel de Control"
- Información de usuario:
  - Avatar (iniciales o foto)
  - Nombre completo
  - Rol/posición (ej: "VP of Engineering")
  - Indicador de estado (online/away)

### Métricas Clave (Grid de tarjetas):
Disposición en grid responsivo (1 columna en móvil, 2-4 columnas en desktop):

#### Tarjeta 1: Leads Mensuales
- Ícono: + o silueta de persona con signo más
- Título: "Leads Mensuales"
- Valor principal: Número formateado (ej: 1,245)
- Indicador de cambio: Flecha verde/roja con porcentaje vs período anterior
- Color temático: Azul primario

#### Tarjeta 2: Tasa de Conversión
- Ícono: Checkmark o porcentaje
- Título: "Tasa de Conversión"
- Valor principal: Porcentaje con un decimal (ej: 24.5%)
- Indicador de cambio: Flecha verde/roja con porcentaje vs período anterior
- Color temático: Verde éxito

#### Tarjeta 3: Ingresos Generados
- Ícono: Símbolo de dólar o gráfico creciente
- Título: "Ingresos Generados"
- Valor principal: Moneda formateada (ej: $45,200)
- Indicador de cambio: Flecha verde/roja con porcentaje vs período anterior
- Color temático: Amarillo advertencia

#### Tarjeta 4: Clientes Activos
- Ícono: Grupo de personas o usuario
- Título: "Clientes Activos"
- Valor principal: Número formateado (ej: 89)
- Indicador de cambio: Flecha verde/roja con porcentaje vs período anterior
- Color temático: Rojo peligro

### Sección de Actividades Recientes:
- Título: "Actividades Recientes"
- Lista de elementos con:
  - Ícono circular coloreado según tipo de actividad
  - Contenido:
    - Subtítulo (tipo de actividad)
    - Descripción breve
    - Timestamp relativo (ej: "Hace 5 minutos")
  - Divisor fino entre elementos
  - Último elemento sin border-bottom

#### Tipos de Actividad y Colores:
- Primario (azul): Nuevos leads, mensajes
- Éxito (verde): Ventas completadas, pagos recibidos
- Advertencia (amarillo): Reuniones, llamadas programadas
- Información (gris): Actualizaciones del sistema

## 3. Vista de Gestión de Clientes (Contactos)

### Layout General:
- Mantiene el mismo sidebar y header que el Dashboard
- Área principal adaptada para gestión de contactos

### Header Específico:
- Título: "Gestión de Clientes"
- Botón de acción primaria: "+ Nuevo Cliente" (alineado a la derecha)
- Campos de búsqueda y filtros:
  - Input de búsqueda amplio con placeholder "Buscar clientes..."
  - Selector de filtros rápidos (Activos, Inactivos, Prospectos, etc.)
  - Selector de ordenación (Nombre A-Z, Fecha reciente, Valor alto-bajo)

### Lista/Tabla de Clientes:
Opción A: Vista de Tarjetas (para segmentación visual)
- Grid responsivo de tarjetas de cliente
- Cada tarjeta muestra:
  - Avatar del cliente o iniciales
  - Nombre completo
  - Empresa/Organización (si aplica)
  - Último contacto o estado
  - Valor potencial o historial de compras
  - Botones de acción rápidos (Llamar, Email, Ver detalle)

Opción B: Vista de Tabla Tradicional (para datos densos)
- Encabezados de columna:
  - Avatar/Iniciales
  - Nombre
  - Empresa
  - Email
  - Teléfono
  - Último contacto
  - Estado
  - Valor histórico
  - Acciones
- Filas seleccionables con highlight en hover
- Menú de acciones por fila (⋮) con opciones: Editar, Historial, Eliminar
- Paginación en la base (10-25-50-100 elementos por página)
- Información de total: "Mostrando 1-20 de 154 clientes"

### Filtros Avanzados (Expandible/Collapsible):
- Panel lateral izquierdo adicional o modal:
  - Rango de fechas de último contacto
  - Rango de valor histórico
  - Etapas del embudo de ventas
  - Fuentes de adquisición
  - Tags/categorías personalizadas
  - Propietario de cuenta (si hay equipo)

### Acciones Masivas:
- Selección múltiple de filas
- Barra de acciones que aparece al seleccionar:
  - Exportar seleccionados
  - Cambiar estado
  - Asignar propietario
  - Enviar campaña
  - Eliminar

### Estado Vacío:
- Cuando no hay resultados: Ícono grande + mensaje descriptivo + botón claro de acción
- Cuando no hay clientes: Estado vacío con guía para importar o crear primer cliente

## Consideraciones de Diseño General

### Sistema de Colores:
- Primario: #3498db (Azul corporativo)
- Secundario: #2c3e50 (Azul oscuro)
- Éxito: #27ae60 (Verde)
- Advertencia: #f39c12 (Amarillo)
- Peligro: #e74c3c (Rojo)
- Fondo: #f5f5f5 (Gris muy claro)
- Superficie: #ffffff (Blanco)
- Texto primario: #333333
- Texto secundario: #7f8c8d
- Bordes: #ecf0f1 (Gris muy claro)

### Tipografía:
- Títulos: Fuente sans-serif semi-bold o bold
- Cuerpo: Fuente sans-serif regular
- Números métricos: Fuente monoespaciada o čísalos tabulares para alineación

### Espaciado y Elevación:
- Consistencia en padding y margins (base 8px grid)
- Sombras sutiles para elevación (0 2px 10px rgba(0,0,0,0.1))
- Radio de bordes: 4-8px según componente
- Transiciones suaves para hover y estados activos (0.2s-0.3s)

### Responsividad:
- Mobile-first approach
- Sidebar colapsable a icon-only o drawer en móviles
- Grid de métricas que se adapta (1 columna móvil → 2 columnas tablet → 4 columnas desktop)
- Tabla de clientes con scroll horizontal en móviles cuando sea necesario

### Accesibilidad:
- Contraste adecuado (WCAG AA mínimo)
- Navegación teclable
- ARIA labels donde sea necesario
- Tamaño mínimo de objetivo táctil (44x44px)
- Labels asociados a inputs

Este wireframe proporciona la estructura detallada necesaria para que el Frontend Developer pueda implementar el CRM Dashboard siguiendo las especificaciones de UX/UI.