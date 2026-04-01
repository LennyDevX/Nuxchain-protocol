---
name: protocol-economics-invariants
description: 'Use when changing APY, rewards, boosts, fees, commissions, treasury splits, mint pricing, referral math, staking multipliers, or protocol tokenomics. Usa esta skill para validar formulas, caps, limites y sostenibilidad economica.'
argument-hint: 'Describe la formula, modulo economico, cap esperado y comportamiento deseado'
---

# Protocol Economics Invariants

## Outcome
- Valida que los cambios economicos sigan siendo coherentes, sostenibles y testeables.
- Hace explicitas las formulas, caps, acumulaciones y limites.
- Obliga a comprobar extremos y combinaciones, no solo casos felices.

## When to Use
- Cambios en APY, rewards, fees o comisiones.
- Ajustes de skills, rarity, multipliers, streaks o referrals.
- Cambios en tesoreria, distribuciones, pricing o rebates.
- Cualquier PR que altere el flujo de valor del protocolo.

## Procedure
1. Escribe la formula actual y la formula propuesta en terminos operativos, no en lenguaje ambiguo.
2. Enumera invariantes duras: caps maximos, minimos, monotonicidad esperada, no doble conteo, no rewards negativas, no underfunding silencioso, no overflow semantico.
3. Identifica todas las variables y contratos que alimentan la formula.
4. Revisa si hay stacking de multiplicadores y en que orden se aplica.
5. Prueba al menos estos bordes: cero, minimo valido, maximo valido, combinacion maxima, combinacion invalida y estado pausado o desconfigurado.
6. Comprueba que eventos, vistas y reporting sigan reflejando la economia real.
7. Si el cambio altera comportamiento esperado del usuario, actualiza la narrativa tecnica en docs o comentarios donde haga falta.

## Decision Rules
- Prefiere caps explicitos a supuestos implicitos.
- Si dos modulos calculan la misma magnitud, deben compartir fuente o quedar sincronizados por prueba.
- Si un cambio mejora rendimiento economico pero complica validacion o auditabilidad, simplifica primero.
- Si no puedes explicar el peor caso numerico, el cambio no esta listo.

## Completion Criteria
- Las formulas y caps quedaron documentadas en el analisis o en pruebas.
- Existen casos de borde y de combinacion maxima.
- No hay drift entre logica write-path y funciones view.
- El resultado economico esperado se puede verificar con pruebas o lecturas concretas.
