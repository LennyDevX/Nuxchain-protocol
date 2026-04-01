---
name: erc6551-account-wiring
description: 'Use when deploying, configuring, debugging, or reviewing ERC-6551 token bound accounts, implementation addresses, deterministic account derivation, or TBA mismatches across NuxChain agent NFT categories. Usa esta skill para wiring preciso de cuentas ligadas al NFT.'
argument-hint: 'Describe el contrato NFT, el implementation ERC-6551, el tokenId o el mismatch observado'
---

# ERC6551 Account Wiring

## Outcome
- Deja la capa ERC-6551 consistente entre category NFTs, implementation y cuentas ligadas al token.
- Fuerza comprobaciones sobre direccion calculada, direccion desplegada y configuracion real.
- Reduce fallos silenciosos donde el mint ocurre pero el TBA queda en cero o mal enlazado.

## When to Use
- Cambios en `contracts/NFT/NuxAgentAccount6551.sol` o `contracts/NFT/NuxAgentNFTBase.sol`.
- Configuracion o upgrade de `erc6551Implementation`.
- Errores donde distintas colecciones de agentes apuntan a implementaciones distintas.
- Revisions de mint que crean TBAs o calculan cuentas deterministicas.

## Procedure
1. Confirma la fuente de verdad del implementation desplegado en `deployments/complete-deployment.json` y las lecturas reales de cada category NFT.
2. Verifica que cada category NFT use el mismo `erc6551Implementation` esperado salvo que exista una excepcion explicita y justificada.
3. Revisa la llamada a la registry canonica `0x000000006551c19487814612e58FE06813775758` y confirma parametros: implementation, salt, `block.chainid`, contrato NFT y `tokenId`.
4. Comprueba el par `createAccount` vs `account` para distinguir entre direccion deterministica calculada y cuenta efectivamente desplegada.
5. Valida que `_tokenBoundAccounts[tokenId]` y `computeTokenBoundAccount(tokenId)` converjan cuando el flujo de mint es correcto.
6. Revisa guardas operativas relacionadas, en especial la prevencion de ownership cycles y cualquier dependencia que use la TBA como agent wallet.
7. Si detectas un mismatch, decide si el problema es de deploy, de wiring posterior, de category contract aislado o de lectura equivocada.

## Decision Rules
- No trates `tokenId` como identidad global; la cuenta esta atada a `nftContract + tokenId + chainId + implementation`.
- Un mint exitoso no prueba que la TBA haya quedado desplegada o usable.
- Si una categoria apunta a otra implementation, tratalo como incidente de wiring hasta demostrar lo contrario.
- Si la cuenta calculada es correcta pero la almacenada no, el bug esta en el flujo de mint o persistencia, no en la derivacion.

## Completion Criteria
- Las categories relevantes reportan el implementation correcto.
- La cuenta calculada y la cuenta desplegada coinciden cuando deben hacerlo.
- No hay TBAs en cero en rutas donde la feature se considera obligatoria.
- Queda claro si el problema era de codigo, upgrade, configure o datos de despliegue.
