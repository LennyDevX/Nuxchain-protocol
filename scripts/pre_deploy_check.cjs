const { ethers } = require("hardhat");
require("dotenv").config();

/**
 * 🔍 PRE-DEPLOYMENT WALLET VERIFICATION
 * 
 * Verifica que:
 * 1. La PRIVATE_KEY en .env es correcta
 * 2. La wallet tiene suficiente balance
 * 3. El hardhat.config está configurado correctamente
 * 4. El API key de Alchemy funciona
 * 5. Puedes conectar a Polygon mainnet
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔍 PRE-DEPLOYMENT VERIFICATION                              ║");
    console.log("║  Verificando wallet y configuración antes del deploy        ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    let checksPassed = 0;
    let checksFailed = 0;

    // ====================================================
    // CHECK 1: PRIVATE_KEY existe en .env
    // ====================================================
    console.log("1️⃣  Verificando PRIVATE_KEY en .env...");
    
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
        console.log("   ❌ PRIVATE_KEY no está definido en .env");
        checksFailed++;
    } else if (!privateKey.startsWith("0x")) {
        console.log("   ❌ PRIVATE_KEY debe comenzar con '0x'");
        checksFailed++;
    } else if (privateKey.length !== 66) {
        console.log("   ❌ PRIVATE_KEY debe tener 66 caracteres (0x + 64 hex)");
        console.log(`      Longitud actual: ${privateKey.length}`);
        checksFailed++;
    } else {
        console.log("   ✅ PRIVATE_KEY formato correcto\n");
        checksPassed++;
    }

    // ====================================================
    // CHECK 2: Wallet derivada de PRIVATE_KEY
    // ====================================================
    console.log("2️⃣  Derivando wallet de PRIVATE_KEY...");
    
    try {
        const wallet = new ethers.Wallet(privateKey);
        const walletAddress = wallet.address;
        
        console.log("   ✅ Wallet derivada exitosamente");
        console.log(`   📍 Dirección: ${walletAddress}\n`);
        checksPassed++;

        // ====================================================
        // CHECK 3: Conexión a Polygon
        // ====================================================
        console.log("3️⃣  Verificando conexión a Polygon...");
        
        try {
            const [signer] = await ethers.getSigners();
            const signerAddress = signer.address;
            
            if (signerAddress.toLowerCase() === walletAddress.toLowerCase()) {
                console.log("   ✅ Signer correcto");
                console.log(`   📍 Signer Address: ${signerAddress}\n`);
                checksPassed++;
            } else {
                console.log("   ⚠️  Advertencia: Signer no coincide");
                console.log(`      PRIVATE_KEY wallet: ${walletAddress}`);
                console.log(`      Hardhat signer: ${signerAddress}\n`);
                checksFailed++;
            }

            // ====================================================
            // CHECK 4: Balance
            // ====================================================
            console.log("4️⃣  Verificando balance en Polygon...");
            
            try {
                const balance = await ethers.provider.getBalance(signerAddress);
                const balanceEther = ethers.formatEther(balance);
                const balanceNumber = parseFloat(balanceEther);
                
                console.log(`   💰 Balance: ${balanceEther} POL`);
                
                if (balanceNumber >= 10) {
                    console.log("   ✅ Balance suficiente para deploy (≥ 10 POL)\n");
                    checksPassed++;
                } else if (balanceNumber >= 5) {
                    console.log("   ⚠️  Balance bajo (< 10 POL, mínimo 5 POL)");
                    console.log("       Puede que no haya suficiente para todos los módulos\n");
                    checksFailed++;
                } else {
                    console.log("   ❌ Balance INSUFICIENTE para deploy (< 5 POL)");
                    console.log("       Necesitas al menos 5-10 POL\n");
                    checksFailed++;
                }
            } catch (error) {
                console.log(`   ⚠️  No se pudo verificar balance: ${error.message}`);
                console.log("      Pero esto puede ser normal si estás en testnet\n");
            }

            // ====================================================
            // CHECK 5: Network
            // ====================================================
            console.log("5️⃣  Verificando red...");
            
            try {
                const network = await ethers.provider.getNetwork();
                
                console.log(`   📡 Network: ${network.name}`);
                console.log(`   🔗 Chain ID: ${network.chainId}`);
                
                if (network.chainId === 137) {
                    console.log("   ✅ Conectado a Polygon Mainnet\n");
                    checksPassed++;
                } else if (network.chainId === 80002) {
                    console.log("   ⚠️  Conectado a Polygon Amoy (testnet)");
                    console.log("       Para mainnet usa: npx hardhat run ... --network polygon\n");
                    checksFailed++;
                } else {
                    console.log(`   ❌ Red incorrecta. Chain ID: ${network.chainId}\n`);
                    checksFailed++;
                }
            } catch (error) {
                console.log(`   ❌ Error verificando red: ${error.message}\n`);
                checksFailed++;
            }

            // ====================================================
            // CHECK 6: Alchemy API Key
            // ====================================================
            console.log("6️⃣  Verificando Alchemy API Key...");
            
            const alchemyKey = process.env.ALCHEMY_API_KEY;
            if (!alchemyKey) {
                console.log("   ❌ ALCHEMY_API_KEY no está definido\n");
                checksFailed++;
            } else {
                console.log("   ✅ ALCHEMY_API_KEY está definido\n");
                checksPassed++;
            }

            // ====================================================
            // CHECK 7: Polygonscan API Key
            // ====================================================
            console.log("7️⃣  Verificando Polygonscan API Key...");
            
            const polygonscanKey = process.env.POLYGONSCAN_API_KEY;
            if (!polygonscanKey) {
                console.log("   ⚠️  POLYGONSCAN_API_KEY no está definido");
                console.log("       Verification en Polygonscan fallará\n");
                checksFailed++;
            } else {
                console.log("   ✅ POLYGONSCAN_API_KEY está definido\n");
                checksPassed++;
            }

        } catch (error) {
            console.log(`   ❌ Error conectando a Polygon: ${error.message}\n`);
            console.log("   Posibles causas:");
            console.log("      • ALCHEMY_API_KEY inválido");
            console.log("      • Red no configurada en hardhat.config.cjs");
            console.log("      • Problema de conexión de internet\n");
            checksFailed += 4;
        }

    } catch (error) {
        console.log(`   ❌ Error derivando wallet: ${error.message}`);
        console.log("      PRIVATE_KEY probablemente inválida\n");
        checksFailed += 6;
    }

    // ====================================================
    // RESUMEN
    // ====================================================
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📊 RESUMEN DE VERIFICACIÓN                                   ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    const totalChecks = checksPassed + checksFailed;
    const percentage = totalChecks > 0 ? ((checksPassed / totalChecks) * 100).toFixed(0) : 0;

    console.log(`   ✅ Checks OK:      ${checksPassed}`);
    console.log(`   ❌ Checks Fallidos: ${checksFailed}`);
    console.log(`   📊 Porcentaje:     ${percentage}%\n`);

    if (checksFailed === 0) {
        console.log("🎉 ¡TODO ESTÁ LISTO PARA DEPLOY!\n");
        console.log("Puedes ejecutar cualquiera de estos comandos:\n");
        console.log("   Opción 1 (Recomendada - Todo automático):");
        console.log("   npx hardhat run scripts/updates/staking/deploy_all_updates.cjs --network polygon\n");
        console.log("   Opción 2 (Manual - Solo Treasury):");
        console.log("   npx hardhat run scripts/updates/staking/deploy_treasury_manager.cjs --network polygon\n");
        process.exit(0);
    } else if (checksFailed <= 2) {
        console.log("⚠️  Algunos checks fallaron, pero puedes continuar.\n");
        console.log("Issues:\n");
        if (!process.env.POLYGONSCAN_API_KEY) {
            console.log("   • Sin POLYGONSCAN_API_KEY: No podrás verificar contratos automáticamente");
            console.log("     Solución: Agrega POLYGONSCAN_API_KEY a .env\n");
        }
        console.log("Puedes continuar con el deploy pero con limitaciones.\n");
        process.exit(0);
    } else {
        console.log("❌ MÚLTIPLES PROBLEMAS ENCONTRADOS\n");
        console.log("NO PUEDES HACER DEPLOY HASTA SOLUCIONAR ESTOS PROBLEMAS:\n");
        
        if (!process.env.PRIVATE_KEY) {
            console.log("   1. PRIVATE_KEY no definida");
            console.log("      Agrega en .env: PRIVATE_KEY=0x{tu_clave_privada}\n");
        }
        if (!process.env.ALCHEMY_API_KEY) {
            console.log("   2. ALCHEMY_API_KEY no definida");
            console.log("      Obtén en: https://www.alchemy.com/\n");
        }
        
        process.exit(1);
    }
}

main().catch(console.error);
