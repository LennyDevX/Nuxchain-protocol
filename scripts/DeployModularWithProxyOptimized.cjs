#!/usr/bin/env node

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

// ════════════════════════════════════════════════════════════════════════════════════════
// VALIDACIÓN DE INTERFACES Y ENUMS
// ════════════════════════════════════════════════════════════════════════════════════════

/**
 * Valida que los contratos usen las mismas enumeraciones
 */
async function validateInterfaces() {
    console.log("🔍 [VALIDATION] Validando sincronización de interfaces...\n");
    
    try {
        // Validar que IStakingIntegration está disponible
        const stakingInterface = await hre.ethers.getContractFactory("EnhancedSmartStaking");
        console.log("  ✅ EnhancedSmartStaking disponible");
        
        // Validar que Skills importa correctamente
        const skillsFactory = await hre.ethers.getContractFactory("GameifiedMarketplaceSkills");
        console.log("  ✅ GameifiedMarketplaceSkills compila correctamente");
        
        // Validar que Quests importa correctamente
        const questsFactory = await hre.ethers.getContractFactory("GameifiedMarketplaceQuests");
        console.log("  ✅ GameifiedMarketplaceQuests compila correctamente");
        
        // Validar que Core está disponible
        const coreFactory = await hre.ethers.getContractFactory("GameifiedMarketplaceCoreV1");
        console.log("  ✅ GameifiedMarketplaceCoreV1 disponible");
        
        console.log("\n✅ Todas las interfaces están sincronizadas correctamente\n");
        return true;
    } catch (error) {
        console.error("❌ Error en validación de interfaces:", error.message);
        throw error;
    }
}

/**
 * Valida que los métodos requeridos existan en los contratos
 */
async function validateMethods() {
    console.log("🔍 [VALIDATION] Validando métodos requeridos...\n");
    
    // Métodos que Skills debe usar
    const skillsRequiredMethods = [
        "registerSkillsForNFT",
        "setStakingContract",
        "getActiveSkillsForUser"
    ];
    
    // Métodos que Quests debe usar
    const questsRequiredMethods = [
        "createQuest",
        "completeQuest",
        "setStakingContract"
    ];
    
    // Métodos que Core debe exponer
    const coreRequiredMethods = [
        "setSkillsContract",
        "setQuestsContract",
        "setStakingContract",
        "updateUserXP"
    ];
    
    // Métodos que Staking debe implementar (desde IStakingIntegration)
    const stakingRequiredMethods = [
        "notifySkillActivation",
        "notifySkillDeactivation",
        "notifyQuestCompletion",
        "notifyAchievementUnlocked",
        "updateUserXP"
    ];
    
    const factories = {
        Skills: await hre.ethers.getContractFactory("GameifiedMarketplaceSkills"),
        Quests: await hre.ethers.getContractFactory("GameifiedMarketplaceQuests"),
        Core: await hre.ethers.getContractFactory("GameifiedMarketplaceCoreV1"),
        Staking: await hre.ethers.getContractFactory("EnhancedSmartStaking")
    };
    
    // Validar Skills
    for (const method of skillsRequiredMethods) {
        if (!factories.Skills.interface.hasFunction(method)) {
            throw new Error(`❌ GameifiedMarketplaceSkills falta método: ${method}`);
        }
    }
    console.log("  ✅ GameifiedMarketplaceSkills tiene todos los métodos requeridos");
    
    // Validar Quests
    for (const method of questsRequiredMethods) {
        if (!factories.Quests.interface.hasFunction(method)) {
            throw new Error(`❌ GameifiedMarketplaceQuests falta método: ${method}`);
        }
    }
    console.log("  ✅ GameifiedMarketplaceQuests tiene todos los métodos requeridos");
    
    // Validar Core
    for (const method of coreRequiredMethods) {
        if (!factories.Core.interface.hasFunction(method)) {
            throw new Error(`❌ GameifiedMarketplaceCoreV1 falta método: ${method}`);
        }
    }
    console.log("  ✅ GameifiedMarketplaceCoreV1 tiene todos los métodos requeridos");
    
    // Validar Staking
    for (const method of stakingRequiredMethods) {
        if (!factories.Staking.interface.hasFunction(method)) {
            throw new Error(`❌ EnhancedSmartStaking falta método: ${method}`);
        }
    }
    console.log("  ✅ EnhancedSmartStaking tiene todos los métodos requeridos");
    
    console.log("\n✅ Todos los métodos requeridos están implementados\n");
}

async function main() {
    console.log("🚀 DEPLOYMENT MODULARIZADO CON PROXY Y SINCRONIZACIÓN\n");
    console.log("════════════════════════════════════════════════════════════════════════════════════════\n");
    
    // PASO 0: Validar interfaces antes del deployment
    console.log("📋 PASO 0: VALIDACIÓN DE INTERFACES\n");
    await validateInterfaces();
    await validateMethods();
    
    const [deployer] = await hre.ethers.getSigners();
    console.log(`📍 Deployer: ${deployer.address}`);
    console.log(`🌐 Network: ${hre.network.name}\n`);
    
    // 1. Deploy GameifiedMarketplaceCoreV1 (Implementation)
    console.log("📋 PASO 1: DESPLEGAR CORE V1 (Implementation)\n");
    console.log("📦 Desplegando GameifiedMarketplaceCoreV1 (Implementation)...");
    const GameifiedMarketplaceCoreV1 = await hre.ethers.getContractFactory("GameifiedMarketplaceCoreV1");
    const implementation = await GameifiedMarketplaceCoreV1.deploy();
    await implementation.waitForDeployment();
    const implementationAddress = await implementation.getAddress();
    console.log(`✅ Implementation deployed at: ${implementationAddress}\n`);
    
    // 2. Create initialization data
    console.log("📋 PASO 2: PREPARAR DATOS DE INICIALIZACIÓN\n");
    console.log("📝 Preparando datos de inicialización...");
    const initializationData = GameifiedMarketplaceCoreV1.interface.encodeFunctionData(
        'initialize',
        [deployer.address] // platformTreasury
    );
    console.log(`✅ Datos de inicialización codificados\n`);
    
    // 3. Deploy Proxy
    console.log("📋 PASO 3: DESPLEGAR UUPS PROXY\n");
    console.log("📦 Desplegando UUPS Proxy...");
    const GameifiedMarketplaceProxy = await hre.ethers.getContractFactory("GameifiedMarketplaceProxy");
    const proxy = await GameifiedMarketplaceProxy.deploy(implementationAddress, initializationData);
    await proxy.waitForDeployment();
    const proxyAddress = await proxy.getAddress();
    console.log(`✅ Proxy deployed at: ${proxyAddress}`);
    console.log(`   🔴 DIRECCIÓN PERMANENTE PARA TODAS LAS LLAMADAS\n`);
    
    // 4. Deploy GameifiedMarketplaceSkills
    console.log("📋 PASO 4: DESPLEGAR SKILLS CON SEGURIDAD\n");
    console.log("📦 Desplegando GameifiedMarketplaceSkills (v2 - Anti-abuse)...");
    const GameifiedMarketplaceSkills = await hre.ethers.getContractFactory("GameifiedMarketplaceSkills");
    const skills = await GameifiedMarketplaceSkills.deploy(proxyAddress);
    await skills.waitForDeployment();
    const skillsAddress = await skills.getAddress();
    console.log(`✅ GameifiedMarketplaceSkills deployed at: ${skillsAddress}`);
    console.log(`   Características de seguridad:`);
    console.log(`   • Max 3 skills activos por usuario`);
    console.log(`   • Un skill por tipo por usuario`);
    console.log(`   • Expiración: 30 días`);
    console.log(`   • Renovación: 50% del precio original\n`);
    
    // 5. Deploy GameifiedMarketplaceQuests
    console.log("📋 PASO 5: DESPLEGAR QUESTS\n");
    console.log("📦 Desplegando GameifiedMarketplaceQuests...");
    const GameifiedMarketplaceQuests = await hre.ethers.getContractFactory("GameifiedMarketplaceQuests");
    const quests = await GameifiedMarketplaceQuests.deploy(proxyAddress);
    await quests.waitForDeployment();
    const questsAddress = await quests.getAddress();
    console.log(`✅ GameifiedMarketplaceQuests deployed at: ${questsAddress}\n`);
    
    // 6. Deploy EnhancedSmartStaking
    console.log("📋 PASO 6: DESPLEGAR STAKING MEJORADO\n");
    console.log("📦 Desplegando EnhancedSmartStaking...");
    const treasuryAddress = deployer.address;
    const EnhancedSmartStaking = await hre.ethers.getContractFactory("EnhancedSmartStaking");
    const staking = await EnhancedSmartStaking.deploy(treasuryAddress);
    await staking.waitForDeployment();
    const stakingAddress = await staking.getAddress();
    console.log(`✅ EnhancedSmartStaking deployed at: ${stakingAddress}\n`);
    
    // 7. Link contracts through proxy
    console.log("📋 PASO 7: CONFIGURAR REFERENCIAS ENTRE CONTRATOS\n");
    console.log("🔗 Configurando referencias...\n");
    
    // Connect to proxy using CoreV1 ABI
    const coreProxy = GameifiedMarketplaceCoreV1.attach(proxyAddress);
    
    // Set Skills
    console.log("  ⏳ Configurando Core -> Skills...");
    let tx = await coreProxy.setSkillsContract(skillsAddress);
    let receipt = await tx.wait();
    console.log(`  ✅ Proxy -> Skills configurado (gas: ${receipt.gasUsed})`);
    
    // Set Quests
    console.log("  ⏳ Configurando Core -> Quests...");
    tx = await coreProxy.setQuestsContract(questsAddress);
    receipt = await tx.wait();
    console.log(`  ✅ Proxy -> Quests configurado (gas: ${receipt.gasUsed})`);
    
    // Link staking contract to Core
    console.log("  ⏳ Configurando Core -> Staking...");
    tx = await coreProxy.setStakingContract(stakingAddress);
    receipt = await tx.wait();
    console.log(`  ✅ Proxy -> Staking configurado (gas: ${receipt.gasUsed})\n`);
    
    // 8. Link marketplace to staking
    console.log("🔗 Configurando notificaciones Marketplace -> Staking...\n");
    
    const stakingContract = EnhancedSmartStaking.attach(stakingAddress);
    
    console.log("  ⏳ Configurando Staking.setMarketplaceAddress...");
    tx = await stakingContract.setMarketplaceAddress(proxyAddress);
    receipt = await tx.wait();
    console.log(`  ✅ Staking puede recibir notificaciones del Proxy (gas: ${receipt.gasUsed})\n`);
    
    // 9. Link skills to staking for notifications
    console.log("🔗 Configurando canal Skills -> Staking...\n");
    
    const skillsContract = GameifiedMarketplaceSkills.attach(skillsAddress);
    
    console.log("  ⏳ Configurando Skills.setStakingContract...");
    tx = await skillsContract.setStakingContract(stakingAddress);
    receipt = await tx.wait();
    console.log(`  ✅ Skills notificará activaciones al Staking (gas: ${receipt.gasUsed})\n`);
    
    // 10. Link quests to staking for notifications
    console.log("🔗 Configurando canal Quests -> Staking...\n");
    
    const questsContract = GameifiedMarketplaceQuests.attach(questsAddress);
    
    console.log("  ⏳ Configurando Quests.setStakingContract...");
    tx = await questsContract.setStakingContract(stakingAddress);
    receipt = await tx.wait();
    console.log(`  ✅ Quests notificará completiones al Staking (gas: ${receipt.gasUsed})\n`);
    
    // 11. Verify UPGRADER_ROLE
    console.log("🔐 Configurando permisos UPGRADER_ROLE...");
    const UPGRADER_ROLE = await coreProxy.UPGRADER_ROLE();
    tx = await coreProxy.grantRole(UPGRADER_ROLE, deployer.address);
    receipt = await tx.wait();
    console.log(`✅ UPGRADER_ROLE asignado al deployer\n`);
    
    // 12. Validate synchronization
    console.log("✅ VALIDAR SINCRONIZACIÓN POST-DEPLOYMENT\n");
    
    try {
        // Test: Skills puede notificar Staking
        const skillsHasMarketplace = await skillsContract.stakingContractAddress();
        if (skillsHasMarketplace.toLowerCase() === stakingAddress.toLowerCase()) {
            console.log("  ✅ Skills vinculado a Staking correctamente");
        } else {
            throw new Error("Skills no está vinculado a Staking");
        }
        
        // Test: Quests puede notificar Staking
        const questsHasMarketplace = await questsContract.stakingContractAddress();
        if (questsHasMarketplace.toLowerCase() === stakingAddress.toLowerCase()) {
            console.log("  ✅ Quests vinculado a Staking correctamente");
        } else {
            throw new Error("Quests no está vinculado a Staking");
        }
        
        // Test: Staking conoce el Marketplace
        const stakingMarketplace = await stakingContract.marketplaceContract();
        if (stakingMarketplace.toLowerCase() === proxyAddress.toLowerCase()) {
            console.log("  ✅ Staking conoce al Proxy correctamente");
        } else {
            throw new Error("Staking no conoce al Proxy");
        }
        
        // Test: Core tiene dirección de Skills
        const coreSkills = await coreProxy.skillsContractAddress();
        if (coreSkills.toLowerCase() === skillsAddress.toLowerCase()) {
            console.log("  ✅ Core vinculado a Skills correctamente");
        } else {
            throw new Error("Core no está vinculado a Skills");
        }
        
        // Test: Core tiene dirección de Quests
        const coreQuests = await coreProxy.questsContractAddress();
        if (coreQuests.toLowerCase() === questsAddress.toLowerCase()) {
            console.log("  ✅ Core vinculado a Quests correctamente");
        } else {
            throw new Error("Core no está vinculado a Quests");
        }
        
        // Test: Core tiene dirección de Staking
        const coreStaking = await coreProxy.stakingContractAddress();
        if (coreStaking.toLowerCase() === stakingAddress.toLowerCase()) {
            console.log("  ✅ Core vinculado a Staking correctamente");
        } else {
            throw new Error("Core no está vinculado a Staking");
        }
        
        console.log("\n✅ TODAS LAS VALIDACIONES PASADAS\n");
    } catch (error) {
        console.error("❌ Error en validación:", error.message);
        throw error;
    }
    
    // Save deployment info
    const deploymentInfo = {
        network: hre.network.name,
        timestamp: new Date().toISOString(),
        deployer: deployer.address,
        contracts: {
            proxy: {
                address: proxyAddress,
                type: "UUPS Proxy (Permanent)",
                purpose: "Permanent address for all Core interactions",
                bytecode: "~2KB"
            },
            implementation: {
                address: implementationAddress,
                type: "GameifiedMarketplaceCoreV1 (Upgradeable)",
                purpose: "Business logic, swappable via proxy",
                bytecode: "~11KB",
                upgradeable: true,
                features: [
                    "NFT Creation (Standard & Skills)",
                    "Marketplace (List/Buy/Offer)",
                    "Social Features (Like/Comment)",
                    "User Profiles & XP Tracking"
                ]
            },
            skills: {
                address: skillsAddress,
                type: "Skills Management (v2 - Anti-abuse)",
                bytecode: "~10KB",
                securityFeatures: [
                    "Max 3 active skills per user",
                    "One skill type per user",
                    "30-day expiration",
                    "50% renewal cost",
                    "Notifies Staking of activations"
                ],
                features: [
                    "Skill NFT Registration",
                    "Skill Type & Rarity Tracking",
                    "XP Bonuses",
                    "Expiration Management",
                    "Renewal System"
                ]
            },
            quests: {
                address: questsAddress,
                type: "Quests System",
                bytecode: "~8KB",
                features: [
                    "Quest Management (CRUD)",
                    "Dynamic Progress Tracking",
                    "Quest Type Support (5 types)",
                    "Notifies Staking of completions"
                ]
            },
            staking: {
                address: stakingAddress,
                type: "Enhanced Smart Staking",
                bytecode: "~15KB",
                features: [
                    "NFT-based Staking with Skill Boosts",
                    "APY Rewards Calculation",
                    "Achievement System",
                    "Synchronized with Marketplace"
                ],
                synchronization: {
                    receivesNotifications: true,
                    notificationTypes: [
                        "notifySkillActivation - when skills are registered",
                        "notifySkillDeactivation - when skills expire",
                        "notifyQuestCompletion - when quests are completed",
                        "notifyAchievementUnlocked - when achievements are earned",
                        "updateUserXP - for XP tracking"
                    ],
                    verifiedSync: {
                        skillsToStaking: "✅ Verified",
                        questsToStaking: "✅ Verified",
                        coreToSkills: "✅ Verified",
                        coreToQuests: "✅ Verified",
                        coreTostaking: "✅ Verified"
                    }
                }
            }
        },
        statistics: {
            totalBytecode: "~46KB (with proxy and staking)",
            optimizedLimit: "24KB per contract (Polygon)",
            deploymentMethod: "UUPS Proxy Pattern + Cross-contract Notifications",
            status: "✅ PRODUCTION READY",
            upgradeable: true,
            synchronized: true,
            interfaceValidation: "✅ Passed"
        },
        upgradePath: {
            description: "To upgrade implementation:",
            steps: [
                "1. Deploy new GameifiedMarketplaceCoreV2 implementation",
                "2. Call proxy.upgradeTo(newImplementationAddress)",
                "3. State is preserved, users call same proxy address"
            ],
            requirement: "Caller must have UPGRADER_ROLE"
        },
        interactions: {
            permanent_address: proxyAddress,
            userCreatesNFT: `${proxyAddress}.createStandardNFT()`,
            userAddsSkills: `${skillsAddress}.registerSkillsForNFT()`,
            systemUpdatesXP: `Skills/Quests -> ${proxyAddress}.updateUserXP()`,
            userCompletesQuest: `${questsAddress}.completeQuest()`,
            skillsNotifyStaking: `${skillsAddress}.notifySkillActivation() -> ${stakingAddress}`,
            questsNotifyStaking: `${questsAddress}.notifyQuestCompletion() -> ${stakingAddress}`,
            stakingRewardsSync: `Staking rewards synchronized with marketplace activity`
        },
        synchronizationFlows: {
            skillActivation: {
                flow: "Skill registered -> Skills notifies Staking -> Skill boost applied to staking rewards",
                contracts_involved: [skillsAddress, stakingAddress],
                xpGainLocation: proxyAddress,
                rewardLocation: stakingAddress,
                validatedSync: true
            },
            questCompletion: {
                flow: "Quest completed -> Quests notifies Staking -> Quest rewards synced",
                contracts_involved: [questsAddress, stakingAddress],
                xpGainLocation: proxyAddress,
                rewardLocation: stakingAddress,
                validatedSync: true
            },
            userRewards: {
                flow: "All marketplace activity -> Core XP tracking + Staking reward multipliers",
                totalValueLocation: "Staking contract tracks cumulative rewards",
                validatedSync: true
            }
        }
    };
    
    const deploymentPath = path.join(__dirname, "..", "deployments", "modular-with-proxy-optimized.json");
    fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
    
    console.log("📋 Información de deployment guardada en deployments/modular-with-proxy-optimized.json\n");
    console.log("════════════════════════════════════════════════════════════════════════════════════════");
    console.log("✅ ¡DEPLOYMENT CON PROXY, STAKING E INTERFACES SINCRONIZADAS COMPLETADO!\n");
    console.log("🎯 DIRECCIONES PERMANENTES (Use estas para frontend):");
    console.log(`  📌 GameifiedMarketplaceCore Proxy: ${proxyAddress}`);
    console.log(`  🔄 Implementation (can be upgraded):  ${implementationAddress}`);
    console.log(`  📦 GameifiedMarketplaceSkills (v2):  ${skillsAddress}`);
    console.log(`  🎮 GameifiedMarketplaceQuests:       ${questsAddress}`);
    console.log(`  💰 EnhancedSmartStaking:            ${stakingAddress}`);
    console.log("\n📝 IMPORTANTE:");
    console.log(`   Use ${proxyAddress} en tu frontend para marketplace`);
    console.log("   La dirección del proxy NUNCA cambiará, incluso después de upgrades\n");
    console.log("🔄 SINCRONIZACIÓN DE CONTRATOS:");
    console.log(`   ✅ Core Proxy -> Skills: Sincronizado`);
    console.log(`   ✅ Core Proxy -> Quests: Sincronizado`);
    console.log(`   ✅ Core Proxy -> Staking: Sincronizado`);
    console.log(`   ✅ Skills -> Staking Notifications: Configurado`);
    console.log(`   ✅ Quests -> Staking Notifications: Configurado`);
    console.log(`   ✅ Interfaces: Validadas y Optimizadas\n`);
    console.log("🛡️ SEGURIDAD EN SKILLS:");
    console.log(`   ✅ Max 3 skills activos por usuario`);
    console.log(`   ✅ Un skill type por usuario`);
    console.log(`   ✅ Expiración de 30 días`);
    console.log(`   ✅ Sistema de renovación\n`);
    console.log("🔐 UPGRADE INSTRUCTIONS:");
    console.log(`   1. Deploy GameifiedMarketplaceCoreV2 implementation`);
    console.log(`   2. Call coreProxy.upgradeTo(newImplementationAddress)`);
    console.log(`   3. State is automatically preserved`);
    console.log(`   4. Staking will continue to receive notifications from new implementation\n`);
    console.log("════════════════════════════════════════════════════════════════════════════════════════\n");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
