Resumen de contratos: EnhancedSmartStaking & GameifiedMarketplace

Propósito general
-----------------
Este repositorio contiene dos contratos clave para la plataforma:

- EnhancedSmartStaking: contrato de staking con recompensas, lockups y capa gamificada que permite interactuar con "skill NFTs" para mejorar recompensas.

- GameifiedMarketplace: marketplace NFT centrado en "skill NFTs" (habilidades) que interactúa con el staking para habilitar features y cobrar fees en POL.

Objetivo del documento
----------------------
Explicar de forma clara y resumida cómo funcionan los contratos, qué funciones y límites tienen, cómo se aplican fees/royalties, qué skills existen y el flujo que debe seguir un usuario en la web para usar la plataforma.

1) EnhancedSmartStaking — ¿Qué hace?
------------------------------------
- Permite que usuarios hagan depósitos (staking) en ETH (o token de prueba) con distintos lockups (0, 30, 90, 180, 365 días). Los depositantes obtienen recompensas con una tasa por hora y bonos por lockup.
- Implementa límites: depósito mínimo, depósito máximo, límite diario de retiro y máximos por usuario.
- Integra skills vía NFT para aumentar recompensas, reducir lockups o habilitar auto-compounding.
- Lleva seguimiento de quests y achievements notificados por el marketplace.

Principales características
- Depósito con lockup: opciones 0/30/90/180/365 días.
- Recompensas: calculadas por tiempo y lockup, con comisión hacia el treasury.
- Auto-compound: se puede habilitar con una skill NFT.
- Notificaciones: el marketplace puede notificar quests, achievements y activaciones de skills.

Campos y límites clave (resumen)
- MIN_DEPOSIT: 5 (unidad del contrato)
- MAX_DEPOSIT: 10.000 (unidad del contrato)
- DAILY_WITHDRAWAL_LIMIT: 1.000
- Comisión (commission) por operaciones: 6% (BASE)
- Rarities y multiplicadores: COMMON → N/A, UNCOMMON → +10%, RARE → +20%, EPIC → +40%, LEGENDARY → +80% (aplican sobre boosts)

Funciones importantes (que el frontend usará)
- deposit(lockupDays)
- withdraw()
- withdrawAll()
- compound()
- getTotalDeposit(user)
- calculateRewards(user)
- calculateBoostedRewards(user)
- setMarketplaceAddress(address) — (admin)
- notifySkillActivation(user, nftId, skillType, effectValue) — llamada por marketplace
- notifyQuestCompletion(user, questId, reward) — llamada por marketplace
- getActiveSkills(user)
- getUserSkillProfile(user)

2) GameifiedMarketplace — ¿Qué hace?
------------------------------------
- Marketplace NFT enfocado en "Skill NFTs" (NFTs que contienen de 1 a N skills). Los usuarios crean NFTs y pueden incluir skills para mejorar su experiencia de staking.
- Reglas de monetización: para crear una Skill NFT el usuario debe tener al menos 200 POL en staking; el primer skill es gratis, skills adicionales tienen un fee en POL según rareza.
- Maneja listing, ofertas, compras, likes, comentarios, XP por acciones y un sistema de niveles.
- Coordina con EnhancedSmartStaking para notificar activaciones y actualizaciones de skills.

Campos y límites clave (resumen)
- MIN_POL_FOR_SKILL_NFT: 200 POL (requisito para mintear skill NFTs)
- FIRST_SKILL_FREE: 1 (el primer skill del NFT no paga fee)
- ADDITIONAL_SKILL_MIN_FEE: 25 POL
- ADDITIONAL_SKILL_MAX_FEE: 100 POL
- SKILL_CHANGE_COOLDOWN: 7 días (para cambiar skills sin pagar fee)
- SKILL_CHANGE_FEE: 10 POL (si cambias antes de cooldown)
- STAKING_REWARD_COMMISSION_PERCENTAGE: 2% (aplica en reclamaciones cruzadas)
- PLATFORM_FEE_PERCENTAGE: 5% en ventas (viene del marketplace)

Skills soportadas (resumen)
- STAKE_BOOST_I/II/III: incrementos en APY o multiplicadores de recompensa.
- AUTO_COMPOUND: activa auto-compounding para el usuario.
- LOCK_REDUCER: reduce tiempos de lockup (por ejemplo -25%).
- FEE_REDUCER_I/II: reduce fees de plataforma (ej. -10% / -25%).

Rarities
- COMMON, UNCOMMON, RARE, EPIC, LEGENDARY — afectan potencia y fees.
- Rarity probabilities al mintear el primer skill (documentado en el contrato): ejemplo: COMMON 50%, UNCOMMON 30%, RARE 12%, EPIC 6%, LEGENDARY 2%.

Fees y royalties
- Royalty: porcentaje setting al mintear (según ERC-2981). El marketplace puede asignar royalties.
- Al vender: plataforma retiene PLATFORM_FEE_PERCENTAGE (5%) y paga el resto al vendedor.
- Al crear skills: POL fees para skills adicionales enviados al staking treasury o al platform treasury según la configuración.

Funciones importantes (para el frontend)
- createSkillNFT(uri, category, royalty, skills[], effectValues[], rarities[])
- createNFT(uri, category, royalty)
- activateSkill(tokenId)
- deactivateSkill(tokenId)
- getUserActiveSkills(address)
- getSkillDetails(tokenId)
- listTokenForSale(tokenId, price)
- buyToken(tokenId)
- makeOffer(tokenId, expiresInDays)
- acceptOffer(tokenId, offerIndex)
- toggleLike(tokenId), addComment(tokenId, text)
- getUserProfile(address)

3) Flujo para un usuario común (pasos en la web)
------------------------------------------------
1. Conectar wallet (Metamask u otra).
2. Ir a "Staking" y depositar POL (o el token compatible) en el contrato EnhancedSmartStaking.
   - Elegir monto (>= 5 mínimo) y lockup (0/30/90/180/365 días).
   - Verás tu balance total (getTotalDeposit) y rewards estimados (calculateRewards).
3. Si quieres crear Skill NFT:
   - Verifica que tu balance en staking >= 200 POL (canUserCreateSkillNFT)
   - En "Crear Skill NFT" eliges URI, skills (1-5), valores y dejas que el sistema calcule la rareza/fees.
   - El primer skill del NFT es gratuito. Si agregas skills adicionales, pagarás en POL según rareza.
   - Tras mintearlo, el marketplace notifica al staking (setSkillRarity y notifySkillActivation cuando activas).
4. Activar skill:
   - En tu perfil, selecciona el NFT y presiona "Activar Skill".
   - El marketplace llama a `notifySkillActivation` en el staking para que los boosts se apliquen.
   - Si la skill es AUTO_COMPOUND, pasarás a la lista de auto-compound.
5. Uso de skills:
   - Las skills aumentan tu recompensa calculada (`calculateBoostedRewards`) o reducen lockups (`calculateReducedLockTime`) o reducen fees.
6. Cobrar recompensas:
   - Al retirar (withdraw), el staking calcula las comisiones y transferencias.
   - El marketplace puede aplicar una comisión por integrarse con staking (STAKING_REWARD_COMMISSION_PERCENTAGE).
7. Venta de NFTs:
   - Listar en marketplace, vender, recibir pago menos la comisión del 5%.
8. Quests y Achievements:
   - El marketplace puede notificar el staking cuando completes quests o desbloquees logros (`notifyQuestCompletion` / `notifyAchievementUnlocked`), lo que puede dar boosts temporales.

4) Recomendaciones para integrar en tu web
------------------------------------------
- Mostrar el balance y rewards estimados con llamadas a `getTotalDeposit` y `calculateBoostedRewards`.
- Validar creación de skill NFTs verificando `canUserCreateSkillNFT` (o directamente `getUserStakingBalance`).
- Implementar pasos claros: Deposit → Mint Skill NFT → Activate Skill → Enjoy Boosts.
- Registrar eventos desde el backend (SkillActivated, TokenCreated, Deposited) para actualizar estado y notificaciones en tiempo real.
- Manejar gracefully reverts: por ejemplo, "Insufficient staking balance" cuando el usuario no tiene 200 POL.

5) Riesgos y límites (para la comunidad)
----------------------------------------
- Contract size: la versión completa del marketplace es grande y puede requerir optimizaciones o dividir lógica al desplegar en mainnet.
- Costes: crear skills y fees en POL generan fricción económica; modela los fees según adopción.
- Seguridad: permisos admin/roles deben restringirse y auditarse (AccessControl usado).
- Expiraciones temporales: quests y achievement boosts expiran (default 30 días).

6) Preguntas frecuentes rápidas
--------------------------------
- ¿Puedo mintear skills sin staking? No. Requisito mínimo: 200 POL en staking.
- ¿Cuál es el fee por skills? Entre 25 POL (COMMON) y 100 POL (LEGENDARY) por skill adicional.
- ¿Primer skill gratis? Sí.
- ¿Cuántos skills puedo activar? Depende del level (XP) — el contrato calcula maxActiveSkills según nivel.

7) Conclusión corta (para compartir)
------------------------------------
Con estos contratos puedes ofrecer a tu comunidad un ecosistema gamificado: users stakean POL, mintean skills NFTs (con rarezas y fees), activan skills para mejorar sus rewards en staking y usan el marketplace para vender/gestionar NFTs. Integra los endpoints clave en tu frontend y escucha eventos para sincronizar la experiencia en tiempo real.
