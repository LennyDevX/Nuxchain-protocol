---
name: agent-runtime-integration
description: 'Use when integrating AI agent NFTs with registry, minigames, rentals, paymaster logic, NuxTap agent marketplace, supported NFT lists, or operational roles. Usa esta skill para validar integraciones runtime alrededor de los agent NFTs.'
argument-hint: 'Describe el flujo runtime: minigame, rental, marketplace, paymaster, view o roles implicados'
---

# Agent Runtime Integration

## Outcome
- Asegura que los agent NFTs funcionen dentro del ecosistema operativo y no solo como ERC-721 aislados.
- Valida wiring, roles, listas de NFTs soportados y side effects de reputacion, tasks o settlement.
- Detecta integraciones quebradas entre registry, NuxTap y modulos auxiliares.

## When to Use
- Cambios en `NuxAgentMiniGame`, `NuxAgentRental`, `NuxAgentPaymaster`, `NuxAgentView` o `NuxTapAgentMarketplace`.
- Nuevas integraciones entre agent NFTs y juegos, marketplace, rentals o servicios de ejecucion.
- Reconfiguracion de contratos soportados o roles despues de deploy.

## Procedure
1. Dibuja el flujo runtime completo: quien posee el NFT, quien usa la TBA, quien registra tareas, quien cobra y quien reparte permisos.
2. Verifica prerequisitos de registry: NFT contracts registrados, roles `GAME_ROLE` o `VALIDATOR_ROLE` cuando hagan falta, y agent wallets coherentes.
3. Confirma contratos soportados en surfaces runtime, por ejemplo `setSupportedNFTContract` en NuxTap si el flujo depende de whitelist.
4. Revisa settlement y side effects: record de tareas, reputacion, revenue, rental state, expiries y vistas agregadas.
5. Prueba el flujo extremo a extremo con las suites mas cercanas: `test/NFTs/NuxAgentMiniGame.cjs`, `test/NFTs/NuxAgentRental.cjs`, `test/NuxTapGame.cjs`, `test/NuxTapAgentMarketplace.cjs` segun aplique.
6. Si una integracion usa identidad de agente, verifica que viaje como `nftContract + tokenId` hasta el final.

## Decision Rules
- Un contrato soportado en whitelist no prueba que tenga roles o registry wiring correctos.
- La integracion runtime se valida con flujo completo, no solo con setters exitosos.
- Si un side effect como reputation o task logging es producto visible, no debe quedar como mejor-esfuerzo silencioso sin awareness del equipo.
- Cuando una integracion toca pagos o execution wallets, trata el cambio como sensible aunque el NFT surface no cambie.

## Completion Criteria
- Roles, whitelists y registry wiring quedaron verificados.
- El flujo runtime critico funciona extremo a extremo.
- No hay deriva entre NFTs de agentes y consumidores operativos como NuxTap o rentals.
- Los tests relevantes cubren el comportamiento realmente afectado.
