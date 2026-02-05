# EnhancedSmartStaking (módulos) — Resumen conciso

Descripción
- Conjunto modular de contratos para staking, recompensas, skills y gamification.
- Módulos principales: Core, Rewards, Skills, Gamification, View.

Qué puede hacer el usuario
- Stake tokens, reclamar recompensas, activar skills
- Consultar balances y status via `View` contract

Admin
- Configurar tasas, pools, y parámetros de recompensas
- Integrar con marketplace para notificaciones y sinergias

Interacciones
- Marketplace: sincronización de eventos (ventas, activaciones) y uso de skills
- Leveling/Quests: otorga XP por acciones vinculadas al staking

Archivos fuente:
- `contracts/SmartStaking/*`