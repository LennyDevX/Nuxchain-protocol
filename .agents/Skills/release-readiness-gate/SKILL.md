---
name: release-readiness-gate
description: 'Use when deciding go or no-go for merge, deploy, upgrade, or smart contract release. Usa esta skill para consolidar pruebas, seguridad, size, wiring, deployment readiness y riesgos residuales en una decision operativa final.'
argument-hint: 'Describe el cambio, release objetivo y criterio de salida esperado'
---

# Release Readiness Gate

## Outcome
- Emite una decision clara de go, no-go o go-with-risks.
- Consolida evidencia tecnica y operativa antes de exponer el sistema a usuarios o mainnet.
- Evita cerrar tareas con una sensacion de avance pero sin validacion suficiente.

## When to Use
- Antes de merge a una rama sensible.
- Antes de deploy o upgrade productivo.
- Antes de etiquetar una release o entregar cambios a otro equipo.

## Procedure
1. Resume el cambio en una frase: que se queria cambiar y que realmente se cambio.
2. Invoca las skills necesarias segun la naturaleza del diff: planning, debug, economics, security, upgrade, size, tests, wiring y deployment.
3. Exige evidencia minima:
   - Compilacion correcta.
   - Suites de test relevantes.
   - Sin blockers de bytecode.
   - Sin riesgos de upgrade sin resolver.
   - Wiring y roles validados si el cambio sale a cadena.
   - Verificacion y sanity checks si hubo deploy.
4. Identifica riesgos residuales, supuestos no probados y dependencias manuales.
5. Emite la decision final con razon tecnica, no con optimismo.

## Decision Rules
- Sin evidencia, no hay readiness.
- Un solo blocker de seguridad, upgrade o deployabilidad pesa mas que muchos checks verdes cosmeticos.
- Diferencia claramente entre riesgo aceptado y riesgo desconocido.
- Si el release depende de pasos manuales delicados, esos pasos forman parte del gate.

## Completion Criteria
- Existe una decision explicita: go, no-go o go-with-risks.
- La decision cita evidencia concreta.
- Los blockers y riesgos residuales quedaron enumerados.
- El equipo puede usar la salida como checklist real de release.
