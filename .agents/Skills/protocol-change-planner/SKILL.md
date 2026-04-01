---
name: protocol-change-planner
description: 'Use when planning Solidity protocol changes, refactors, new features, or multi-contract updates before editing code. Usa esta skill para cambios en contratos, storage, APIs, modulos, pruebas, despliegue y blast radius en NuxChain.'
argument-hint: 'Describe el feature, contratos objetivo, restricciones, riesgo y resultado esperado'
---

# Protocol Change Planner

## Outcome
- Produce un plan de cambio verificable antes de editar codigo.
- Delimita alcance, blast radius, riesgos de upgrade, pruebas y despliegue.
- Decide si el cambio debe resolverse con un flujo simple o con una coordinacion mas amplia.

## When to Use
- Nueva feature en Solidity o Hardhat.
- Refactor de varios contratos.
- Cambio en interfaces, eventos, errores custom o structs.
- Trabajo que pueda tocar storage, roles, scripts, export o documentacion tecnica.

## Procedure
1. Establece ground truth. Lee contratos, interfaces, tests, scripts y direcciones relacionadas antes de proponer cambios.
2. Clasifica el tipo de cambio: view-only, state mutation, tokenomics, access control, upgrade, deployment wiring o external surface.
3. Mapea el blast radius. Identifica contratos afectados en `contracts/`, suites en `test/`, scripts en `scripts/`, artefactos en `deployments/` y paquete compartido en `export/`.
4. Elige la solucion mas simple que cierre el problema. Si un ajuste local sirve, no escales a un rediseño.
5. Lista invariantes que no deben romperse: balances, caps, access control, pausas, eventos, compatibilidad ABI, limites de bytecode y compatibilidad de upgrade.
6. Decide skills complementarias. Si hay storage o proxy, usa `uups-upgrade-safety`. Si hay riesgo de EIP-170, usa `contract-size-budget-guard`. Si cambia wiring o roles, usa `protocol-wiring-and-roles`.
7. Define verificacion minima. Incluye compilacion, pruebas focalizadas, checks de despliegue y lecturas on-chain o simuladas segun el caso.
8. Solo despues de ese mapa, ejecuta la implementacion.

## Decision Rules
- Si el cambio toca variables de estado, structs persistentes o herencia upgradeable, tratalo como cambio de upgrade aunque parezca pequeno.
- Si el cambio modifica formulas, recompensas, fees o splits, invoca `protocol-economics-invariants`.
- Si el cambio cruza dos o mas modulos, exige plan de integracion y no solo cambios locales.
- Si no puedes nombrar una prueba o comprobacion concreta para validar el cambio, el plan aun no esta listo.

## Completion Criteria
- Existe una lista explicita de archivos, contratos y scripts impactados.
- Hay invariantes y riesgos enumerados antes de editar.
- La estrategia de validacion esta definida por adelantado.
- El cambio se puede describir como una secuencia pequena y verificable de pasos.
