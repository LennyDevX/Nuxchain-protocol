---
name: protocol-wiring-and-roles
description: 'Use when connecting contracts, setting module addresses, granting roles, configuring registries, or validating cross-contract dependencies after deploy or upgrade. Usa esta skill para revisar wiring, permisos y configuracion operacional del protocolo.'
argument-hint: 'Indica los contratos, direcciones, roles o modulos que deben quedar conectados'
---

# Protocol Wiring And Roles

## Outcome
- Garantiza que el sistema quede conectado y autorizado de forma coherente.
- Detecta dependencias faltantes, zero addresses, permisos incompletos y configuracion divergente.
- Obliga a verificar estado real, no solo scripts ejecutados.

## When to Use
- Despues de deploy o upgrade.
- Cambios en setters de modulos o registries.
- Configuracion de treasury, marketplace, NFTs, quests o staking modules.
- Problemas donde el codigo compila pero el sistema no coopera en runtime.

## Procedure
1. Dibuja el grafo minimo de dependencias: quien llama a quien, quien configura a quien y quien autoriza a quien.
2. Enumera setters, roles, ownership y permisos necesarios para que el flujo funcione.
3. Verifica direcciones reales en `deployments/addresses.json` y `deployments/complete-deployment.json` si aplica.
4. Comprueba que cada dependencia critica no sea cero, apunte al contrato correcto y exponga la interfaz esperada.
5. Ejecuta o revisa `scripts/pre_deploy_check.cjs` y `scripts/configure.cjs` cuando el cambio lo requiera.
6. Haz lecturas puntuales del estado final para confirmar wiring, no asumas que el script dejo todo bien.
7. Si cambian ABIs o surfaces consumidas externamente, recuerda regenerar `export/`.

## Decision Rules
- Un deploy exitoso no prueba configuracion correcta.
- Un rol faltante puede ser causa raiz de bugs aparentemente logicos.
- Si varias fuentes de direcciones discrepan, la fuente de verdad debe resolverse antes de seguir.
- La configuracion se valida con lecturas de contrato, no solo con logs de terminal.

## Completion Criteria
- Todas las dependencias criticas estan configuradas y verificadas.
- Los roles y ownerships necesarios quedaron confirmados.
- No hay zero addresses ni referencias obsoletas en rutas activas.
- Existe evidencia de verificacion posterior a la configuracion.
