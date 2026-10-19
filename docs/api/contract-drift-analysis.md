# Auditoría de Desincronización de Contratos API v1 (Backend vs Clientes) y Propuesta de Prevención Continua

**Fecha:** 2026-10-19  
**Rama:** `chore/api-contract-drift-analysis`  
**Estado:** En progreso / Análisis e investigación técnica

---

## 1. Resumen Ejecutivo

Este documento presenta el análisis exhaustivo de desincronización entre la API v1 (Rails) y sus clientes móviles (iOS SwiftUI y Android KMP/Compose), así como la propuesta técnica para implementar un mecanismo automatizado de prevención continua que garantice que ningún desajuste de contrato pase a producción sin ser detectado por CI.

---

## 2. Diagnóstico del Estado Actual: Medición Exacta de Desajustes

*(En investigación activa: extrayendo endpoints, serializadores backend, modelos DTO en iOS y DTO en KMP)*

---

## 3. Mapeo de Envelopes por Endpoint

*(En catalogación: `data`/`meta` vs `<recurso>`/`pagination`)*

---

## 4. Clasificación y Priorización de Desajustes

*(Categorización según impacto en usuario: P0 Crítico / P1 Alto / P2 Medio / P3 Inofensivo)*

---

## 5. Análisis de Causa Raíz

*(Por qué los tests unitarios y de DTO actuales son ciegos al drift del backend)*

---

## 6. Evaluación de Alternativas Arquitectónicas

- **Opción A:** Golden JSON Fixtures generadas desde backend consumidas en tests de clientes.
- **Opción B:** Tests de contrato estrictos en backend y clientes.
- **Opción C:** Generación de DTOs desde OpenAPI specs.
- **Opción D:** CI Contract Verification Job (Linter / Schema Validator).

---

## 7. Propuesta Recomendada y Spike

---

## 8. Qué NO verifiqué

---
