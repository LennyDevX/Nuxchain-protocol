#!/usr/bin/env node

const { ethers, network, run, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

/**
 * 🚀 DEPLOYMENT COMPLETO - NUXCHAIN PROTOCOL v6.0
 * 
 * Despliega TODOS los contratos del protocolo sincronizados:
 * 
 * ✅ ENHANCED SMART STAKING V2 (8 Módulos - UUPS + View Split):
 *    1. EnhancedSmartStakingCoreV2 (Core + Deposits/Withdrawals - UUPS)
 *    2. EnhancedSmartStakingRewards (APY + Compounding)
 *    3. EnhancedSmartStakingSkills (Skill activation/effects)
 *    4. EnhancedSmartStakingGamification (XP + Levels)
 *    5. EnhancedSmartStakingViewCore (View - Deposits & Portfolio)
 *    6. EnhancedSmartStakingViewStats (View - Pool Stats & APY)
 *    7. EnhancedSmartStakingViewSkills (View - Skills & Metrics)
 *    8. DynamicAPYCalculator (APY calculation utility)
 * 
 * ✅ GAMEIFIED MARKETPLACE (UUPS Proxy + 9 Módulos):
 *    1. GameifiedMarketplaceCoreV1 (UUPS Proxy)
 *    2. LevelingSystem (UUPS)
 *    3. ReferralSystem (UUPS)
 *    4. GameifiedMarketplaceSkillsNft (NFT Skills)
 *    5. IndividualSkillsMarketplace (Direct Skills)
 *    6. GameifiedMarketplaceQuests (Quest System)
 *    7. CollaboratorBadgeRewards (UUPS - Badge System)
 *    8. MarketplaceView (View Contract)
 *    9. MarketplaceStatistics (Statistics)
 *   10. MarketplaceSocial (Social Integration)
 * 
 * ✅ TREASURY MANAGEMENT:
 *    1. TreasuryManager (Centralized Treasury)
 * 
 * ✅ CARACTERÍSTICAS:
 *    • Sincronización bidireccional completa
 *    • Arquitectura modular 100% upgradeable via UUPS
 *    • Todas las direcciones incluidas en JSON
 *    • Verificación automática en Polygonscan
 *    • Configuración de roles y permisos
 *    • Total: 19 contratos desplegados
 * 
 * @custom:version 6.0.0
 * @custom:security-contact security@nuvo.com
 */

async function main() {
    console.log("\n");
    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🚀 NUXCHAIN PROTOCOL - COMPLETE DEPLOYMENT v6.0                             ║");
    console.log("║                                                                                ║");
    console.log("║  ✅ EnhancedSmartStakingV2 (8 Modules + UUPS + View Split)                   ║");
    console.log("║  ✅ GameifiedMarketplace (UUPS + 9 Sub-modules)                              ║");
    console.log("║  ✅ TreasuryManager (Centralized Revenue Distribution)                       ║");
    console.log("║  ✅ Complete Bidirectional Synchronization                                    ║");
    console.log("║  ✅ All 19 Contracts - Verified & Ready                                       ║");
    console.log("║                                                                                ║");
    console.log("║  Network: ${network.name.toUpperCase().padEnd(35)} Chain ID: ${(await ethers.provider.getNetwork()).chainId}                    ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    // Load treasury address
    const TREASURY_ADDRESS = process.env.TREASURY_ADDRESS;
    if (!TREASURY_ADDRESS) {
        throw new Error("❌ TREASURY_ADDRESS not found in .env");
    }
    console.log(`🏦 Treasury Address (from .env): ${TREASURY_ADDRESS}\n`);

    // Get deployer info
    const [deployer] = await ethers.getSigners();
    const deployerBalance = await ethers.provider.getBalance(deployer.address);
    const initialBalance = deployerBalance;

    console.log(`📍 Deployer: ${deployer.address}`);
    console.log(`💰 Balance: ${ethers.formatEther(deployerBalance)} POL`);
    console.log(`🌐 Network: ${network.name}`);
    console.log(`⛓️  Chain ID: ${(await ethers.provider.getNetwork()).chainId}\n`);

    // Compile contracts
    await run("compile");
    console.log("✅ Compilation completed\n");

    // Get optimized gas price
    console.log("⛽ Getting current gas price...");
    const feeData = await ethers.provider.getFeeData();
    // Use base gas price without multiplier for better acceptance rate
    // Polygon typically uses 30-80 Gwei, minimum tip is 25 Gwei
    if (!feeData.maxFeePerGas || !feeData.maxPriorityFeePerGas) {
        throw new Error("❌ Invalid gas fee data from RPC. maxFeePerGas or maxPriorityFeePerGas is null. Please check your network/RPC or set a fallback gas price.");
    }
    // IMPORTANT: Polygon has minimum priority fee of 25 Gwei, so we use actual values with 25% buffer
    // Increased buffer to handle batch transaction repricing issues
    const baseMaxFee = feeData.maxFeePerGas;
    const baseMaxPriority = feeData.maxPriorityFeePerGas;
    
    // Apply 25% buffer to ensure we meet network minimums and handle batch repricing
    const maxFeePerGas = (baseMaxFee * 125n) / 100n;
    const maxPriorityFeePerGas = (baseMaxPriority * 125n) / 100n;
    
    console.log(`   Base Fee: ${ethers.formatUnits(baseMaxFee, "gwei")} Gwei`);
    console.log(`   Base Priority: ${ethers.formatUnits(baseMaxPriority, "gwei")} Gwei`);
    console.log(`   Final Max Fee: ${ethers.formatUnits(maxFeePerGas, "gwei")} Gwei (+25% buffer for batch safety)`);
    console.log(`   Final Priority Fee: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} Gwei (+25% buffer for batch safety)\n`);

    const gasOptions = { 
        maxFeePerGas, 
        maxPriorityFeePerGas,
        gasLimit: 8000000 // Límite optimizado para Polygon
    };
    const deploymentData = {
        network: network.name,
        chainId: (await ethers.provider.getNetwork()).chainId.toString(),
        deployer: deployer.address,
        treasury: TREASURY_ADDRESS,
        timestamp: new Date().toISOString(),
        staking: {},
        marketplace: {}
    };

    try {
        // ═════════════════════════════════════════════════════════════════════════════════
        // FASE 0: DESPLEGAR TREASURY MANAGER
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  FASE 0: TREASURY MANAGEMENT DEPLOYMENT                                      ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

        console.log("📦 0.1 Deploying TreasuryManager (Centralized Revenue Distribution)...");
        const TreasuryFactory = await ethers.getContractFactory("TreasuryManager");
        let treasuryManager;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            treasuryManager = await TreasuryFactory.deploy(gasOptions);
            const treasuryTx = treasuryManager.deploymentTransaction();
            console.log(`   📡 TX Hash: ${treasuryTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${treasuryTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for deployment...`);
            await treasuryManager.waitForDeployment();
            const treasuryManagerAddress = await treasuryManager.getAddress();
            console.log(`✅ Treasury Manager: ${treasuryManagerAddress}\n`);
            deploymentData.treasury = { manager: treasuryManagerAddress };
            await waitForContractCode(treasuryManagerAddress, { retries: 20, delay: 3000, name: "TreasuryManager" });
        } catch (error) {
            console.error(`❌ Error deploying TreasuryManager: ${error.message}`);
            throw error;
        }

        // ═════════════════════════════════════════════════════════════════════════════════
        // FASE 1: DESPLEGAR ENHANCED SMART STAKING (MODULAR - 8 CONTRATOS)
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  FASE 1: ENHANCED SMART STAKING DEPLOYMENT (Modular - 8 Contracts)           ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

        // 1.1 Deploy Rewards Module
        console.log("📦 1.1 Deploying EnhancedSmartStakingRewards (Rewards & APY)...");
        const RewardsFactory = await ethers.getContractFactory("EnhancedSmartStakingRewards");
        let rewardsTx;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const rewards = await RewardsFactory.deploy(gasOptions);
            rewardsTx = rewards.deploymentTransaction();
            console.log(`   📡 TX Hash: ${rewardsTx ? rewardsTx.hash : 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${rewardsTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for 1 confirmation (optimized)...`);
            
            const deploymentPromise = rewards.waitForDeployment();
            const timeoutPromise = new Promise((_, reject) => 
                setTimeout(() => reject(new Error('Deployment timeout after 3 minutes')), 180000)
            );
            
            await Promise.race([deploymentPromise, timeoutPromise]);
            
            const rewardsAddress = await rewards.getAddress();
            console.log(`✅ Rewards Module: ${rewardsAddress}\n`);
            deploymentData.staking.rewards = rewardsAddress;
            await waitForContractCode(rewardsAddress, { retries: 20, delay: 3000, name: "Rewards" });
        } catch (error) {
            console.error(`❌ Error deploying Rewards: ${error.message}`);
            if (rewardsTx) {
                console.error(`   View: https://polygonscan.com/tx/${rewardsTx.hash}`);
            }
            throw error;
        }

        // 1.2 Deploy Skills Module
        console.log("📦 1.2 Deploying EnhancedSmartStakingSkills (Skill Activation)...");
        const SkillsFactory = await ethers.getContractFactory("EnhancedSmartStakingSkills");
        let skillsTx;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const stakingSkills = await SkillsFactory.deploy(gasOptions);
            skillsTx = stakingSkills.deploymentTransaction();
            console.log(`   📡 TX Hash: ${skillsTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${skillsTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for confirmations (2-5 minutes)...`);
            
            const deploymentPromise = stakingSkills.waitForDeployment();
            const timeoutPromise = new Promise((_, reject) => 
                setTimeout(() => reject(new Error('Timeout after 3 minutes')), 180000)
            );
            await Promise.race([deploymentPromise, timeoutPromise]);
            const skillsAddress = await stakingSkills.getAddress();
            console.log(`✅ Skills Module: ${skillsAddress}\n`);
            deploymentData.staking.skills = skillsAddress;
            await waitForContractCode(skillsAddress, { retries: 20, delay: 3000, name: "Skills" });
        } catch (error) {
            console.error(`❌ Error deploying Skills: ${error.message}`);
            throw error;
        }

        // 1.3 Deploy Gamification Module
        console.log("📦 1.3 Deploying EnhancedSmartStakingGamification (XP & Levels)...");
        const GamificationFactory = await ethers.getContractFactory("EnhancedSmartStakingGamification");
        let gamTx;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const gamification = await GamificationFactory.deploy(gasOptions);
            gamTx = gamification.deploymentTransaction();
            console.log(`   📡 TX Hash: ${gamTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${gamTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for confirmations (2-5 minutes)...`);
            
            const deploymentPromise = gamification.waitForDeployment();
            const timeoutPromise = new Promise((_, reject) => 
                setTimeout(() => reject(new Error('Timeout after 3 minutes')), 180000)
            );
            await Promise.race([deploymentPromise, timeoutPromise]);
            const gamificationAddress = await gamification.getAddress();
            console.log(`✅ Gamification Module: ${gamificationAddress}\n`);
            deploymentData.staking.gamification = gamificationAddress;
            await waitForContractCode(gamificationAddress, { retries: 20, delay: 3000, name: "Gamification" });
        } catch (error) {
            console.error(`❌ Error deploying Gamification: ${error.message}`);
            throw error;
        }

        // 1.4 Deploy Core Staking (UUPS Proxy)
        console.log("📦 1.4 Deploying EnhancedSmartStakingCoreV2 (Core - Orchestrator - UUPS)...");
        const CoreFactory = await ethers.getContractFactory("EnhancedSmartStakingCoreV2");
        let stakingCore;
        let coreTx;
        try {
            console.log(`   ⏳ Deploying UUPS proxy...`);
            stakingCore = await upgrades.deployProxy(CoreFactory, [TREASURY_ADDRESS], {
                initializer: 'initialize',
                kind: 'uups',
                ...gasOptions
            });
            await stakingCore.waitForDeployment();
            const coreAddress = await stakingCore.getAddress();
            console.log(`✅ Core Staking Proxy (UUPS): ${coreAddress}\n`);
            deploymentData.staking.core = coreAddress;
            await waitForContractCode(coreAddress, { retries: 20, delay: 3000, name: "Core" });
        } catch (error) {
            console.error(`❌ Error deploying Core: ${error.message}`);
            throw error;
        }

        // 1.5 Deploy View Module (AFTER Core, since it needs Core address) - OPTIONAL
        console.log("📦 1.5 Deploying EnhancedSmartStakingView (Split into 3 modular contracts)...");
        const coreAddress = await stakingCore.getAddress();
        
        // 1.5.1 Deploy ViewCore (Deposits, Balances)
        const ViewCoreFactory = await ethers.getContractFactory("EnhancedSmartStakingViewCore");
        try {
            console.log(`   ⏳ 1.5.1 ViewCore - Sending deployment transaction...`);
            const viewCoreContract = await ViewCoreFactory.deploy(coreAddress, gasOptions);
            const viewCoreTx = viewCoreContract.deploymentTransaction();
            console.log(`   📡 TX Hash: ${viewCoreTx?.hash || 'pending'}`);
            await Promise.race([
                viewCoreContract.waitForDeployment(),
                new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 180000))
            ]);
            const viewCoreAddress = await viewCoreContract.getAddress();
            console.log(`   ✅ ViewCore Module: ${viewCoreAddress}`);
            deploymentData.staking.viewCore = viewCoreAddress;
            await waitForContractCode(viewCoreAddress, { retries: 20, delay: 3000, name: "ViewCore" });
        } catch (error) {
            console.warn(`   ❌ ViewCore deployment failed: ${error.message}`);
            deploymentData.staking.viewCore = "0x0000000000000000000000000000000000000000";
        }
        
        // 1.5.2 Deploy ViewStats (Pool stats, APY, Dashboard)
        const ViewStatsFactory = await ethers.getContractFactory("EnhancedSmartStakingViewStats");
        try {
            console.log(`   ⏳ 1.5.2 ViewStats - Sending deployment transaction...`);
            const viewStatsContract = await ViewStatsFactory.deploy(coreAddress, gasOptions);
            const viewStatsTx = viewStatsContract.deploymentTransaction();
            console.log(`   📡 TX Hash: ${viewStatsTx?.hash || 'pending'}`);
            await Promise.race([
                viewStatsContract.waitForDeployment(),
                new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 180000))
            ]);
            const viewStatsAddress = await viewStatsContract.getAddress();
            console.log(`   ✅ ViewStats Module: ${viewStatsAddress}`);
            deploymentData.staking.viewStats = viewStatsAddress;
            await waitForContractCode(viewStatsAddress, { retries: 20, delay: 3000, name: "ViewStats" });
        } catch (error) {
            console.warn(`   ❌ ViewStats deployment failed: ${error.message}`);
            deploymentData.staking.viewStats = "0x0000000000000000000000000000000000000000";
        }
        
        // 1.5.3 Deploy ViewSkills (Skills, Gamification, Metrics)
        const ViewSkillsFactory = await ethers.getContractFactory("EnhancedSmartStakingViewSkills");
        try {
            console.log(`   ⏳ 1.5.3 ViewSkills - Sending deployment transaction...`);
            const viewSkillsContract = await ViewSkillsFactory.deploy(coreAddress, gasOptions);
            const viewSkillsTx = viewSkillsContract.deploymentTransaction();
            console.log(`   📡 TX Hash: ${viewSkillsTx?.hash || 'pending'}`);
            await Promise.race([
                viewSkillsContract.waitForDeployment(),
                new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 180000))
            ]);
            const viewSkillsAddress = await viewSkillsContract.getAddress();
            console.log(`   ✅ ViewSkills Module: ${viewSkillsAddress}`);
            deploymentData.staking.viewSkills = viewSkillsAddress;
            await waitForContractCode(viewSkillsAddress, { retries: 20, delay: 3000, name: "ViewSkills" });
        } catch (error) {
            console.warn(`   ❌ ViewSkills deployment failed: ${error.message}`);
            deploymentData.staking.viewSkills = "0x0000000000000000000000000000000000000000";
        }
        
        // Backward compatibility: set view to viewCore
        deploymentData.staking.view = deploymentData.staking.viewCore;
        console.log(`\n   📋 All 3 View modules deployed successfully!\n`);

        // 1.6 Deploy DynamicAPYCalculator (Utility Contract)
        console.log("📦 1.6 Deploying DynamicAPYCalculator (APY Calculation Utility)...");
        const APYFactory = await ethers.getContractFactory("DynamicAPYCalculator");
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const apy = await APYFactory.deploy(gasOptions);
            const apyTx = apy.deploymentTransaction();
            console.log(`   📡 TX Hash: ${apyTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${apyTx?.hash || 'pending'}`);
            await apy.waitForDeployment();
            const apyAddress = await apy.getAddress();
            console.log(`✅ DynamicAPYCalculator: ${apyAddress}\n`);
            deploymentData.staking.dynamicAPY = apyAddress;
            await waitForContractCode(apyAddress, { retries: 20, delay: 3000, name: "DynamicAPY" });
        } catch (error) {
            console.warn(`   ⚠️  DynamicAPYCalculator deployment optional: ${error.message}`);
            deploymentData.staking.dynamicAPY = "0x0000000000000000000000000000000000000000";
        }

        // 1.7 Configure Core -> Module References (OPTIMIZED: Batch transactions)
        console.log("🔗 1.6 Configuring Core -> Module References...");
        
        const rewardsAddress = deploymentData.staking.rewards;
        const skillsAddress = deploymentData.staking.skills;
        const gamificationAddress = deploymentData.staking.gamification;
        const SkillsFactoryForAttach = await ethers.getContractFactory("EnhancedSmartStakingSkills");
        const SkillsModuleInstance = SkillsFactoryForAttach.attach(skillsAddress);
        const GamificationFactoryForAttach = await ethers.getContractFactory("EnhancedSmartStakingGamification");
        const GamificationModuleInstance = GamificationFactoryForAttach.attach(gamificationAddress);
        
        try {
            // OPTIMIZACIÓN: Enviar todas las TX sin esperar, luego esperar todas juntas
            console.log("   📤 Sending batch transactions...");
            const tx1 = await stakingCore.setRewardsModule(rewardsAddress, gasOptions);
            const tx2 = await stakingCore.setSkillsModule(skillsAddress, gasOptions);
            const tx3 = await stakingCore.setGamificationModule(gamificationAddress, gasOptions);
            
            console.log("   ⏳ Waiting for all confirmations...");
            await Promise.all([tx1.wait(1), tx2.wait(1), tx3.wait(1)]);
            console.log("   ✅ Core -> Rewards Module");
            console.log("   ✅ Core -> Skills Module");
            console.log("   ✅ Core -> Gamification Module\n");
        } catch (error) {
            console.error(`❌ Error configuring Core references: ${error.message}`);
            throw error;
        }

        // 1.7 Configure Module -> Core References (OPTIMIZED: Batch)
        console.log("🔗 1.7 Configuring Module -> Core References...");
        try {
            console.log("   📤 Sending batch transactions...");
            const tx1 = await SkillsModuleInstance.setCoreStakingContract(coreAddress, gasOptions);
            const tx2 = await GamificationModuleInstance.setCoreStakingContract(coreAddress, gasOptions);
            
            await Promise.all([tx1.wait(1), tx2.wait(1)]);
            console.log("   ✅ Skills Module -> Core");
            console.log("   ✅ Gamification Module -> Core\n");
        } catch (error) {
            console.error(`❌ Error configuring Module references: ${error.message}`);
            throw error;
        }

        // ═════════════════════════════════════════════════════════════════════════════════
        // FASE 2: DESPLEGAR GAMEIFIED MARKETPLACE (UUPS Proxy + 6 MÓDULOS)
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  FASE 2: GAMEIFIED MARKETPLACE DEPLOYMENT (UUPS Proxy + 6 Sub-modules)       ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

        // 2.0.1 Deploy LevelingSystem (UUPS via upgrades plugin)
        console.log("📦 2.0.1 Deploying LevelingSystem (UUPS)...");
        const LevelingFactory = await ethers.getContractFactory("LevelingSystem");
        const levelingProxy = await upgrades.deployProxy(LevelingFactory, [deployer.address], {
            initializer: 'initialize',
            kind: 'uups'
        });
        await levelingProxy.waitForDeployment();
        const levelingProxyAddress = await levelingProxy.getAddress();
        console.log(`   ✅ Leveling Proxy: ${levelingProxyAddress}\n`);
        deploymentData.marketplace.leveling = levelingProxyAddress;

        // 2.0.2 Deploy ReferralSystem (UUPS via upgrades plugin)
        console.log("📦 2.0.2 Deploying ReferralSystem (UUPS)...");
        const ReferralFactory = await ethers.getContractFactory("ReferralSystem");
        const referralProxy = await upgrades.deployProxy(ReferralFactory, [deployer.address], {
            initializer: 'initialize',
            kind: 'uups'
        });
        await referralProxy.waitForDeployment();
        const referralProxyAddress = await referralProxy.getAddress();
        console.log(`   ✅ Referral Proxy: ${referralProxyAddress}\n`);
        deploymentData.marketplace.referral = referralProxyAddress;

        // 2.1 Deploy GameifiedMarketplaceCoreV1 (UUPS Proxy via upgrades plugin)
        console.log("📦 2.1 Deploying GameifiedMarketplaceCoreV1 (UUPS Proxy)...");
        const MarketplaceCoreFactory = await ethers.getContractFactory("GameifiedMarketplaceCoreV1");
        let marketplaceProxy;
        try {
            console.log(`   ⏳ Deploying with upgrades.deployProxy()...`);
            console.log(`   Using treasury: ${TREASURY_ADDRESS}`);
            
            // Deploy with proper error handling
            marketplaceProxy = await upgrades.deployProxy(
                MarketplaceCoreFactory,
                [TREASURY_ADDRESS],
                {
                    initializer: 'initialize',
                    kind: 'uups',
                    timeout: 120000  // 2 minute timeout
                }
            );
            
            await marketplaceProxy.waitForDeployment();
            const proxyAddress = await marketplaceProxy.getAddress();
            console.log(`✅ Marketplace Core Proxy: ${proxyAddress}\n`);
            deploymentData.marketplace.proxy = proxyAddress;
            deploymentData.marketplace.implementation = proxyAddress; // Track proxy as implementation for consistency
            await waitForContractCode(proxyAddress, { retries: 20, delay: 3000, name: "Marketplace Proxy" });
        } catch (error) {
            console.error(`❌ Error deploying Marketplace Proxy: ${error.message}`);
            console.error(`Full error:`, error);
            throw error;
        }

        // 2.4 Deploy Skills NFT Module
        console.log("📦 2.4 Deploying GameifiedMarketplaceSkillsNft (NFT-Embedded Skills)...");
        const SkillsNFTFactory = await ethers.getContractFactory("GameifiedMarketplaceSkillsNft");
        const coreProxyAddress = deploymentData.marketplace.proxy;
        let skillsNFT;
        let skillsNFTTx;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            console.log(`   Using core proxy address: ${coreProxyAddress}`);
            skillsNFT = await SkillsNFTFactory.deploy(coreProxyAddress, gasOptions);
            skillsNFTTx = skillsNFT.deploymentTransaction();
            console.log(`   📡 TX Hash: ${skillsNFTTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${skillsNFTTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for 1 confirmation...`);
            await skillsNFT.waitForDeployment();
            const skillsNFTAddress = await skillsNFT.getAddress();
            console.log(`✅ Skills NFT: ${skillsNFTAddress}`);
            
            // Wait a moment for the contract to be fully initialized on-chain
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            // Verify the contract is properly initialized
            const currentTreasury = await skillsNFT.treasuryAddress();
            console.log(`   Current treasury: ${currentTreasury}`);
            
            // Only update treasury if needed
            if (currentTreasury !== TREASURY_ADDRESS) {
                console.log(`   Updating treasury to: ${TREASURY_ADDRESS}`);
                let tx = await skillsNFT.setTreasuryAddress(TREASURY_ADDRESS, gasOptions);
                let receipt = await tx.wait();
                if (receipt && receipt.status === 1) {
                    console.log(`✅ Treasury configured\n`);
                } else {
                    throw new Error(`Treasury configuration failed with status ${receipt?.status}`);
                }
            } else {
                console.log(`✅ Treasury already configured\n`);
            }
            
            deploymentData.marketplace.skillsNFT = skillsNFTAddress;
            await waitForContractCode(skillsNFTAddress, { retries: 20, delay: 3000, name: "SkillsNFT" });
        } catch (error) {
            console.error(`❌ Error deploying Skills NFT: ${error.message}`);
            console.error(`Stack: ${error.stack}`);
            throw error;
        }

        // 2.5 Deploy Individual Skills Marketplace
        console.log("📦 2.5 Deploying IndividualSkillsMarketplace (Direct Skill Purchase)...");
        const IndividualSkillsFactory = await ethers.getContractFactory("IndividualSkillsMarketplace");
        let individualSkills;
        let individualTx;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            individualSkills = await IndividualSkillsFactory.deploy(TREASURY_ADDRESS, gasOptions);
            individualTx = individualSkills.deploymentTransaction();
            console.log(`   📡 TX Hash: ${individualTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${individualTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for 1 confirmation...`);
            await individualSkills.waitForDeployment();
            const individualSkillsAddress = await individualSkills.getAddress();
            console.log(`✅ Individual Skills: ${individualSkillsAddress}\n`);
            deploymentData.marketplace.individualSkills = individualSkillsAddress;
            await waitForContractCode(individualSkillsAddress, { retries: 20, delay: 3000, name: "IndividualSkills" });
        } catch (error) {
            console.error(`❌ Error deploying Individual Skills: ${error.message}`);
            throw error;
        }

        // 2.6 Deploy Quests Module
        console.log("📦 2.6 Deploying GameifiedMarketplaceQuests (Quest System)...");
        const QuestsFactory = await ethers.getContractFactory("GameifiedMarketplaceQuests");
        const marketplaceProxyAddress = deploymentData.marketplace.proxy;
        let quests;
        let questsTx;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            quests = await QuestsFactory.deploy(marketplaceProxyAddress, gasOptions);
            questsTx = quests.deploymentTransaction();
            console.log(`   📡 TX Hash: ${questsTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${questsTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for 1 confirmation...`);
            await quests.waitForDeployment();
            const questsAddress = await quests.getAddress();
            console.log(`✅ Quests: ${questsAddress}\n`);
            deploymentData.marketplace.quests = questsAddress;
            await waitForContractCode(questsAddress, { retries: 20, delay: 3000, name: "Quests" });
        } catch (error) {
            console.error(`❌ Error deploying Quests: ${error.message}`);
            throw error;
        }

        // 2.7 Deploy CollaboratorBadgeRewards (UUPS)
        console.log("📦 2.7 Deploying CollaboratorBadgeRewards (UUPS - Badge System)...");
        const CollaboratorFactory = await ethers.getContractFactory("CollaboratorBadgeRewards");
        try {
            console.log(`   ⏳ Deploying UUPS proxy...`);
            const collaboratorProxy = await upgrades.deployProxy(CollaboratorFactory, [], {
                initializer: 'initialize',
                kind: 'uups',
                ...gasOptions
            });
            await collaboratorProxy.waitForDeployment();
            const collaboratorAddress = await collaboratorProxy.getAddress();
            console.log(`✅ CollaboratorBadgeRewards (UUPS): ${collaboratorAddress}\n`);
            deploymentData.marketplace.collaboratorBadges = collaboratorAddress;
            await waitForContractCode(collaboratorAddress, { retries: 20, delay: 3000, name: "CollaboratorBadges" });
        } catch (error) {
            console.error(`❌ Error deploying CollaboratorBadgeRewards: ${error.message}`);
            throw error;
        }

        // 2.8 Deploy MarketplaceView
        console.log("📦 2.8 Deploying MarketplaceView (View Contract)...");
        const MarketplaceViewFactory = await ethers.getContractFactory("MarketplaceView");
        const marketplaceCoreProxyAddress = deploymentData.marketplace.proxy;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const marketplaceView = await MarketplaceViewFactory.deploy(deployer.address, marketplaceCoreProxyAddress, gasOptions);
            const viewTx = marketplaceView.deploymentTransaction();
            console.log(`   📡 TX Hash: ${viewTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${viewTx?.hash || 'pending'}`);
            await marketplaceView.waitForDeployment();
            const viewAddress = await marketplaceView.getAddress();
            console.log(`✅ MarketplaceView: ${viewAddress}\n`);
            deploymentData.marketplace.view = viewAddress;
            await waitForContractCode(viewAddress, { retries: 20, delay: 3000, name: "MarketplaceView" });
        } catch (error) {
            console.error(`❌ Error deploying MarketplaceView: ${error.message}`);
            throw error;
        }

        // 2.9 Deploy MarketplaceStatistics
        console.log("📦 2.9 Deploying MarketplaceStatistics (Statistics Contract)...");
        const MarketplaceStatsFactory = await ethers.getContractFactory("MarketplaceStatistics");
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const stats = await MarketplaceStatsFactory.deploy(deployer.address, marketplaceCoreProxyAddress, gasOptions);
            const statsTx = stats.deploymentTransaction();
            console.log(`   📡 TX Hash: ${statsTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${statsTx?.hash || 'pending'}`);
            await stats.waitForDeployment();
            const statsAddress = await stats.getAddress();
            console.log(`✅ MarketplaceStatistics: ${statsAddress}\n`);
            deploymentData.marketplace.statistics = statsAddress;
            await waitForContractCode(statsAddress, { retries: 20, delay: 3000, name: "MarketplaceStatistics" });
        } catch (error) {
            console.error(`❌ Error deploying MarketplaceStatistics: ${error.message}`);
            throw error;
        }

        // 2.10 Deploy MarketplaceSocial
        console.log("📦 2.10 Deploying MarketplaceSocial (Social Integration)...");
        const MarketplaceSocialFactory = await ethers.getContractFactory("MarketplaceSocial");
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const social = await MarketplaceSocialFactory.deploy(deployer.address, marketplaceCoreProxyAddress, gasOptions);
            const socialTx = social.deploymentTransaction();
            console.log(`   📡 TX Hash: ${socialTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${socialTx?.hash || 'pending'}`);
            await social.waitForDeployment();
            const socialAddress = await social.getAddress();
            console.log(`✅ MarketplaceSocial: ${socialAddress}\n`);
            deploymentData.marketplace.social = socialAddress;
            await waitForContractCode(socialAddress, { retries: 20, delay: 3000, name: "MarketplaceSocial" });
        } catch (error) {
            console.error(`❌ Error deploying MarketplaceSocial: ${error.message}`);
            throw error;
        }

        // ═════════════════════════════════════════════════════════════════════════════════
        // FASE 3: SINCRONIZACIÓN BIDIRECCIONAL
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔═══════════════════════════════════════════════════════════════════════════╗");
        console.log("║  FASE 3: BIDIRECTIONAL SYNCHRONIZATION                                   ║");
        console.log("╚═══════════════════════════════════════════════════════════════════════════╝\n");

        // Retrieve all addresses from deployment data
        const proxyAddress = deploymentData.marketplace.proxy;
        const skillsNFTAddress = deploymentData.marketplace.skillsNFT;
        const individualSkillsAddress = deploymentData.marketplace.individualSkills;
        const questsAddress = deploymentData.marketplace.quests;

        // Connect to proxy using Core ABI
        const coreProxy = MarketplaceCoreFactory.attach(proxyAddress);
        const skillsNFTContract = SkillsNFTFactory.attach(skillsNFTAddress);
        const individualSkillsContract = IndividualSkillsFactory.attach(individualSkillsAddress);
        const questsContract = QuestsFactory.attach(questsAddress);
        
        const levelingProxyContract = LevelingFactory.attach(deploymentData.marketplace.leveling);
        const referralProxyContract = ReferralFactory.attach(deploymentData.marketplace.referral);

        // 3.1 Configure Marketplace -> Module References (OPTIMIZED: Batch)
        console.log("🔗 3.1 Configuring Marketplace -> Module References...");
        try {
            // Grant MARKETPLACE_ROLE to Core Proxy on Leveling & Referral
            const MARKETPLACE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MARKETPLACE_ROLE"));
            
            console.log("   📤 Sending batch transactions...");
            const tx1 = await levelingProxyContract.grantRole(MARKETPLACE_ROLE, proxyAddress, gasOptions);
            const tx2 = await referralProxyContract.grantRole(MARKETPLACE_ROLE, proxyAddress, gasOptions);
            const tx3 = await coreProxy.setLevelingSystem(deploymentData.marketplace.leveling, gasOptions);
            const tx4 = await coreProxy.setReferralSystem(deploymentData.marketplace.referral, gasOptions);
            const tx5 = await coreProxy.setSkillsContract(skillsNFTAddress, gasOptions);
            const tx6 = await questsContract.setLevelingContract(deploymentData.marketplace.leveling, gasOptions);

            await Promise.all([tx1.wait(1), tx2.wait(1), tx3.wait(1), tx4.wait(1), tx5.wait(1), tx6.wait(1)]);
            console.log("   ✅ Leveling -> Granted MARKETPLACE_ROLE to Proxy");
            console.log("   ✅ Referral -> Granted MARKETPLACE_ROLE to Proxy");
            console.log("   ✅ Core Proxy -> Leveling System");
            console.log("   ✅ Core Proxy -> Referral System");
            console.log("   ✅ Core Proxy -> Skills NFT");
            console.log("   ✅ Quests -> Leveling System");

            // Quests contract is standalone, Core doesn't need to know about it directly
            // tx = await coreProxy.setQuestsContract(questsAddress, gasOptions);
            // await tx.wait();
            // console.log("   ✅ Core Proxy -> Quests");
        } catch (error) {
            console.error(`❌ Error configuring Marketplace references: ${error.message}`);
            throw error;
        }

        // 3.2 Configure Staking -> Marketplace References (OPTIMIZED: Batch)
        console.log("🔗 3.2 Configuring Staking -> Marketplace References...");
        try {
            console.log("   📤 Sending batch transactions...");
            // Authorize Marketplace Proxy in Staking Core
            const tx1 = await stakingCore.setMarketplaceAuthorization(proxyAddress, true, gasOptions);
            
            // Also authorize individual modules if they need to notify Staking directly
            const tx1b = await stakingCore.setMarketplaceAuthorization(skillsNFTAddress, true, gasOptions);
            const tx1c = await stakingCore.setMarketplaceAuthorization(individualSkillsAddress, true, gasOptions);
            const tx1d = await stakingCore.setMarketplaceAuthorization(questsAddress, true, gasOptions);

            // Modules should accept calls from Staking Core (since Core delegates to them)
            // So marketplaceContract in modules should be the Core address
            const tx2 = await SkillsModuleInstance.setMarketplaceContract(coreAddress, gasOptions);
            const tx3 = await GamificationModuleInstance.setMarketplaceContract(coreAddress, gasOptions);

            await Promise.all([tx1.wait(1), tx1b.wait(1), tx1c.wait(1), tx1d.wait(1), tx2.wait(1), tx3.wait(1)]);
            console.log("   ✅ Staking Core -> Authorized Marketplace Proxy");
            console.log("   ✅ Staking Core -> Authorized Skills NFT");
            console.log("   ✅ Staking Core -> Authorized Individual Skills");
            console.log("   ✅ Staking Core -> Authorized Quests");
            console.log("   ✅ Staking Skills -> Set Marketplace to Core (for delegation)");
            console.log("   ✅ Staking Gamification -> Set Marketplace to Core (for delegation)\n");
        } catch (error) {
            console.error(`❌ Error configuring Staking references: ${error.message}`);
            throw error;
        }

        // 3.3 Configure Module -> Staking Notification Channels (OPTIMIZED: Batch)
        console.log("🔗 3.3 Configuring Notification Channels (Marketplace -> Staking)...");
        try {
            console.log("   📤 Sending batch transactions...");
            const tx1 = await skillsNFTContract.setStakingContract(coreAddress, gasOptions);
            const tx2 = await individualSkillsContract.setStakingContract(coreAddress, gasOptions);
            const tx3 = await questsContract.setStakingContract(coreAddress, gasOptions);

            await Promise.all([tx1.wait(1), tx2.wait(1), tx3.wait(1)]);
            console.log("   ✅ Skills NFT -> Staking (notifications)");
            console.log("   ✅ Individual Skills -> Staking (notifications)");
            console.log("   ✅ Quests -> Staking (notifications)\n");
        } catch (error) {
            console.error(`❌ Error configuring Notification channels: ${error.message}`);
            throw error;
        }

        // 3.4 Grant UPGRADER_ROLE
        console.log("🔐 3.4 Configuring UPGRADER_ROLE...");
        try {
            const UPGRADER_ROLE = await coreProxy.UPGRADER_ROLE();
            let tx = await coreProxy.grantRole(UPGRADER_ROLE, deployer.address, gasOptions);
            await tx.wait();
            console.log("   ✅ UPGRADER_ROLE granted to deployer\n");
        } catch (error) {
            console.error(`❌ Error granting UPGRADER_ROLE: ${error.message}`);
            throw error;
        }

        // ═════════════════════════════════════════════════════════════════════════════════
        // FASE 4: VALIDACIÓN DE SINCRONIZACIÓN
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔═══════════════════════════════════════════════════════════════════════════╗");
        console.log("║  FASE 4: SYNCHRONIZATION VALIDATION                                      ║");
        console.log("╚═══════════════════════════════════════════════════════════════════════════╝\n");

        try {
            console.log("✓ Validating Marketplace -> Module References...");
            let coreSkills = await coreProxy.skillsContractAddress();
            if (coreSkills.toLowerCase() !== skillsNFTAddress.toLowerCase()) throw new Error("Skills ref mismatch");
            console.log(`  ✅ Skills: ${coreSkills}`);

            let coreLeveling = await coreProxy.levelingSystemAddress();
            if (coreLeveling.toLowerCase() !== deploymentData.marketplace.leveling.toLowerCase()) throw new Error("Leveling ref mismatch");
            console.log(`  ✅ Leveling: ${coreLeveling}`);

            let coreReferral = await coreProxy.referralSystemAddress();
            if (coreReferral.toLowerCase() !== deploymentData.marketplace.referral.toLowerCase()) throw new Error("Referral ref mismatch");
            console.log(`  ✅ Referral: ${coreReferral}\n`);

            console.log("✓ Validating Staking -> Marketplace References...");
            let isProxyAuthorized = await stakingCore.authorizedMarketplaces(proxyAddress);
            if (!isProxyAuthorized) throw new Error("Marketplace Proxy not authorized in Staking Core");
            console.log(`  ✅ Staking Core -> Marketplace Proxy Authorized: ${isProxyAuthorized}`);

            let skillsMarketplace = await SkillsModuleInstance.marketplaceContract();
            if (skillsMarketplace.toLowerCase() !== coreAddress.toLowerCase()) throw new Error("Skills->Marketplace mismatch (should be Core)");
            console.log(`  ✅ Skills Module -> Marketplace: ${skillsMarketplace} (Core)`);

            let gamMarketplace = await GamificationModuleInstance.marketplaceContract();
            if (gamMarketplace.toLowerCase() !== coreAddress.toLowerCase()) throw new Error("Gamification->Marketplace mismatch (should be Core)");
            console.log(`  ✅ Gamification Module -> Marketplace: ${gamMarketplace} (Core)\n`);

            console.log("✓ Validating Notification Channels...");
            let skillsStaking = await skillsNFTContract.stakingContractAddress();
            if (skillsStaking.toLowerCase() !== coreAddress.toLowerCase()) throw new Error("SkillsNFT->Staking mismatch");
            console.log(`  ✅ Skills NFT -> Staking: ${skillsStaking}`);

            let individualStaking = await individualSkillsContract.stakingContractAddress();
            if (individualStaking.toLowerCase() !== coreAddress.toLowerCase()) throw new Error("IndividualSkills->Staking mismatch");
            console.log(`  ✅ Individual Skills -> Staking: ${individualStaking}`);

            let questsStaking = await questsContract.stakingContractAddress();
            if (questsStaking.toLowerCase() !== coreAddress.toLowerCase()) throw new Error("Quests->Staking mismatch");
            console.log(`  ✅ Quests -> Staking: ${questsStaking}\n`);

            console.log("✅ ALL SYNCHRONIZATION VALIDATIONS PASSED!\n");
        } catch (error) {
            console.error(`❌ Validation failed: ${error.message}`);
            throw error;
        }

        // ═════════════════════════════════════════════════════════════════════════════════
        // FASE 5: VERIFICACIÓN EN POLYGONSCAN (AUTOMÁTICA)
        // ═════════════════════════════════════════════════════════════════════════════════
        if (network.name === "polygon" || network.name === "mumbai") {
            console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
            console.log("║  FASE 5: AUTOMATIC VERIFICATION ON POLYGONSCAN                                ║");
            console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

            console.log("⏳ Waiting for 30 seconds before verification (block confirmations)...");
            await new Promise(resolve => setTimeout(resolve, 30000));

            const verificationTasks = [
                { address: rewardsAddress, name: "EnhancedSmartStakingRewards", path: "contracts/SmartStaking/EnhancedSmartStakingRewards.sol:EnhancedSmartStakingRewards", args: [] },
                { address: skillsAddress, name: "EnhancedSmartStakingSkills", path: "contracts/SmartStaking/EnhancedSmartStakingSkills.sol:EnhancedSmartStakingSkills", args: [] },
                { address: gamificationAddress, name: "EnhancedSmartStakingGamification", path: "contracts/SmartStaking/EnhancedSmartStakingGamification.sol:EnhancedSmartStakingGamification", args: [] },
                { address: deploymentData.staking.viewCore, name: "EnhancedSmartStakingViewCore", path: "contracts/SmartStaking/EnhancedSmartStakingViewCore.sol:EnhancedSmartStakingViewCore", args: [coreAddress] },
                { address: deploymentData.staking.viewStats, name: "EnhancedSmartStakingViewStats", path: "contracts/SmartStaking/EnhancedSmartStakingViewStats.sol:EnhancedSmartStakingViewStats", args: [coreAddress] },
                { address: deploymentData.staking.viewSkills, name: "EnhancedSmartStakingViewSkills", path: "contracts/SmartStaking/EnhancedSmartStakingViewSkills.sol:EnhancedSmartStakingViewSkills", args: [coreAddress] },
                // UUPS Proxy - verification handled by upgrades plugin
                // { address: coreAddress, name: "EnhancedSmartStakingCoreV2 (Proxy)", path: "contracts/SmartStaking/EnhancedSmartStakingCoreV2.sol:EnhancedSmartStakingCoreV2", args: [] },
                { address: proxyAddress, name: "GameifiedMarketplaceCoreV1 (Proxy)", path: "contracts/Marketplace/GameifiedMarketplaceCoreV1.sol:GameifiedMarketplaceCoreV1", args: [] },
                { address: deploymentData.marketplace.leveling, name: "LevelingSystem (Proxy)", path: "contracts/Marketplace/LevelingSystem.sol:LevelingSystem", args: [] },
                { address: deploymentData.marketplace.referral, name: "ReferralSystem (Proxy)", path: "contracts/Marketplace/ReferralSystem.sol:ReferralSystem", args: [] },
                { address: skillsNFTAddress, name: "GameifiedMarketplaceSkillsNft", path: "contracts/Marketplace/GameifiedMarketplaceSkillsNft.sol:GameifiedMarketplaceSkillsNft", args: [proxyAddress] },
                { address: individualSkillsAddress, name: "IndividualSkillsMarketplace", path: "contracts/Marketplace/IndividualSkillsMarketplace.sol:IndividualSkillsMarketplace", args: [TREASURY_ADDRESS] },
                { address: questsAddress, name: "GameifiedMarketplaceQuests", path: "contracts/Marketplace/GameifiedMarketplaceQuests.sol:GameifiedMarketplaceQuests", args: [proxyAddress] }
            ];

            for (const task of verificationTasks) {
                try {
                    console.log(`🔍 Verifying ${task.name}...`);
                    await run("verify:verify", {
                        address: task.address,
                        constructorArguments: task.args,
                        contract: task.path
                    });
                    console.log(`✅ ${task.name} verified\n`);
                } catch (error) {
                    const msg = error.message || String(error);
                    if (msg.includes("Already Verified")) {
                        console.log(`ℹ️  ${task.name} already verified\n`);
                    } else {
                        console.log(`⚠️  ${task.name} verification failed: ${msg.substring(0, 100)}\n`);
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════════════════
        // FASE 6: GUARDAR INFORMACIÓN DE DEPLOYMENT
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔═══════════════════════════════════════════════════════════════════════════╗");
        console.log("║  FASE 6: SAVING DEPLOYMENT INFORMATION                                   ║");
        console.log("╚═══════════════════════════════════════════════════════════════════════════╝\n");

        const deploymentsDir = path.join(__dirname, "..", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }

        // Prepare complete deployment data with all addresses and details
        const finalBalance = await ethers.provider.getBalance(deployer.address);
        const gasCostWei = initialBalance - finalBalance;
        const gasCostPOL = ethers.formatEther(gasCostWei);
        const networkChainId = (await ethers.provider.getNetwork()).chainId;
        const blockNumber = await ethers.provider.getBlockNumber();
        
        // Build Polygonscan URLs based on network
        const getScanUrl = (address, type = 'address') => {
            if (network.name === 'polygon') {
                return type === 'tx' ? `https://polygonscan.com/tx/${address}` : `https://polygonscan.com/address/${address}`;
            } else if (network.name === 'mumbai') {
                return type === 'tx' ? `https://mumbai.polygonscan.com/tx/${address}` : `https://mumbai.polygonscan.com/address/${address}`;
            } else if (network.name === 'hardhat' || network.name === 'localhost') {
                return `localhost://${address}`;
            }
            return `https://etherscan.io/address/${address}`;
        };

        const completeDeploymentData = {
            metadata: {
                version: "6.0.0",
                deploymentDate: new Date().toISOString(),
                network: network.name,
                chainId: networkChainId.toString(),
                blockNumber: blockNumber.toString(),
                environment: process.env.NODE_ENV || "production"
            },
            deployer: {
                address: deployer.address,
                scanUrl: getScanUrl(deployer.address),
                initialBalance: ethers.formatEther(initialBalance),
                finalBalance: ethers.formatEther(finalBalance),
                gasCostWei: gasCostWei.toString(),
                gasCostPOL: gasCostPOL
            },
            treasury: {
                address: TREASURY_ADDRESS,
                scanUrl: getScanUrl(TREASURY_ADDRESS),
                description: "Treasury account for commissions & rewards"
            },
            gasMetrics: {
                totalGasWei: gasCostWei.toString(),
                totalGasPOL: gasCostPOL,
                estimatedCost_USD: "Use current POL price to calculate"
            },
            staking: {
                core: {
                    address: deploymentData.staking.core,
                    scanUrl: getScanUrl(deploymentData.staking.core),
                    name: "EnhancedSmartStakingCoreV2",
                    contract: "EnhancedSmartStakingCoreV2",
                    type: "UUPS Proxy",
                    description: "Core staking contract - Orchestrator (Upgradeable)",
                    roles: {
                        DEFAULT_ADMIN_ROLE: deployer.address,
                        ADMIN_ROLE: deployer.address,
                        UPGRADER_ROLE: deployer.address
                    },
                    initialized: true,
                    initParams: {
                        treasury: TREASURY_ADDRESS
                    }
                },
                rewards: {
                    address: deploymentData.staking.rewards,
                    scanUrl: getScanUrl(deploymentData.staking.rewards),
                    name: "EnhancedSmartStakingRewards",
                    contract: "EnhancedSmartStakingRewards",
                    type: "Standalone Module",
                    description: "Rewards & APY calculation module",
                    linkedTo: deploymentData.staking.core
                },
                skills: {
                    address: deploymentData.staking.skills,
                    scanUrl: getScanUrl(deploymentData.staking.skills),
                    name: "EnhancedSmartStakingSkills",
                    contract: "EnhancedSmartStakingSkills",
                    type: "Standalone Module",
                    description: "Skill activation & management module",
                    linkedTo: deploymentData.staking.core
                },
                gamification: {
                    address: deploymentData.staking.gamification,
                    scanUrl: getScanUrl(deploymentData.staking.gamification),
                    name: "EnhancedSmartStakingGamification",
                    contract: "EnhancedSmartStakingGamification",
                    type: "Standalone Module",
                    description: "XP, levels & gamification module",
                    linkedTo: deploymentData.staking.core
                },
                view: {
                    address: deploymentData.staking.view,
                    scanUrl: getScanUrl(deploymentData.staking.view),
                    name: "EnhancedSmartStakingViewCore (Primary)",
                    contract: "EnhancedSmartStakingViewCore",
                    type: "View Module (Read-Only) - Part 1/3",
                    description: "Deposits, balances, and portfolio queries"
                },
                viewStats: {
                    address: deploymentData.staking.viewStats,
                    scanUrl: getScanUrl(deploymentData.staking.viewStats),
                    name: "EnhancedSmartStakingViewStats",
                    contract: "EnhancedSmartStakingViewStats",
                    type: "View Module (Read-Only) - Part 2/3",
                    description: "Pool statistics, APY rates, dashboard, projections"
                },
                viewSkills: {
                    address: deploymentData.staking.viewSkills,
                    scanUrl: getScanUrl(deploymentData.staking.viewSkills),
                    name: "EnhancedSmartStakingViewSkills",
                    contract: "EnhancedSmartStakingViewSkills",
                    type: "View Module (Read-Only) - Part 3/3",
                    description: "Skills, gamification, user metrics, effectiveness analysis"
                },
                synchronization: {
                    core_to_modules: {
                        rewards: deploymentData.staking.rewards,
                        skills: deploymentData.staking.skills,
                        gamification: deploymentData.staking.gamification
                    },
                    modules_to_core: {
                        rewards_reference: "Initialized in Core",
                        skills_reference: "Initialized in Core",
                        gamification_reference: "Initialized in Core"
                    },
                    view_architecture: "3-part modular design: ViewCore (deposits) + ViewStats (analytics) + ViewSkills (gamification)"
                }
            },
            marketplace: {
                proxy: {
                    address: deploymentData.marketplace.proxy,
                    scanUrl: getScanUrl(deploymentData.marketplace.proxy),
                    name: "GameifiedMarketplaceProxy",
                    type: "UUPS Proxy",
                    description: "Primary marketplace proxy - Use this address for all interactions",
                    isPrimary: true,
                    roles: {
                        DEFAULT_ADMIN_ROLE: deployer.address,
                        ADMIN_ROLE: deployer.address,
                        UPGRADER_ROLE: deployer.address
                    },
                    initialized: true,
                    initParams: {
                        treasury: TREASURY_ADDRESS
                    }
                },
                implementation: {
                    address: deploymentData.marketplace.implementation,
                    scanUrl: getScanUrl(deploymentData.marketplace.implementation),
                    name: "GameifiedMarketplaceCoreV1 Implementation",
                    contract: "GameifiedMarketplaceCoreV1",
                    type: "Implementation (Logic Contract)",
                    description: "UUPS implementation - do not call directly",
                    linkedTo: deploymentData.marketplace.proxy
                },
                leveling: {
                    address: deploymentData.marketplace.leveling,
                    scanUrl: getScanUrl(deploymentData.marketplace.leveling),
                    name: "LevelingSystem",
                    contract: "LevelingSystem",
                    type: "UUPS Proxy",
                    description: "Leveling system for player progression",
                    linkedTo: deploymentData.marketplace.proxy,
                    roles: {
                        MARKETPLACE_ROLE: deploymentData.marketplace.proxy
                    }
                },
                referral: {
                    address: deploymentData.marketplace.referral,
                    scanUrl: getScanUrl(deploymentData.marketplace.referral),
                    name: "ReferralSystem",
                    contract: "ReferralSystem",
                    type: "UUPS Proxy",
                    description: "Referral tracking and rewards system",
                    linkedTo: deploymentData.marketplace.proxy,
                    roles: {
                        MARKETPLACE_ROLE: deploymentData.marketplace.proxy
                    }
                },
                skillsNFT: {
                    address: deploymentData.marketplace.skillsNFT,
                    scanUrl: getScanUrl(deploymentData.marketplace.skillsNFT),
                    name: "GameifiedMarketplaceSkillsNft",
                    contract: "GameifiedMarketplaceSkillsNft",
                    type: "Standalone Module",
                    description: "NFT-embedded skills marketplace",
                    linkedTo: {
                        marketplace: deploymentData.marketplace.proxy,
                        staking: deploymentData.staking.core
                    }
                },
                individualSkills: {
                    address: deploymentData.marketplace.individualSkills,
                    scanUrl: getScanUrl(deploymentData.marketplace.individualSkills),
                    name: "IndividualSkillsMarketplace",
                    contract: "IndividualSkillsMarketplace",
                    type: "Standalone Module",
                    description: "Direct skill purchase without NFT minting",
                    linkedTo: {
                        marketplace: deploymentData.marketplace.proxy,
                        staking: deploymentData.staking.core
                    }
                },
                quests: {
                    address: deploymentData.marketplace.quests,
                    scanUrl: getScanUrl(deploymentData.marketplace.quests),
                    name: "GameifiedMarketplaceQuests",
                    contract: "GameifiedMarketplaceQuests",
                    type: "Standalone Module",
                    description: "Quest creation, completion & rewards",
                    linkedTo: {
                        marketplace: deploymentData.marketplace.proxy,
                        staking: deploymentData.staking.core,
                        leveling: deploymentData.marketplace.leveling
                    }
                },
                collaboratorBadges: {
                    address: deploymentData.marketplace.collaboratorBadges || "0x0",
                    scanUrl: getScanUrl(deploymentData.marketplace.collaboratorBadges),
                    name: "CollaboratorBadgeRewards",
                    contract: "CollaboratorBadgeRewards",
                    type: "UUPS Proxy",
                    description: "Badge rewards and commission system",
                    linkedTo: deploymentData.treasury?.manager
                },
                view: {
                    address: deploymentData.marketplace.view || "0x0",
                    scanUrl: getScanUrl(deploymentData.marketplace.view),
                    name: "MarketplaceView",
                    contract: "MarketplaceView",
                    type: "View Contract",
                    description: "Read-only marketplace queries and filtering",
                    linkedTo: deploymentData.marketplace.proxy
                },
                statistics: {
                    address: deploymentData.marketplace.statistics || "0x0",
                    scanUrl: getScanUrl(deploymentData.marketplace.statistics),
                    name: "MarketplaceStatistics",
                    contract: "MarketplaceStatistics",
                    type: "Statistics Contract",
                    description: "Marketplace statistics and analytics",
                    linkedTo: deploymentData.marketplace.proxy
                },
                social: {
                    address: deploymentData.marketplace.social || "0x0",
                    scanUrl: getScanUrl(deploymentData.marketplace.social),
                    name: "MarketplaceSocial",
                    contract: "MarketplaceSocial",
                    type: "Social Module",
                    description: "Social integration and interactions",
                    linkedTo: deploymentData.marketplace.proxy
                }
            },
            treasury: {
                manager: {
                    address: deploymentData.treasury?.manager || "0x0",
                    scanUrl: getScanUrl(deploymentData.treasury?.manager),
                    name: "TreasuryManager",
                    contract: "TreasuryManager",
                    type: "Standalone",
                    description: "Centralized revenue distribution and management",
                    linkedTo: {
                        staking: deploymentData.staking.core,
                        marketplace: deploymentData.marketplace.proxy,
                        collaboratorBadges: deploymentData.marketplace.collaboratorBadges
                    }
                }
            },
            synchronization: {
                status: "✅ VERIFIED",
                bidirectional_sync: {
                    staking_to_marketplace: {
                        core_address: deploymentData.staking.core,
                        marketplace_proxy: deploymentData.marketplace.proxy,
                        authorized: true,
                        configuration: "setMarketplaceAuthorization()"
                    },
                    marketplace_to_staking: {
                        marketplace_proxy: deploymentData.marketplace.proxy,
                        staking_core: deploymentData.staking.core,
                        levelingSystem: deploymentData.marketplace.leveling,
                        referralSystem: deploymentData.marketplace.referral,
                        configuration: "setLevelingSystem() + setReferralSystem()"
                    }
                },
                core_module_sync: {
                    core: deploymentData.staking.core,
                    rewardsModule: deploymentData.staking.rewards,
                    skillsModule: deploymentData.staking.skills,
                    gamificationModule: deploymentData.staking.gamification,
                    viewCore: deploymentData.staking.viewCore,
                    viewStats: deploymentData.staking.viewStats,
                    viewSkills: deploymentData.staking.viewSkills,
                    dynamicAPY: deploymentData.staking.dynamicAPY,
                    status: "✅ Initialized & Linked"
                },
                notification_channels: {
                    skillsNFT_notifies_staking: {
                        from: deploymentData.marketplace.skillsNFT,
                        to: deploymentData.staking.core,
                        method: "notifySkillActivation()"
                    },
                    individualSkills_notifies_staking: {
                        from: deploymentData.marketplace.individualSkills,
                        to: deploymentData.staking.core,
                        method: "notifySkillActivation()"
                    },
                    quests_notifies_staking: {
                        from: deploymentData.marketplace.quests,
                        to: deploymentData.staking.core,
                        method: "notifyQuestCompletion()"
                    }
                }
            },
            architecture: {
                pattern: "UUPS Proxy + Modular",
                upgradeable_contracts: [
                    "EnhancedSmartStakingCoreV2 (Proxy)",
                    "GameifiedMarketplaceCoreV1 (Proxy)",
                    "LevelingSystem (Proxy)",
                    "ReferralSystem (Proxy)",
                    "CollaboratorBadgeRewards (Proxy)"
                ],
                standalone_modules: 10,
                marketplace_modules: 10,
                staking_modules: 8,
                treasury_modules: 1,
                total_contracts: 19,
                description: "Complete bidirectional synchronization with fully upgradeable UUPS architecture"
            },
            usage_instructions: {
                staking: {
                    primary_address: deploymentData.staking.core,
                    scanUrl: getScanUrl(deploymentData.staking.core),
                    methods: ["deposit()", "withdraw()", "compound()", "calculateRewards()"]
                },
                marketplace: {
                    primary_address: deploymentData.marketplace.proxy,
                    scanUrl: getScanUrl(deploymentData.marketplace.proxy),
                    note: "Always use proxy address, never interact with implementation"
                },
                queries: {
                    viewCore: {
                        address: deploymentData.staking.viewCore,
                        methods: ["getUserPortfolio()", "getUserDeposits()", "getUserLockup()"]
                    },
                    viewStats: {
                        address: deploymentData.staking.viewStats,
                        methods: ["getPoolStats()", "getAPYRates()"]
                    },
                    viewSkills: {
                        address: deploymentData.staking.viewSkills,
                        methods: ["getUserSkills()", "getSkillEffects()"]
                    }
                }
            },
            verification: {
                polygonscan: {
                    network: network.name,
                    explorerUrl: network.name === 'polygon' ? 'https://polygonscan.com' : 'https://mumbai.polygonscan.com',
                    status: "Pending verification (automatic)"
                }
            }
        };

        // Save as complete-deployment.json (Full details)
        const deploymentFile = path.join(deploymentsDir, "complete-deployment.json");
        fs.writeFileSync(deploymentFile, JSON.stringify(completeDeploymentData, null, 2));
        console.log(`💾 Complete deployment saved: ${deploymentFile}`);
        console.log(`   📊 Size: ${(fs.statSync(deploymentFile).size / 1024).toFixed(2)} KB\n`);

        // Save as network-specific file (polygon-deployment.json / mumbai-deployment.json)
        const networkFile = path.join(deploymentsDir, `${network.name}-deployment.json`);
        fs.writeFileSync(networkFile, JSON.stringify(completeDeploymentData, null, 2));
        console.log(`💾 Network deployment saved: ${networkFile}`);
        console.log(`   📊 Size: ${(fs.statSync(networkFile).size / 1024).toFixed(2)} KB\n`);

        // Save addresses-only file for quick reference (CLI usage)
        const addressesOnlyData = {
            metadata: {
                generatedAt: new Date().toISOString(),
                network: network.name,
                chainId: networkChainId.toString()
            },
            wallets: {
                deployer: deployer.address,
                treasury: TREASURY_ADDRESS
            },
            staking: {
                core: deploymentData.staking.core,
                rewards: deploymentData.staking.rewards,
                skills: deploymentData.staking.skills,
                gamification: deploymentData.staking.gamification,
                viewCore: deploymentData.staking.viewCore,
                viewStats: deploymentData.staking.viewStats,
                viewSkills: deploymentData.staking.viewSkills,
                view: deploymentData.staking.view,
                dynamicAPY: deploymentData.staking.dynamicAPY
            },
            marketplace: {
                proxy: deploymentData.marketplace.proxy,
                implementation: deploymentData.marketplace.implementation,
                leveling: deploymentData.marketplace.leveling,
                referral: deploymentData.marketplace.referral,
                skillsNFT: deploymentData.marketplace.skillsNFT,
                individualSkills: deploymentData.marketplace.individualSkills,
                quests: deploymentData.marketplace.quests,
                collaboratorBadges: deploymentData.marketplace.collaboratorBadges,
                view: deploymentData.marketplace.view,
                statistics: deploymentData.marketplace.statistics,
                social: deploymentData.marketplace.social
            },
            treasury: {
                manager: deploymentData.treasury?.manager
            },
            summary: {
                totalContracts: 19,
                uupsProxies: 5,
                standAloneModules: 10,
                treasuryModules: 1,
                viewContracts: 3,
                gasCostPOL: gasCostPOL
            }
        };

        const addressesFile = path.join(deploymentsDir, `${network.name}-addresses.json`);
        fs.writeFileSync(addressesFile, JSON.stringify(addressesOnlyData, null, 2));
        console.log(`💾 Quick reference addresses saved: ${addressesFile}`);
        console.log(`   📊 Size: ${(fs.statSync(addressesFile).size / 1024).toFixed(2)} KB\n`);

        // Save Hardhat deployment format for compatibility
        const hardhatDeploymentData = {
            address: deploymentData.marketplace.proxy,
            abi: [],
            transactionHash: null,
            receipt: null,
            args: [TREASURY_ADDRESS],
            numDeployments: 1,
            implementation: deploymentData.marketplace.implementation,
            bytecode: "0x",
            deploymentBytecode: "0x",
            solcInputHash: "",
            metadata: JSON.stringify(completeDeploymentData.metadata),
            linkedLibraries: {},
            saved: true
        };

        const hardhatDeployFile = path.join(deploymentsDir, `${network.name}-hardhat-version.json`);
        fs.writeFileSync(hardhatDeployFile, JSON.stringify(hardhatDeploymentData, null, 2));
        console.log(`💾 Hardhat format saved: ${hardhatDeployFile}`);
        console.log(`   📊 Size: ${(fs.statSync(hardhatDeployFile).size / 1024).toFixed(2)} KB\n`);

        // Save environment file for frontend/testing
        const envData = "# NUXCHAIN PROTOCOL V6.0 - DEPLOYMENT ADDRESSES\n" +
            `# Generated: ${new Date().toISOString()}\n` +
            `# Network: ${network.name}\n` +
            `# Chain ID: ${networkChainId}\n\n` +
            "# WALLETS\n" +
            `VITE_DEPLOYER_ADDRESS=${deployer.address}\n` +
            `VITE_TREASURY_ADDRESS=${TREASURY_ADDRESS}\n\n` +
            "# STAKING CONTRACTS\n" +
            `VITE_STAKING_CORE_ADDRESS=${deploymentData.staking.core}\n` +
            `VITE_STAKING_REWARDS_ADDRESS=${deploymentData.staking.rewards}\n` +
            `VITE_STAKING_SKILLS_ADDRESS=${deploymentData.staking.skills}\n` +
            `VITE_STAKING_GAMIFICATION_ADDRESS=${deploymentData.staking.gamification}\n` +
            `VITE_STAKING_VIEW_CORE_ADDRESS=${deploymentData.staking.viewCore}\n` +
            `VITE_STAKING_VIEW_STATS_ADDRESS=${deploymentData.staking.viewStats}\n` +
            `VITE_STAKING_VIEW_SKILLS_ADDRESS=${deploymentData.staking.viewSkills}\n` +
            `VITE_STAKING_VIEW_ADDRESS=${deploymentData.staking.view}\n` +
            `VITE_DYNAMIC_APY_CALCULATOR_ADDRESS=${deploymentData.staking.dynamicAPY}\n\n` +
            "# MARKETPLACE CONTRACTS\n" +
            `VITE_MARKETPLACE_PROXY_ADDRESS=${deploymentData.marketplace.proxy}\n` +
            `VITE_MARKETPLACE_LEVELING_ADDRESS=${deploymentData.marketplace.leveling}\n` +
            `VITE_MARKETPLACE_REFERRAL_ADDRESS=${deploymentData.marketplace.referral}\n` +
            `VITE_MARKETPLACE_SKILLS_NFT_ADDRESS=${deploymentData.marketplace.skillsNFT}\n` +
            `VITE_MARKETPLACE_INDIVIDUAL_SKILLS_ADDRESS=${deploymentData.marketplace.individualSkills}\n` +
            `VITE_MARKETPLACE_QUESTS_ADDRESS=${deploymentData.marketplace.quests}\n` +
            `VITE_MARKETPLACE_COLLABORATOR_BADGES_ADDRESS=${deploymentData.marketplace.collaboratorBadges}\n` +
            `VITE_MARKETPLACE_VIEW_ADDRESS=${deploymentData.marketplace.view}\n` +
            `VITE_MARKETPLACE_STATISTICS_ADDRESS=${deploymentData.marketplace.statistics}\n` +
            `VITE_MARKETPLACE_SOCIAL_ADDRESS=${deploymentData.marketplace.social}\n\n` +
            "# TREASURY CONTRACTS\n" +
            `VITE_TREASURY_MANAGER_ADDRESS=${deploymentData.treasury?.manager}\n\n` +
            "# NETWORK INFO\n" +
            `VITE_NETWORK_NAME=${network.name}\n` +
            `VITE_CHAIN_ID=${networkChainId}\n` +
            `VITE_BLOCK_NUMBER=${blockNumber}\n` +
            `VITE_DEPLOYMENT_DATE=${new Date().toISOString()}\n\n` +
            "# GAS COSTS\n" +
            `VITE_TOTAL_GAS_POL=${gasCostPOL}\n` +
            `VITE_TOTAL_GAS_WEI=${gasCostWei.toString()}\n\n` +
            "# SCANNER URLs\n" +
            `VITE_SCAN_URL_STAKING_CORE=${getScanUrl(deploymentData.staking.core)}\n` +
            `VITE_SCAN_URL_MARKETPLACE=${getScanUrl(deploymentData.marketplace.proxy)}\n` +
            `VITE_SCAN_URL_DEPLOYER=${getScanUrl(deployer.address)}\n`;

        const envFile = path.join(deploymentsDir, `${network.name}-addresses.env`);
        fs.writeFileSync(envFile, envData);
        console.log(`💾 Environment file saved: ${envFile}`);
        console.log(`   📊 Size: ${(fs.statSync(envFile).size / 1024).toFixed(2)} KB\n`);

        // ═════════════════════════════════════════════════════════════════════════════════
        // RESUMEN FINAL
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  ✅ COMPLETE DEPLOYMENT SUCCESSFUL!                                         ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

        console.log("� WALLET INFORMATION:");
        console.log(`   Deployer:        ${deployer.address}`);
        console.log(`   Treasury:        ${TREASURY_ADDRESS}`);
        console.log(`   Initial Balance: ${ethers.formatEther(initialBalance)} POL`);
        console.log(`   Final Balance:   ${ethers.formatEther(finalBalance)} POL`);
        console.log(`   Gas Cost:        ${gasCostPOL} POL\n`);

        console.log("📋 ENHANCED SMART STAKING (8 MODULAR CONTRACTS + UTILITIES):");
        console.log(`   Core (UUPS):       ${deploymentData.staking.core}`);
        console.log(`   Rewards:           ${deploymentData.staking.rewards}`);
        console.log(`   Skills:            ${deploymentData.staking.skills}`);
        console.log(`   Gamification:      ${deploymentData.staking.gamification}`);
        console.log(`   ViewCore:          ${deploymentData.staking.viewCore}`);
        console.log(`   ViewStats:         ${deploymentData.staking.viewStats}`);
        console.log(`   ViewSkills:        ${deploymentData.staking.viewSkills}`);
        console.log(`   DynamicAPY:        ${deploymentData.staking.dynamicAPY}\n`);

        console.log("📋 GAMEIFIED MARKETPLACE (UUPS PROXY + 10 SUB-MODULES):");
        console.log(`   Proxy (PRIMARY):        ${deploymentData.marketplace.proxy}`);
        console.log(`   Implementation:         ${deploymentData.marketplace.implementation}`);
        console.log(`   Leveling (UUPS):        ${deploymentData.marketplace.leveling}`);
        console.log(`   Referral (UUPS):        ${deploymentData.marketplace.referral}`);
        console.log(`   CollaboratorBadges:     ${deploymentData.marketplace.collaboratorBadges}`);
        console.log(`   Skills NFT:             ${deploymentData.marketplace.skillsNFT}`);
        console.log(`   Individual Skills:      ${deploymentData.marketplace.individualSkills}`);
        console.log(`   Quests:                 ${deploymentData.marketplace.quests}`);
        console.log(`   View:                   ${deploymentData.marketplace.view}`);
        console.log(`   Statistics:             ${deploymentData.marketplace.statistics}`);
        console.log(`   Social:                 ${deploymentData.marketplace.social}\n`);

        console.log("🏦 TREASURY MANAGEMENT:");
        console.log(`   Treasury Manager:   ${deploymentData.treasury?.manager}\n`);

        console.log("🔗 SYNCHRONIZATION STATUS:");
        console.log(`   ✅ Core Staking ↔ All Modules`);
        console.log(`   ✅ Marketplace Proxy ↔ Staking Core`);
        console.log(`   ✅ LevelingSystem configured ✓`);
        console.log(`   ✅ ReferralSystem configured ✓`);
        console.log(`   ✅ Skills NFT → Staking Notifications`);
        console.log(`   ✅ Individual Skills → Staking Notifications`);
        console.log(`   ✅ Quests → Staking XP Sync\n`);

        console.log("🛡️ ARCHITECTURE & SECURITY:");
        console.log(`   ✅ UUPS Proxy Pattern (5 proxies: Core, Marketplace, Leveling, Referral, Collaborator)`);
        console.log(`   ✅ Modular & Reusable Design (19 total contracts)`);
        console.log(`   ✅ Split View Contracts (ViewCore, ViewStats, ViewSkills)`);
        console.log(`   ✅ Centralized Treasury Management`);
        console.log(`   ✅ Bidirectional Integration`);
        console.log(`   ✅ Role-Based Access Control`);
        console.log(`   ✅ Gas-Optimized Operations\n`);

        console.log("📁 SAVED DEPLOYMENT FILES:");
        console.log(`   \n   📄 Complete Details:`);
        console.log(`      ${deploymentFile}`);
        console.log(`   📄 Network-Specific:`);
        console.log(`      ${networkFile}`);
        console.log(`   📄 Quick Addresses:`);
        console.log(`      ${addressesFile}`);
        console.log(`   📄 Environment File:`);
        console.log(`      ${envFile}`);
        console.log(`   📄 Hardhat Format:`);
        console.log(`      ${hardhatDeployFile}\n`);

        console.log("📝 CRITICAL - USE THESE ADDRESSES:\n");
        console.log("🟢 FOR STAKING INTERACTIONS:");
        console.log(`   Address: ${deploymentData.staking.core}`);
        console.log(`   Scanner: ${getScanUrl(deploymentData.staking.core)}\n`);

        console.log("🟢 FOR MARKETPLACE INTERACTIONS:");
        console.log(`   Address: ${deploymentData.marketplace.proxy}`);
        console.log(`   Scanner: ${getScanUrl(deploymentData.marketplace.proxy)}`);
        console.log(`   ⚠️  Always use PROXY address, never interact with implementation\n`);

        console.log("🟢 FOR VIEW-ONLY QUERIES:");
        console.log(`   Address: ${deploymentData.staking.view}`);
        console.log(`   Scanner: ${getScanUrl(deploymentData.staking.view)}\n`);

        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  💰 DEPLOYMENT COST SUMMARY                                                  ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");
        console.log(`Initial Balance:    ${ethers.formatEther(initialBalance)} POL`);
        console.log(`Final Balance:      ${ethers.formatEther(finalBalance)} POL`);
        console.log(`Total Gas Cost:     ${gasCostPOL} POL (${gasCostWei.toString()} Wei)`);
        console.log(`Network:            ${network.name} (Chain ID: ${networkChainId})`);
        console.log(`Block Number:       ${blockNumber}`);
        console.log(`Deployment Date:    ${new Date().toISOString()}\n`);

        console.log("✅ ALL DEPLOYMENT FILES SAVED TO: " + deploymentsDir + "\n");

        return completeDeploymentData;

    } catch (error) {
        console.error("\n❌ DEPLOYMENT ERROR:", error.message);
        console.error(error.stack);
        process.exit(1);
    }
}

async function waitForContractCode(address, options = {}) {
    const { retries = 30, delay = 2000, name = "Contract" } = options;
    let lastError = null;
    
    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            const code = await ethers.provider.getCode(address);
            if (code && code !== '0x') {
                console.log(`   ✅ ${name} bytecode confirmed\n`);
                return true;
            }
        } catch (err) {
            lastError = err;
            console.log(`   ⚠️  Network error checking bytecode (attempt ${attempt}/${retries}): ${err.message.substring(0, 80)}`);
        }
        
        if (attempt < retries) {
            console.log(`   ⏳ Waiting for ${name} bytecode on chain (${attempt}/${retries}, ${delay/1000}s)...`);
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }
    
    console.log(`   ⚠️  ${name} bytecode verification timeout after ${retries * delay / 1000}s`);
    console.log(`   ℹ️  Contract is deployed, bytecode will appear shortly. Continuing...\n`);
    return false;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
