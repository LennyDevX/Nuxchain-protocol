const { ethers } = require("hardhat");
require("dotenv").config({ override: true });

/**
 * 🔍 PRE-DEPLOYMENT WALLET VERIFICATION
 * 
 * Verifica que:
 * 1. La PRIVATE_KEY en .env es correcta
 * 2. La wallet tiene suficiente balance
 * 3. El signer de Hardhat coincide con la wallet esperada
 * 4. El API key de Alchemy funciona
 * 5. Puedes conectar a Polygon mainnet
 * 6. TREASURY_ADDRESS está configurada para deploy.cjs
 */

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  🔍 PRE-DEPLOYMENT VERIFICATION                              ║");
    console.log("║  Verificando wallet y configuración antes del deploy        ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    let checksPassed = 0;
    let checksFailed = 0;
    const burnTreasuryAddress = "0x000000000000000000000000000000000000dead";

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
                
                if (network.chainId === 137n) {
                    console.log("   ✅ Conectado a Polygon Mainnet\n");
                    checksPassed++;
                } else if (network.chainId === 80002n) {
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

            // ====================================================
            // CHECK 8: Treasury address requerida por deploy.cjs
            // ====================================================
            console.log("8️⃣  Verificando TREASURY_ADDRESS...");

            const treasuryAddress = process.env.TREASURY_ADDRESS;
            if (!treasuryAddress) {
                console.log("   ❌ TREASURY_ADDRESS no está definido\n");
                checksFailed++;
            } else if (!ethers.isAddress(treasuryAddress) || treasuryAddress === ethers.ZeroAddress) {
                console.log("   ❌ TREASURY_ADDRESS no es una dirección válida\n");
                checksFailed++;
            } else if (treasuryAddress.toLowerCase() === burnTreasuryAddress) {
                console.log("   ❌ TREASURY_ADDRESS apunta a la burn address placeholder 0x...dEaD");
                console.log("      Configura la treasury real antes de desplegar en mainnet\n");
                checksFailed++;
            } else {
                console.log(`   ✅ TREASURY_ADDRESS válido: ${treasuryAddress}\n`);
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
        console.log("Flujo recomendado actual:\n");
        console.log("   1. npm exec hardhat compile");
        console.log("   2. npm run check:contract-sizes");
        console.log("   3. npm exec hardhat test");
        console.log("   4. npx hardhat run scripts/deploy.cjs --network polygon");
        console.log("   5. npx hardhat run scripts/configure.cjs --network polygon");
        console.log("   6. npx hardhat run scripts/fund.cjs --network polygon");
        console.log("   7. npx hardhat run scripts/verify.cjs --network polygon\n");
        process.exit(0);
    } else if (checksFailed <= 2) {
        console.log("⚠️  Algunos checks fallaron, pero puedes continuar.\n");
        console.log("Issues:\n");
        if (!process.env.POLYGONSCAN_API_KEY) {
            console.log("   • Sin POLYGONSCAN_API_KEY: No podrás verificar contratos automáticamente");
            console.log("     Solución: Agrega POLYGONSCAN_API_KEY a .env\n");
        }
        if (!process.env.TREASURY_ADDRESS) {
            console.log("   • Sin TREASURY_ADDRESS: scripts/deploy.cjs fallará al iniciar");
            console.log("     Solución: Agrega TREASURY_ADDRESS a .env\n");
        } else if (process.env.TREASURY_ADDRESS.toLowerCase() === burnTreasuryAddress) {
            console.log("   • TREASURY_ADDRESS apunta a 0x...dEaD, que solo sirve como placeholder");
            console.log("     Solución: reemplázala por la treasury real antes del deploy\n");
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
        if (!process.env.TREASURY_ADDRESS) {
            console.log("   3. TREASURY_ADDRESS no definida");
            console.log("      Agrega en .env la treasury destino usada por scripts/deploy.cjs\n");
        } else if (process.env.TREASURY_ADDRESS.toLowerCase() === burnTreasuryAddress) {
            console.log("   3. TREASURY_ADDRESS sigue apuntando a 0x...dEaD");
            console.log("      Reemplázala por la treasury real antes del deploy en Polygon\n");
        }
        
        process.exit(1);
    }
}

main().catch(console.error);
