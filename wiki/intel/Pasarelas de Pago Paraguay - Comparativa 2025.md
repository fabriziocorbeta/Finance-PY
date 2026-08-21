---
type: intel
title: "Pasarelas de Pago Paraguay — Comparativa 2025"
created: 2026-05-05
updated: 2026-05-05
tags: [intel, payments, paraguay, upay, dinelco, pagopar, ecommerce, fintech]
status: activo
fuente: análisis contractual (T&C oficiales)
---

# Pasarelas de Pago Paraguay — Comparativa 2025

Análisis basado en términos y condiciones contractuales de UPay, Dinelco (BEPSA DEL PARAGUAY SAECA) y PagoPar (GRUPO M S.A.).

> Artefacto visual: `comparacion-pasarelas-py.html` en Desktop — 5 tabs interactivos con radar chart, barras de fees, y tabla de riesgo.

---

## Resumen Ejecutivo

| Proveedor | Fortaleza clave | Debilidad clave | Mejor para |
|-----------|----------------|-----------------|------------|
| **UPay** | Ecosistema Bancard, relación establecida | Contrato privado, precios opacos | Comercios medianos con volumen |
| **Dinelco** | AML robusto, débito automático, red Practipago | Máxima opacidad de precios | Suscripciones, cobros recurrentes |
| **PagoPar** | Precios públicos, mayor variedad de métodos, salida flexible | 100% responsabilidad contracargos, banco único (Ueno) | Startups, e-commerce, transparencia |

---

## Fees por Método de Pago

### PagoPar — Tarifario Público (único con precios publicados)

| Método | Básico (Gs.49k/mes) | Estándar (Gs.99k/mes) | Avanzado (Gs.199k/mes) |
|--------|---------------------|----------------------|------------------------|
| Débito nacional | 3.00% | 3.00% | 3.00% |
| Crédito nacional | 4.00% | 4.00% | 3.00% |
| Crédito extranjero | 4.00% | 3.80% | 3.60% |
| QR | 4.00% | 3.80% | 3.60% |
| Billeteras | 5.00% | 4.00% | 3.00% |
| CelPOS (POS móvil) | Gs.0/mes | — | — |

**Nota:** +1.91% IVA + Renta sobre comisiones de crédito.

### UPay — Estimaciones (contrato privado)
- Débito: ~3.5% | Crédito nacional: ~4.0% | Extranjeras: ~4.5%

### Dinelco — Negociado individualmente (sin tarifario público)

---

## Liquidación

| Proveedor | Frecuencia | Banco | Notas |
|-----------|-----------|-------|-------|
| UPay | 3–5 días hábiles | Varios | Negociable |
| Dinelco | Negociada | Varios | Por acuerdo contractual |
| PagoPar | **Martes y viernes 16:00** | **Solo Ueno Bank** | Banco obligatorio — punto de riesgo |

---

## Métodos de Pago Soportados

| Método | UPay | Dinelco | PagoPar |
|--------|------|---------|---------|
| Bancard Débito | ✓ | ? | ✓ |
| Bancard Crédito | ✓ | ? | ✓ |
| Tigo Money | ✓ | ✓ (Giros Tigo) | ✓ |
| Personal Pay | ✓ | — | ✓ |
| QR Interoperable | ✓ | ? | ✓ |
| Pago Express | ? | ✓ | — |
| Débito Automático | ? | ✓ (especialidad) | limitado |
| Tarjetas extranjeras | ✓ | — | ✓ |
| Red física Practipago | — | ✓ | — |

---

## Análisis de Riesgo Contractual

| Riesgo | UPay | Dinelco | PagoPar |
|--------|------|---------|---------|
| Opacidad de precios | Media | **Alta** | Baja |
| Exposición contracargos | Media | Media | **Máxima (100%)** |
| Flexibilidad de salida | Media | Media | Alta |
| Bloqueo de banco | No | No | **Sí — solo Ueno Bank** |
| Cumplimiento AML | Estándar | **Robusto (Ley 1015/97)** | Estándar |

---

## Marco Legal (todos aplican)

- **Ley 4868/2013** — Comercio Electrónico
- **Ley 1334/98** — Defensa del Consumidor
- **Ley 1015/97** — Lavado de dinero (Dinelco cita explícitamente)
- **PCI DSS** — Dinelco certifica explícitamente; otros implícito
- Jurisdicción: Asunción, Paraguay en todos los casos

---

## Score Comparativo (0–10, mayor = mejor para el comercio)

| Dimensión | UPay | Dinelco | PagoPar |
|-----------|------|---------|---------|
| Transparencia de precios | 5 | 3 | **9** |
| Fees competitivos | 5 | 5 | **7** |
| Variedad de métodos | 7 | 5 | **8** |
| Velocidad de liquidación | 6 | 5 | **7** |
| Política contracargos | 6 | **6** | 2 |
| Flexibilidad de salida | 6 | 5 | **9** |
| Integración técnica | **7** | 5 | **8** |
| Cumplimiento legal | 7 | **9** | 7 |
| **TOTAL / 80** | **49** | **43** | **57** |

*UPay scores son estimaciones — PDF del contrato privado no extraíble.*

---

## Conclusiones para Decisión

1. **PagoPar gana en transparencia y flexibilidad** — ideal si querés saber exactamente lo que pagás antes de firmar. Riesgo principal: 100% responsabilidad en contracargos y banco único Ueno.

2. **Dinelco es la opción para cobros recurrentes/débito automático** — red Practipago es infraestructura física sólida. Muy opaco en precios; requiere negociación directa. AML más robusto.

3. **UPay equilibrado pero opaco** — trayectoria como partner oficial Bancard. Requiere ver el contrato real para evaluación completa.

4. **Decisión recomendada:** PagoPar Avanzado (Gs.199k/mes) si el volumen lo justifica — fees más bajos en crédito y extranjeras, salida fácil. Exigir cláusula de contracargos compartida en negociación.

---

## Links Relacionados

- [[comparacion-pasarelas-py.html]] — artefacto interactivo en Desktop
- Fuentes: contrato UPay (privado, PDF no extraído), T&C Dinelco (texto), T&C PagoPar (texto)
