---
type: aprendizaje
status: en-desarrollo
created: 2026-07-07
updated: 2026-07-07
tags: [ia, agencia, negocio, servicios]
---

# Agencias de IA

Plan de incursión: primero terminar agentes propios ([[Agente IA CD & Co]]) → usarlos como caso de estudio → vender a terceros. La tienda es el laboratorio; la agencia, el multiplicador.

## Modelo de negocio
Tres escalones de ingreso (de peor a mejor):
1. **Proyecto one-shot**: construir un agente y entregarlo. Ingreso único, soporte eterno gratis si no se pacta. Evitar como modelo principal.
2. **Setup + retainer mensual**: fee de implementación + mensualidad por hosting, mantenimiento, mejoras y monitoreo. El estándar sano: ingreso recurrente.
3. **Productizado**: mismo agente (ej: "secretaria WhatsApp para comercios") replicado a N clientes con configuración por cliente. Margen máximo, escala real. Es donde tu stack (Supabase multi-tenant + agente WhatsApp) ya apunta.

## Servicios típicos vendibles
- Agente de atención/ventas por WhatsApp (tu especialidad probada)
- Triage y respuesta de leads (velocidad de respuesta = conversión)
- Automatización interna: reportes, facturación, seguimiento de cobros (conecta con tu ERP)
- Contenido asistido por IA para redes del cliente

## Pricing (principios, no cifras)
- Cobrar por valor (ventas recuperadas, horas ahorradas), no por horas de desarrollo.
- Retainer debe cubrir: costo de tokens/API + hosting + margen + horas de soporte estimadas. Medir consumo real por cliente desde el día 1.
- Descubrimiento pagado (auditoría inicial con entregable) filtra curiosos y cobra el diagnóstico.

## Errores conocidos del rubro (evitar)
- Vender "IA mágica": prometer autonomía total → cliente decepcionado. Vender resultados acotados y medibles.
- No pactar límites de soporte → el retainer se vuelve trabajo infinito.
- Demos con caso feliz: el cliente probará el caso hostil el día 1. Probar injection y basura antes de entregar ([[Diseño de Subagentes]]).
- Depender de un solo modelo/proveedor sin plan B (cambios de pricing tipo [[Fable 5 pago por uso]] pegan directo al margen).
- Aceptar cualquier cliente: los primeros 3-5 definen el portafolio; elegir casos replicables.

## Secuencia de entrada
1. Terminar y pulir agentes propios — con métricas reales (conversión, tiempo respondido, ventas atribuidas).
2. Documentar el caso: "mi tienda vende X con un agente que costó Y/mes" — el mejor material de venta.
3. Primeros 2-3 clientes de nicho conocido (comercios retail que venden por WhatsApp) a precio fundador con testimonio pactado.
4. Productizar lo repetido; el contenido en redes ([[Contenido para Redes]]) documentando el proceso genera los leads.

## Ventaja acumulada
ERP propio + agente + tienda real = demo viviente que ninguna agencia "solo prompts" tiene. Vender el sistema completo, no el chatbot.

## Relacionado
- [[Diseño de Subagentes]], [[Dirección de Modelos IA]], [[Agente IA CD & Co]], [[Tienda Online CD & Co]]
