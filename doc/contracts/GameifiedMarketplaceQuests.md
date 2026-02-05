# GameifiedMarketplaceQuests — Resumen conciso

Descripción
- Módulo para crear, gestionar y completar quests dentro del Marketplace. Maneja recompensas, condiciones y minting de recompensas.

Qué puede hacer el usuario
- Crear quests (si tiene permisos)
- Reclamar recompensas tras completar condiciones
- Consultar estado de quests y recompensas

Qué puede hacer el admin
- Configurar condiciones, duración y recompensas
- Conectar el contrato core del marketplace y el sistema de staking/leveling

Interacciones
- GameifiedMarketplaceCore: registra recompensas/XP al completar quests
- Staking/Leveling: usa datos de niveles/XP para condicionantes
- Skills & Rewards: puede otorgar NFTs o XP como recompensa

Archivo fuente:
- `contracts/Marketplace/GameifiedMarketplaceQuests.sol`