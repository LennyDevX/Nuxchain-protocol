# GameifiedMarketplaceCoreV1 — Resumen conciso

Descripción
- Contrato principal del Marketplace (UUPS upgradeable) que implementa minting de NFTs, listado/venta, ofertas, likes, comentarios, royalties y sistema básico de XP/levels.

Qué hace (usuario)
- Crear NFT (single / batch)
- Listar / deslistar NFTs
- Comprar NFTs o aceptar ofertas
- Hacer / cancelar ofertas
- Dar like y comentar NFTs
- Consultar metadata, listados y perfiles de usuario

Qué hace (admins)
- Pausar/despausar el marketplace
- Configurar contratos relacionados (skills, quests, staking)
- Actualizar implementación (UUPS) mediante rol UPGRADER
- Transferir tarifas a la treasury

Interacciones con otros contratos
- LevelingSystem / Gamification: para XP y niveles (notificaciones de XP)
- ReferralSystem: (si está activo) para procesos de referidos
- Quests: crea/completa quests que otorgan recompensas y XP
- Staking: notificaciones al comprar/vender/activar skills
- Skills NFT / IndividualSkills: NFTs con skills y compra directa

Notes Técnicas
- Usa patrones UUPS — requiere funciones initializer y compatibilidad del storage para upgrades
- Mantiene compatibilidad del storage con variables heredadas y antiguas (preserva variables deprecated para evitar colisiones)
- Eventos principales: TokenCreated, TokenListed, TokenSold, OfferMade, XPGained

Consideraciones de seguridad
- Uso de OpenZeppelin (upgradeable) y roles (AccessControl)
- Reentrancy guard en funciones que transfieren fondos
- Validaciones en inputs (precios, royalties, expiración de ofertas)

Archivo fuente:
- `contracts/Marketplace/GameifiedMarketplaceCoreV1.sol`