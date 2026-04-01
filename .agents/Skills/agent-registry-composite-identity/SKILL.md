---
name: agent-registry-composite-identity
description: 'Use when changing NuxAgentRegistry, agent metadata, feedback, validation, agent wallet management, or any integration that identifies agent NFTs across multiple category collections. Usa esta skill para preservar identidad compuesta nftContract plus tokenId y evitar colisiones.'
argument-hint: 'Indica el flujo del registry, API afectada o modulo que consume identidad de agentes'
---

# Agent Registry Composite Identity

## Outcome
- Preserva la identidad compuesta `nftContract + tokenId` en toda la superficie stateful del registry.
- Previene regresiones hacia APIs o storage que dependan solo de `tokenId`.
- Fuerza coherencia entre metadata, reputation, validation y agent wallet management.

## When to Use
- Cambios en `contracts/NFT/NuxAgentRegistry.sol`.
- Integraciones con minigame, paymaster, marketplace, rentals o views que consulten estado del agente.
- Ajustes en feedback, validation requests, metadata on-chain o firma EIP-712 de `agentWallet`.

## Procedure
1. Identifica toda ruta que lea o escriba estado del agente y verifica que use `address nftContract, uint256 tokenId`.
2. Revisa mappings, eventos, firmas, hashes y claves auxiliares para confirmar que ninguna ruta vuelva a `tokenId` solo.
3. Valida `registerNFTContract` y la lista interna de contratos para no romper discovery de colecciones registradas.
4. Comprueba que `setAgentWallet`, `configureAgent`, feedback y validation mantengan el mismo modelo compuesto.
5. Si una integracion externa recibia solo `tokenId`, planifica la migracion de ABI y tests antes de tocar el core.
6. Revisa tests y callers afectados para asegurar que la nueva identidad viaje extremo a extremo.
7. Considera cualquier colision potencial entre Social, Tech, Marketing, Finance y Business cuando los token IDs empiezan en 1 en cada coleccion.

## Decision Rules
- No introduzcas APIs stateful nuevas que identifiquen al agente solo por `tokenId`.
- Si un modulo necesita una clave unica, debe derivarse del par `nftContract + tokenId`, no de supuestos externos.
- Cuando una firma, evento o hash no incluya `nftContract`, asume riesgo de colision hasta demostrar lo contrario.
- Un fix parcial en un solo modulo no vale si los consumidores aguas abajo siguen con identidad incompleta.

## Completion Criteria
- Las rutas stateful del registry usan identidad compuesta.
- No quedan colisiones plausibles entre colecciones de agentes.
- ABI, tests y consumidores relevantes quedaron adaptados.
- El cambio deja una historia clara de migracion o compatibilidad.
