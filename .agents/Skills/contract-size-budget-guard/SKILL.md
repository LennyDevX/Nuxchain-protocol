---
name: contract-size-budget-guard
description: 'Use when adding features to large Solidity contracts, fighting EIP-170 runtime size limits, or deciding how to split logic into modules, libraries, or view facades. Usa esta skill para mantener bytecode desplegable sin deriva funcional.'
argument-hint: 'Indica el contrato grande, cambio propuesto y sintomas de size limit'
---

# Contract Size Budget Guard

## Outcome
- Mantiene contratos desplegables bajo el limite EIP-170.
- Evita meter mas logica en un core que ya esta al borde.
- Prioriza separaciones limpias por responsabilidad en vez de hacks opacos.

## When to Use
- Cambios en contratos grandes como cores o facades.
- Error de deploy por runtime bytecode.
- PRs que agregan funciones, eventos, wrappers o admin surface a contratos ya pesados.

## Procedure
1. Compila y mide el impacto real. Usa `npm run check:contract-sizes` cuando aplique.
2. Identifica si el crecimiento viene de logica write-path, vistas agregadas, wrappers redundantes, strings, modifiers duplicados o herencia excesiva.
3. Decide la estrategia de reduccion: extraer libreria, separar view contract, mover helpers, eliminar dead surface o simplificar branching.
4. Conserva interfaces publicas solo cuando sea necesario para compatibilidad real, no por costumbre.
5. Revisa si el cambio propuesto pertenece en otro modulo en vez de seguir inflando el core.
6. Despues de la reduccion, vuelve a medir y verifica que no se introdujo drift funcional.

## Decision Rules
- Los contratos cercanos a 24576 bytes deben tratarse como presupuestos limitados, no como cajon sin fondo.
- Las funciones view complejas suelen ser candidatas a split antes que el write-path critico.
- No cambies una arquitectura clara por micro-optimizaciones ilegibles si una separacion modular resuelve el problema.
- Si una feature pequena consume demasiado presupuesto, probablemente esta en el modulo equivocado.

## Completion Criteria
- El contrato objetivo queda bajo limite o el bloqueo queda documentado como release blocker.
- La estrategia de split es coherente con la arquitectura del repo.
- No hay wrappers muertos ni superficie admin innecesaria agregada.
- Hay evidencia de medicion antes y despues.
