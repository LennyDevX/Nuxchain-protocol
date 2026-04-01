---
name: smart-contract-security-review
description: 'Use when reviewing Solidity code for vulnerabilities, trust boundaries, privilege risks, accounting bugs, upgrade hazards, or release blockers. Usa esta skill para auditoria ligera, review de seguridad y hallazgos priorizados por severidad.'
argument-hint: 'Indica el contrato, diff, modulo o superficie a revisar'
---

# Smart Contract Security Review

## Outcome
- Produce hallazgos accionables ordenados por severidad.
- Prioriza bugs reales, riesgos de comportamiento y gaps de prueba.
- Evita revisiones superficiales basadas solo en estilo.

## When to Use
- Antes de mergear cambios sensibles.
- Antes de deploy o upgrade.
- Cuando el usuario pide una review, audit o security pass.
- En contratos con valor, privilegios o interacciones externas.

## Procedure
1. Define alcance y activos protegidos: fondos, permisos, invariantes y trust boundaries.
2. Lee primero la superficie write-path, admin-path, external calls y configuracion.
3. Busca clases de riesgo concretas: reentrancy, missing access control, privilege escalation, incorrect accounting, stale assumptions, frontrunning, DOS, griefing, unsafe external dependency, initializer misuse, storage collision, zero address footguns y event/reporting drift.
4. Revisa supuestos entre contratos: quien configura a quien, quien puede pausar, quien puede cambiar direcciones y que pasa si una dependencia queda en cero o mal configurada.
5. Contrasta cada hallazgo con evidencia: linea, ruta de ejecucion, estado requerido y impacto.
6. Pide o crea pruebas focalizadas para validar hallazgos importantes o descartar falsos positivos.
7. Entrega findings primero, preguntas abiertas despues y resumen al final.

## Decision Rules
- No marques como hallazgo algo que no puedas sostener con una ruta de explotacion o regresion creible.
- Un riesgo de upgrade o configuracion puede ser tan severo como un bug de logica.
- Los gaps de prueba importan cuando esconden comportamiento sensible, no como lista mecanica.
- Si no hay findings, deja constancia de riesgos residuales y limites de cobertura.

## Completion Criteria
- Los hallazgos estan ordenados por severidad e impacto.
- Cada finding incluye evidencia y razon tecnica.
- Se distinguen claramente bugs, riesgos operativos y gaps de test.
- Queda claro si el cambio esta listo o no para avanzar.
