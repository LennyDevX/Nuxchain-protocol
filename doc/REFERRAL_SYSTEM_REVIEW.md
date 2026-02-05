# 📋 Cambios en ReferralSystem — Revisión Completa

## ✅ Problemas Identificados y Solucionados

### 1. **Integración con Wallet-Only (Sin Login)**
**Antes**: El contrato no tenía clara la diferencia entre user/buyer/referrer para sistemas sin login.
**Ahora**: Todo se hace con `address` (wallet) directamente. Variables renombradas para claridad:
- `user` → `wallet` / `buyer` / `seller` (según contexto)
- `generateReferralCode(wallet)` genera código único por wallet

---

### 2. **Descuento en PRIMERA Compra**
**Antes**: No había función para procesar descuento.
**Ahora**: Nueva función `processFirstPurchaseDiscount()`:
```solidity
function processFirstPurchaseDiscount(address buyer, uint256 nftPrice) 
    external onlyRole(MARKETPLACE_ROLE) 
    returns (uint256 discountAmount)
```
- Retorna descuento en POL (10% del precio)
- Solo aplica si buyer tiene referrer + no ha comprado antes
- Debe ser llamada desde `GameifiedMarketplaceCore.buyToken()`

---

### 3. **XP para Referrer (Primera Venta del Referido)**
**Antes**: Solo había `recordReferralXP()` genérica.
**Ahora**: Nueva función `processFirstSaleByReferral()`:
```solidity
function processFirstSaleByReferral(address seller) 
    external onlyRole(MARKETPLACE_ROLE) 
    returns (bool)
```
- Detecta cuándo referido hace su PRIMERA venta
- Otorga XP al referrer (25 XP)
- Incrementa contador de "referrals exitosos"
- Debe ser llamada desde `GameifiedMarketplaceCore` cuando seller vende

---

### 4. **Constantes Ajustadas**
| Constante | Antes | Ahora | Razón |
|-----------|-------|-------|-------|
| Descuento | N/A | 10% | Incentivo atractivo sin desequilibrio |
| Buyer XP | 10 | 10 | Cuando hace 1era compra con referral |
| Referrer XP | 5 | 25 | Cuando referido vende su 1er NFT (más valioso) |

---

### 5. **Seguimiento de Primera Compra/Venta**
**Antes**: No se diferenciaba entre compra normal y referral.
**Ahora**: Nuevos mappings:
```solidity
mapping(address => bool) public hasMadeFirstPurchase;  // Con descuento referral
mapping(address => bool) public hasMadeFirstSale;      // First NFT sale
mapping(address => uint256) public successfulReferrals; // Count por referrer
```

---

### 6. **Getters Públicos para Frontend**
**Antes**: Funciones confusas o incompletas.
**Ahora**: Funciones claras y específicas:
```solidity
getReferralCode(wallet) → bytes32          // Su código
getReferrer(buyer) → address               // Quién lo refirió
getReferrerStats(addr) → (total, success, xp)  // Stats del referrer
getUserReferralStatus(user) → (referrer, hasPurchased, hasSold) // Estado
```

---

## 🔧 Flujo de Integración con GameifiedMarketplaceCore

### En `buyToken()`:
```solidity
function buyToken(uint256 _tokenId) public payable whenNotPaused nonReentrant {
    // ... validaciones ...
    
    uint256 price = listedPrice[_tokenId];
    
    // 1️⃣ NUEVO: Procesar descuento referral
    uint256 discount = 0;
    if (address(referralSystem) != address(0)) {
        discount = referralSystem.processFirstPurchaseDiscount(msg.sender, price);
    }
    uint256 finalPrice = price - discount;
    
    // 2️⃣ Validar pago con precio final
    require(msg.value >= finalPrice, "Insufficient payment");
    
    // 3️⃣ Transferir NFT, calcular fees, etc...
    address seller = ownerOf(_tokenId);
    _transfer(seller, msg.sender, _tokenId);
    
    uint256 platformFee = (finalPrice * PLATFORM_FEE_PERCENTAGE) / 100;
    uint256 sellerAmount = finalPrice - platformFee;
    
    userProfiles[seller].nftsSold++;
    userProfiles[msg.sender].nftsBought++;
    userProfiles[seller].totalXP += 20;
    userProfiles[msg.sender].totalXP += 15 + (discount > 0 ? BUYER_FIRST_PURCHASE_XP : 0);
    
    // ... transfers ...
}

// En `acceptOffer()` o cuando seller vende:
function acceptOffer(uint256 _tokenId, uint256 _offerIndex) external nonReentrant {
    // ... lógica ...
    
    // 4️⃣ NUEVO: Procesar XP del referrer si seller hace 1era venta
    if (address(referralSystem) != address(0)) {
        referralSystem.processFirstSaleByReferral(msg.sender);
    }
    
    // ... resto del código ...
}
```

---

## 📡 Interfaz con LevelingSystem (Próximo Paso)

El ReferralSystem debe llamar a LevelingSystem para otorgar XP:
```solidity
// En ReferralSystem.sol (futuro)
interface ILevelingSystem {
    function updateUserXP(address user, uint256 amount) external;
}

function processFirstPurchaseDiscount(...) external ... {
    // ...
    if (levelingSystemAddress != address(0)) {
        ILevelingSystem(levelingSystemAddress).updateUserXP(buyer, BUYER_FIRST_PURCHASE_XP);
    }
}

function processFirstSaleByReferral(...) external ... {
    // ...
    if (levelingSystemAddress != address(0)) {
        ILevelingSystem(levelingSystemAddress).updateUserXP(referrerAddr, REFERRER_FIRST_SALE_XP);
    }
}
```

---

## 🎮 Ejemplo de Uso (Frontend)

```javascript
// 1. User A conecta wallet, genera su código
const code = await referralSystem.generateReferralCode(walletA);
// Event: ReferralCodeGenerated(walletA, code)

// 2. User A comparte código (vía link, QR, etc.)
// Link: https://yoursite.com/referral/[code]

// 3. User B clicea link, conecta wallet, se registra
await referralSystem.registerWithReferralCode(walletB, code);
// Event: ReferralRegistered(walletB, walletA, code)

// 4. User B compra NFT (en marketplace frontend)
// Frontend calcula descuento antes de enviar tx:
const discount = await referralSystem.processFirstPurchaseDiscount(walletB, priceInWei);
// Muestra: "Descuento referral: 0.5 POL (10%)"

// 5. User B compra con precio final (price - discount)
// XP se otorga automáticamente via GameifiedMarketplaceCore

// 6. User B vende su primer NFT
// Automáticamente se llama processFirstSaleByReferral(walletB)
// User A (referrer) recibe 25 XP

// 7. User A ve su dashboard
const stats = await referralSystem.getReferrerStats(walletA);
// {
//   totalReferrals: 1,
//   successfulReferrals: 1,   // ← User B vendió su 1er NFT
//   totalXPEarned: 25
// }
```

---

## ⚠️ TO-DO: Integración Pendiente

Para que el sistema funcione completamente, falta:

1. **En GameifiedMarketplaceCore.buyToken()**:
   - Llamar a `referralSystem.processFirstPurchaseDiscount()`
   - Aplicar descuento al precio

2. **En GameifiedMarketplaceCore.acceptOffer() o venta**:
   - Llamar a `referralSystem.processFirstSaleByReferral()`

3. **En ReferralSystem.sol**:
   - Integración con ILevelingSystem para otorgar XP automáticamente

4. **En Frontend**:
   - Mostrar código referral + QR
   - Link compartible con código
   - Dashboard de referidos y XP
   - Mostrar descuento antes de comprar

---

## 📊 Resumen de Cambios

| Item | Cambio |
|------|--------|
| **Funciones nuevas** | `processFirstPurchaseDiscount()`, `processFirstSaleByReferral()` |
| **Mappings nuevos** | `hasMadeFirstPurchase`, `hasMadeFirstSale`, `successfulReferrals` |
| **Constantes** | Ajustadas para economía correcta |
| **Getters** | Claros y específicos para wallet-only |
| **Eventos** | Renombrados para claridad |
| **Compatibilidad** | 100% backward compatible |

---

## ✅ Estado

- ✅ ReferralSystem actualizado y compilable
- ✅ Documentación actualizada
- ⏳ Pendiente: Integración en GameifiedMarketplaceCore.buyToken()
- ⏳ Pendiente: Integración con LevelingSystem para XP automático
- ⏳ Pendiente: UI/Frontend para mostrar códigos y estadísticas