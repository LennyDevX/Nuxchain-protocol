---
name: solidity-root-cause-debugger
description: 'Use when debugging failing tests, reverts, bad state transitions, on-chain mismatches, or broken Hardhat scripts in Solidity projects. Usa esta skill para encontrar causa raiz, reproducir fallos y aplicar fixes minimos y verificables.'
argument-hint: 'Pega el error, test fallido, revert, script roto o sintoma on-chain'
---

# Solidity Root Cause Debugger

## Outcome
- Encuentra la causa raiz demostrable de un fallo.
- Evita fixes cosmeticos o cambios especulativos.
- Sale con una reproduccion minima, un fix acotado y pruebas que lo validan.

## When to Use
- Test fallido en `test/`.
- Revert inesperado.
- Script de deploy o configure roto.
- Mismatch entre estado esperado y estado on-chain.
- Bug intermitente en flujo multi-contrato.

## Procedure
1. Reproduce el fallo con el comando mas pequeno posible. No depures sobre una descripcion vaga.
2. Captura evidencia exacta: mensaje de error, funcion, parametros, caller, contrato, red, bloque o stack si esta disponible.
3. Localiza la ruta de ejecucion real desde la entrada hasta la condicion que falla.
4. Verifica precondiciones: permisos, pausas, direcciones, cero-values, approvals, balances, indices, timestamps y configuracion de modulos.
5. Comprueba si el problema es de logica, wiring, datos de deploy, entorno o test obsoleto.
6. Formula una hipotesis unica y demuestrala con codigo, lectura de estado o test focalizado.
7. Aplica el cambio minimo que corrija la causa raiz.
8. Reejecuta la reproduccion original y despues las pruebas adyacentes con riesgo de regresion.

## Decision Rules
- Si el fallo ocurre en Polygon o contra direcciones reales, usa el estado de cadena y `deployments/complete-deployment.json` como fuente de verdad.
- Si el error aparece tras un upgrade, invoca `uups-upgrade-safety` y revisa layout, initializer y setters de configuracion.
- Si el sintoma afecta recompensas, boosts, fees o splits, invoca `protocol-economics-invariants`.
- Si el bug solo desaparece al tocar varios archivos sin una explicacion clara, aun no encontraste la causa raiz.

## Completion Criteria
- Existe una reproduccion consistente del fallo original.
- La causa raiz se puede nombrar en una frase concreta.
- El fix cambia solo lo necesario.
- Hay verificacion antes y despues del cambio.
