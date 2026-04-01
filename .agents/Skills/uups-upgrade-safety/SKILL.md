---
name: uups-upgrade-safety
description: 'Use when editing upgradeable contracts, storage layout, initializers, reinitializers, proxy admin flows, or UUPS deployment scripts. Usa esta skill para validar seguridad de upgrade, compatibilidad de storage y pasos de migracion.'
argument-hint: 'Describe el contrato upgradeable, cambio de storage y tipo de upgrade'
---

# UUPS Upgrade Safety

## Outcome
- Reduce el riesgo de romper proxies, storage o inicializacion.
- Fuerza una validacion explicita de layout, herencia y flujo de upgrade.
- Sale con un plan claro de migracion y verificacion posterior.

## When to Use
- Cambios en contratos UUPS o upgradeable.
- Nuevas variables de estado o reordenamientos.
- Cambios en herencia, initializers o roles de autorizacion.
- Scripts de upgrade en `scripts/upgrade-uups.cjs` o despliegues relacionados.

## Procedure
1. Confirma que el contrato objetivo es proxy/UUPS y localiza su superficie de upgrade.
2. Compara el storage antiguo y el nuevo. Solo se permite append-only salvo migracion extremadamente justificada.
3. Verifica herencia y parent initializers. Ningun parent upgradeable debe quedar sin inicializar cuando sea requerido.
4. Revisa `__gap`, structs persistentes, enums serializados y mappings anidados.
5. Comprueba autorizacion de upgrade y riesgo de bloqueo por ownership o roles mal configurados.
6. Si el cambio requiere migracion, define el paso exacto, la ventana operativa y la comprobacion posterior.
7. Valida scripts de upgrade y cualquier setter o configure step necesario tras el upgrade.
8. Ejecuta pruebas o simulaciones que confirmen que el estado previo sigue siendo legible y util.

## Decision Rules
- Nunca reordenes, borres o cambies tipo de variables persistentes en una implementacion ya desplegada.
- Si un contrato no necesita ser upgradeable, no lo compliques con hooks o reinitializers innecesarios.
- Si el cambio toca layout y no puedes demostrar compatibilidad, el default es bloquear el upgrade.
- El upgrade no termina al cambiar la implementacion; termina cuando el sistema queda configurado y validado.

## Completion Criteria
- Layout y herencia son compatibles o el riesgo queda bloqueado explicitamente.
- El flujo de initializer o migration esta definido y probado.
- El permiso de upgrade esta claro.
- Existe verificacion posterior al upgrade mediante lecturas o pruebas.
