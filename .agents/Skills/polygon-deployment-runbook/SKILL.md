---
name: polygon-deployment-runbook
description: 'Use when deploying, upgrading, configuring, or verifying NuxChain contracts on Polygon. Usa esta skill para release operacional con prechecks, deploy, configure, verify, sanity checks y sincronizacion de artefactos.'
argument-hint: 'Indica si haras deploy nuevo, upgrade, configure, verify o release completo en Polygon'
---

# Polygon Deployment Runbook

## Outcome
- Ejecuta despliegues y upgrades con un flujo operativo repetible.
- Reduce errores de entorno, wiring y verificacion.
- Deja evidencia final de direcciones, verificaciones y sanity checks.

## When to Use
- Deploy o upgrade en Polygon.
- Reconfiguracion post-deploy.
- Verificacion en PolygonScan.
- Preparacion de un release real del protocolo.

## Procedure
1. Valida entorno: RPC, claves, red, saldo operativo, direcciones criticas y artefactos compilados.
2. Compila y, si el cambio toca contratos grandes, ejecuta `npm run check:contract-sizes`.
3. Ejecuta preflight cuando corresponda: `npx hardhat run scripts/pre_deploy_check.cjs --network polygon`.
4. Elige el camino correcto:
   - Deploy completo: `npx hardhat run scripts/deploy.cjs --network polygon`
   - Upgrade: `npx hardhat run scripts/upgrade-uups.cjs --network polygon`
   - NuxTap surface: `npx hardhat run scripts/deploy-nuxtap.cjs --network polygon`
5. Configura el sistema: `npx hardhat run scripts/configure.cjs --network polygon`.
6. Verifica contratos: `npx hardhat run scripts/verify.cjs --network polygon`.
7. Confirma lecturas operativas clave sobre contratos o direcciones resultantes. No cierres el flujo solo con exit code 0.
8. Si cambio interfaces o direcciones consumidas externamente, regenera `export/` con `npm run build:export`.

## Decision Rules
- No ejecutes verify como sustituto de un sanity check funcional.
- Si hay upgradeable storage impact, usa primero `uups-upgrade-safety`.
- Si la configuracion requiere direcciones manuales o variables temporales, documenta el paso exacto y la reversibilidad.
- Ante discrepancias entre deploy logs y lecturas reales, gana la cadena.

## Completion Criteria
- Prechecks, deploy o upgrade, configure y verify quedaron ejecutados segun el caso.
- Las direcciones finales quedaron confirmadas en archivos y en lecturas reales.
- El sistema responde correctamente en comprobaciones basicas.
- Los artefactos compartidos quedaron sincronizados cuando aplica.
