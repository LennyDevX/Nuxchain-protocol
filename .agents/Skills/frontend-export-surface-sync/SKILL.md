---
name: frontend-export-surface-sync
description: 'Use when ABI names, deployed addresses, optional clients, NuxAgentView, NuxTap, or other contract surfaces change and external apps need synchronized export artifacts. Usa esta skill para mantener consistente el paquete export y la surface consumida por frontend.'
argument-hint: 'Indica el cambio de ABI, address map, cliente o contrato que debe reflejarse en export/'
---

# Frontend Export Surface Sync

## Outcome
- Mantiene `export/` sincronizado con ABIs, direcciones y clientes del protocolo.
- Evita que apps externas consuman addresses obsoletas o una surface JS distinta de la TS.
- Convierte cambios de contratos en artefactos compartidos verificables.

## When to Use
- Cambios en nombres de contratos, ABIs o direcciones desplegadas.
- Nuevos contratos de agentes o views que deban salir en el paquete compartido.
- Ajustes en `scripts/ExportABIs.cjs`, `scripts/ExportFrontendPackage.cjs`, `export/clients` o `export/config`.

## Procedure
1. Define si el cambio debe ser publico para consumidores externos o si debe permanecer interno al repo.
2. Revisa `FRONTEND_ADDRESS_MAP` en `scripts/ExportFrontendPackage.cjs` para confirmar que cada contrato expuesto tenga su ruta correcta dentro de `deployments/complete-deployment.json`.
3. Si cambias una surface opcional como `NuxAgentView` o NuxTap, conserva el comportamiento opcional y no rompas despliegues viejos sin necesidad.
4. Regenera artefactos en orden: `npm run export:abis` y despues `npm run build:export` o `npm run export:package` segun corresponda.
5. Verifica outputs generados: `export/abis/runtime.js`, `export/config/contracts.generated.json`, `export/config/contracts.generated.ts`, `export/config/contracts.generated.js`.
6. Confirma paridad entre runtime JS y surface TS, especialmente enums, helpers, addresses opcionales y clientes expuestos.
7. Si el cambio afecta consumo de frontend, revisa `export/README.md` y examples cuando sea necesario.

## Decision Rules
- No expongas un contrato en `export/` solo porque existe; debe tener una necesidad real de consumo externo.
- Un ABI actualizado con un address viejo sigue siendo una surface rota.
- Cuando el deployment manifest y el paquete export discrepan, gana la fuente de verdad verificada y se regeneran artefactos.
- Si cambias la shape del cliente, tratalo como cambio de API y comprueba impactos aguas abajo.

## Completion Criteria
- El paquete `export/` refleja el estado actual del protocolo que debe compartirse.
- ABIs, direcciones y clientes quedan alineados.
- JS y TS exponen la misma surface esperada.
- Los consumidores externos no dependen de datos stale del ultimo deploy.
