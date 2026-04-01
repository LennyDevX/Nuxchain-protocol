---
name: smart-contract-test-backfill
description: 'Use when adding or changing Solidity behavior and you need targeted tests, regression coverage, edge cases, or integration validation. Usa esta skill para construir pruebas precisas, minimas y alineadas con el riesgo real del cambio.'
argument-hint: 'Describe el cambio, comportamiento esperado y suite o modulo afectado'
---

# Smart Contract Test Backfill

## Outcome
- Convierte cambios de comportamiento en pruebas concretas.
- Cubre happy path, bordes, permisos y regresiones reales.
- Evita suites infladas que no validan el riesgo importante.

## When to Use
- Nueva logica o bug fix.
- Refactor con riesgo de regresion.
- Cambio en permisos, configuracion, formulas o wiring.
- Cuando falta una prueba que demuestre el bug o la garantia nueva.

## Procedure
1. Escribe la matriz minima de comportamiento: caso feliz, borde, falla esperada, permisos y regresion.
2. Ubica la suite mas cercana en `test/` antes de crear un archivo nuevo.
3. Empieza por una prueba que falle por la razon correcta si estas corrigiendo un bug.
4. Usa nombres de tests que describan la garantia del sistema, no solo la funcion llamada.
5. Valida outputs relevantes: estado, eventos, errores custom, balances, rewards, timestamps o wiring.
6. Si el cambio cruza modulos, agrega al menos una prueba de integracion para comprobar el flujo completo.
7. Reejecuta la suite afectada y cualquier suite vecina con riesgo de deriva.

## Decision Rules
- Una prueba nueva debe existir para demostrar un comportamiento nuevo o una regresion bloqueada.
- No dupliques escenarios iguales con datos cosmeticos.
- Si el bug depende de configuracion o deploy, replica ese estado en la prueba en vez de fingirlo.
- Cuando la logica es economica o upgradeable, los bordes valen mas que una larga lista de happy paths.

## Completion Criteria
- El cambio tiene pruebas alineadas con el riesgo que introduce o corrige.
- Existe al menos una prueba que habria fallado antes del fix cuando corresponde.
- Las aserciones verifican comportamiento de negocio, no solo ejecucion sin revert.
- La cobertura añadida es pequena, precisa y mantenible.
