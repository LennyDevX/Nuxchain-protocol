# ReferralSystem — Resumen conciso

## Descripción
Sistema de referidos **optimizado para wallet-only** (sin login convencional). Cada wallet genera un código único compartible que invita otros usuarios. Descuento en primera compra NFT + XP para ambos usuarios cuando referido vende su primer NFT.

## Flujo Principal
1. **Wallet A** conecta → genera código referral único (permanente)
2. **Wallet A** comparte código con **Wallet B**
3. **Wallet B** conecta, clicea referral link → registra código antes de **primera compra**
4. **Wallet B** compra NFT → recibe **10% descuento + 10 XP**
5. **Wallet B** vende su **primer NFT** → **Wallet A** recibe **25 XP**

## Qué hace el usuario
- Obtener su código referral único (`generateReferralCode`)
- Compartir código vía link/QR
- Registrarse con código antes de primera compra (`registerWithReferralCode`)
- Ver sus estadísticas de referidos y XP ganado

## Qué hace el admin
- Configurar dirección del LevelingSystem
- Otorgar MARKETPLACE_ROLE a GameifiedMarketplaceCore
- Monitorear estadísticas globales

## Interacciones
- **GameifiedMarketplaceCore**: llama a `processFirstPurchaseDiscount()` y `processFirstSaleByReferral()` en buyToken() y venta
- **Frontend**: muestra código, QR, estadísticas en dashboard
- **LevelingSystem**: recibe llamadas para otorgar XP (integración futura)

## Constantes (Configurables)
- `FIRST_PURCHASE_DISCOUNT_PERCENTAGE = 10` → 10% desc en 1era compra
- `BUYER_FIRST_PURCHASE_XP = 10` → XP al buyer en 1era compra
- `REFERRER_FIRST_SALE_XP = 25` → XP al referrer cuando referido vende

## Funciones Clave para Frontend

```solidity
// User - Generar código (una sola vez)
generateReferralCode(wallet) → bytes32 code

// User - Registrarse con código (antes de 1era compra)
registerWithReferralCode(buyer, code) → bool

// User - Consultar su código
getReferralCode(wallet) → bytes32

// User - Ver estado (referrer, compro, vendio)
getUserReferralStatus(user) → (referrer, hasPurchased, hasSold)

// User - Ver estadísticas de referidos
getReferrerStats(referrer) → (totalReferrals, successfulReferrals, totalXP)

// Admin - Habilitar MARKETPLACE_ROLE
grantMarketplaceRole(marketplace)
```

## Integración GameifiedMarketplaceCore

En `buyToken()`:
```solidity
// 1. Procesar descuento (si aplica)
uint256 discount = referralSystem.processFirstPurchaseDiscount(msg.sender, price);
uint256 finalPrice = price - discount;

// 2. Pagar y transferir NFT...
// 3. En la venta, procesar XP del referrer
referralSystem.processFirstSaleByReferral(seller);
```

## Archivo fuente
- `contracts/Marketplace/ReferralSystem.sol`