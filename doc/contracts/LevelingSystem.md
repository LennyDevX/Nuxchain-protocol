# LevelingSystem — Resumen conciso

Descripción
- Módulo para gestionar XP, niveles y perfiles de usuario. Expone funciones para incrementar XP desde otros contratos y calcular nivel.

Usuario
- Consultar perfil (XP, nivel)

Admin
- Incrementar XP para usuarios (mediante role)
- Configurar límites y parámetros (MAX_XP, MAX_LEVEL)

Interacciones
- Marketplace & Quests: llaman a `updateUserXP` para otorgar XP
- Staking/Gamification: consulta de niveles para condiciones

Archivo fuente:
- `contracts/Marketplace/LevelingSystem.sol`