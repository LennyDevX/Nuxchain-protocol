---
name: agent-prompts-and-metadata
description: 'Use when editing AI agent NFT metadata, AgentConfig, tokenURI, agentURI, ERC-7662 prompt fields, encrypted prompt handling, category template defaults, or Gemini model configuration in NuxChain. Usa esta skill para mantener limpia la superficie de prompts y metadata de agentes.'
argument-hint: 'Describe el cambio en prompts, metadata NFT, agentURI, modelo o template por categoria'
---

# Agent Prompts And Metadata

## Outcome
- Mantiene separadas y coherentes las superficies de metadata del NFT y del agente.
- Evita confundir `tokenURI`, `agentURI`, `systemPromptURI`, `userPromptURI`, `model` y flags de cifrado.
- Conserva la semantica ERC-7662 y ERC-8004 sin filtrar datos sensibles por error.

## When to Use
- Cambios en `INuxAgentNFT.AgentConfig`, `NuxAgentNFTBase`, `NuxAgentFactory` o category templates.
- Ajustes en prompts IPFS, cifrado, modelos Gemini, defaults por categoria o URIs de registro.
- Trabajo sobre `NuxAgentView` o cualquier surface que exponga datos del agente.

## Procedure
1. Separa responsabilidades antes de editar:
   - `tokenURI`: metadata visual y comercial del NFT.
   - `agentURI`: registro ERC-8004 del agente.
   - `systemPromptURI` y `userPromptURI`: referencias de prompts ERC-7662.
   - `model` y `geminiConfig`: comportamiento operativo del agente.
2. Verifica si el cambio vive en el factory, en el base contract o en una vista. No dupliques defaults en varios puntos sin una razon fuerte.
3. Mantén el principio de no poner prompts sensibles en claro on-chain si el diseño dice que deben ser URIs cifradas o referencias externas.
4. Revisa que los templates por categoria sigan alineados con el perfil funcional del agente y con el modelo esperado.
5. Si alteras nombres de campos, structs o getters, revisa tests, views y consumidores del paquete export.
6. Confirma que las rutas de mint sigan poblando `mintedAt`, `state`, `agentURI` y royalties como parte del setup base.

## Decision Rules
- No mezcles metadata de experiencia de usuario con metadata operativa del agente.
- Si un dato puede rotar sin remint, considera si debe vivir en registry o en una superficie actualizable, no en un tokenURI fijo.
- Los defaults del factory deben ser explicitos y predecibles, no magia oculta.
- Si una mejora en prompts exige cambiar export o view surfaces, tratalo como cambio de API.

## Completion Criteria
- La semantica de cada URI y campo operativo sigue clara.
- No se introducen leaks evidentes de prompts sensibles.
- Factory, base, views y export surface siguen alineados.
- El comportamiento nuevo puede comprobarse con tests o lecturas concretas.
