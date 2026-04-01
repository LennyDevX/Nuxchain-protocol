---
name: agent-factory-routing
description: 'Use when editing or validating NuxAgentFactory, category templates, factory mint routing, batch minting, fee forwarding, or category contract wiring for AI agent NFTs. Usa esta skill para controlar el flujo completo de mint desde factory a category NFTs.'
argument-hint: 'Describe el cambio en factory, category routing, templates, fees o batch mint'
---

# Agent Factory Routing

## Outcome
- Mantiene correcto el flujo de mint desde `NuxAgentFactory` hasta los category NFTs.
- Valida defaults, routing, permisos del factory y estadisticas derivadas del mint.
- Evita que el usuario minta contra categorias activas a medias o mal cableadas.

## When to Use
- Cambios en `contracts/NFT/NuxAgentFactory.sol`.
- Nuevos category NFTs o ajustes en `setCategoryContract`.
- Cambios en plantillas por categoria, fees, batch mint o recipient logic.
- Problemas donde el factory emite eventos pero el NFT no queda mintado en la coleccion correcta.

## Procedure
1. Recorre el flujo real: `mintAgent` construye `AgentConfig`, resuelve defaults y delega a `mintFromFactory` del NFT de categoria.
2. Verifica que la categoria este activa y que `nftContract` no sea cero antes de cualquier mint.
3. Confirma que el factory tenga `FACTORY_ROLE` en cada category proxy relevante.
4. Revisa que el routing preserve categoria, recipient, `msg.value`, `tokenURI`, `agentURI` y configuracion de prompts/model.
5. Comprueba el comportamiento best-effort hacia registry y aseguralo como side effect no critico, no como dependencia dura del mint.
6. Valida estadisticas y superficies derivadas: `totalAgentsMinted`, `mintsByCategory`, `agentsByOwner` y eventos.
7. Si cambias batch mint, verifica limites, refunds y consistencia parcial o total de fallos.
8. Usa `test/NFTs/NuxAgentFactory.cjs` como suite base y ampliala si el comportamiento nuevo lo exige.

## Decision Rules
- El factory debe simplificar el mint, no esconder configuraciones inconsistentes.
- Defaults de plantilla solo deben aplicarse cuando los campos vengan vacios, no sobrescribir input explicito del usuario.
- Si una categoria nueva no tiene role y wiring completos, debe considerarse no desplegada.
- Un evento de factory no sustituye una verificacion de ownership y balance en el NFT de destino.

## Completion Criteria
- El mint enruta a la coleccion correcta.
- Las plantillas y fees resuelven como se espera.
- Roles, eventos y estadisticas quedan alineados.
- La suite de tests relevante cubre routing, fallos de wiring y bordes del batch.
