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
 * ✅ ENHANCED SMART STAKING (5 Módulos):
 *    1. EnhancedSmartStakingCore (Core + Deposits/Withdrawals)
 *    2. EnhancedSmartStakingRewards (APY + Compounding)
 *    3. EnhancedSmartStakingSkills (Skill activation/effects)
 *    4. EnhancedSmartStakingGamification (XP + Levels)
 *    5. EnhancedSmartStakingView (View-only queries)
 * 
 * ✅ GAMEIFIED MARKETPLACE (UUPS Proxy + 5 Módulos):
 *    1. GameifiedMarketplaceCoreV1 (NFT creation, listing, buying, offers, XP tracking)
 *    2. GameifiedMarketplaceSkillsV2 (NFT-embedded skills with rarity + expiry)
 *    3. IndividualSkillsMarketplace (Direct skill purchase without NFT minting)
 *    4. GameifiedMarketplaceQuests (Quest creation + completion + rewards)
 *    5. GameifiedMarketplaceProxy (UUPS Proxy for upgradeable Core)
 * 
 * ✅ CARACTERÍSTICAS:
 *    • Sincronización bidireccional completa
 *    • Arquitectura modular y upgradeable
 *    • Validación de interfaces integrada
 *    • Verificación automática en Polygonscan
 *    • Configuración de roles y permisos
 * 
 * @custom:version 6.0.0
 * @custom:security-contact security@nuvo.com
 */

async function main() {
    console.log("\n");
    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🚀 NUXCHAIN PROTOCOL - COMPLETE DEPLOYMENT v6.0                             ║");
    console.log("║                                                                                ║");
    console.log("║  ✅ EnhancedSmartStaking (5 modules - Modular + Reusable View contract)       ║");
    console.log("║  ✅ GameifiedMarketplace (UUPS Proxy + 4 sub-modules)                        ║");
    console.log("║  ✅ Complete Bidirectional Synchronization                                    ║");
    console.log("║  ✅ Interface Validation & Automatic Polygonscan Verification                 ║");
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
    // IMPORTANT: Polygon has minimum priority fee of 25 Gwei, so we use actual values with 10% buffer
    // DO NOT reduce by more than 5% to stay above minimums
    const baseMaxFee = feeData.maxFeePerGas;
    const baseMaxPriority = feeData.maxPriorityFeePerGas;
    
    // Apply 10% buffer (not reduction) to ensure we meet network minimums
    const maxFeePerGas = (baseMaxFee * 110n) / 100n;
    const maxPriorityFeePerGas = (baseMaxPriority * 110n) / 100n;
    
    console.log(`   Base Fee: ${ethers.formatUnits(baseMaxFee, "gwei")} Gwei`);
    console.log(`   Base Priority: ${ethers.formatUnits(baseMaxPriority, "gwei")} Gwei`);
    console.log(`   Final Max Fee: ${ethers.formatUnits(maxFeePerGas, "gwei")} Gwei (+10% buffer)`);
    console.log(`   Final Priority Fee: ${ethers.formatUnits(maxPriorityFeePerGas, "gwei")} Gwei (+10% buffer)\n`);

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
        // FASE 1: DESPLEGAR ENHANCED SMART STAKING (MODULAR - 5 CONTRATOS)
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  FASE 1: ENHANCED SMART STAKING DEPLOYMENT (Modular - 5 Contracts)           ║");
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

        // 1.4 Deploy Core Staking
        console.log("📦 1.4 Deploying EnhancedSmartStakingCore (Core - Orchestrator)...");
        const CoreFactory = await ethers.getContractFactory("EnhancedSmartStaking");
        let stakingCore;
        let coreTx;
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            stakingCore = await CoreFactory.deploy(TREASURY_ADDRESS, gasOptions);
            coreTx = stakingCore.deploymentTransaction();
            console.log(`   📡 TX Hash: ${coreTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${coreTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for confirmations (2-5 minutes)...`);
            
            const deploymentPromise = stakingCore.waitForDeployment();
            const timeoutPromise = new Promise((_, reject) => 
                setTimeout(() => reject(new Error('Timeout after 3 minutes')), 180000)
            );
            await Promise.race([deploymentPromise, timeoutPromise]);
            const coreAddress = await stakingCore.getAddress();
            console.log(`✅ Core Staking (Main): ${coreAddress}\n`);
            deploymentData.staking.core = coreAddress;
            await waitForContractCode(coreAddress, { retries: 20, delay: 3000, name: "Core" });
        } catch (error) {
            console.error(`❌ Error deploying Core: ${error.message}`);
            throw error;
        }

        // 1.5 Deploy View Module (AFTER Core, since it needs Core address)
        console.log("📦 1.5 Deploying EnhancedSmartStakingView (View-only Queries)...");
        const ViewFactory = await ethers.getContractFactory("EnhancedSmartStakingView");
        let viewTx;
        const coreAddress = await stakingCore.getAddress();
        try {
            console.log(`   ⏳ Sending deployment transaction...`);
            const viewContract = await ViewFactory.deploy(coreAddress, gasOptions);
            viewTx = viewContract.deploymentTransaction();
            console.log(`   📡 TX Hash: ${viewTx?.hash || 'pending'}`);
            console.log(`   🔗 View: https://polygonscan.com/tx/${viewTx?.hash || 'pending'}`);
            console.log(`   ⏳ Waiting for confirmations (2-5 minutes)...`);
            
            const deploymentPromise = viewContract.waitForDeployment();
            const timeoutPromise = new Promise((_, reject) => 
                setTimeout(() => reject(new Error('Timeout after 3 minutes')), 180000)
            );
            await Promise.race([deploymentPromise, timeoutPromise]);
            const viewAddress = await viewContract.getAddress();
            console.log(`✅ View Module: ${viewAddress}\n`);
            deploymentData.staking.view = viewAddress;
            await waitForContractCode(viewAddress, { retries: 20, delay: 3000, name: "View" });
        } catch (error) {
            console.error(`❌ Error deploying View: ${error.message}`);
            throw error;
        }

        // 1.6 Configure Core -> Module References (OPTIMIZED: Batch transactions)
        console.log("🔗 1.6 Configuring Core -> Module References...");
        
        const rewardsAddress = deploymentData.staking.rewards;
        const skillsAddress = deploymentData.staking.skills;
        const gamificationAddress = deploymentData.staking.gamification;
        
        // Get contract instances from deployed addresses
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
        console.log("📦 2.4 Deploying GameifiedMarketplaceSkillsV2 (NFT-Embedded Skills)...");
        const SkillsNFTFactory = await ethers.getContractFactory("GameifiedMarketplaceSkillsV2");
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
                { address: deploymentData.staking.view, name: "EnhancedSmartStakingView", path: "contracts/SmartStaking/EnhancedSmartStakingView.sol:EnhancedSmartStakingView", args: [coreAddress] },
                { address: coreAddress, name: "EnhancedSmartStaking", path: "contracts/SmartStaking/EnhancedSmartStakingCore.sol:EnhancedSmartStaking", args: [TREASURY_ADDRESS] },
                { address: proxyAddress, name: "GameifiedMarketplaceCoreV1 (Proxy)", path: "contracts/Marketplace/GameifiedMarketplaceCoreV1.sol:GameifiedMarketplaceCoreV1", args: [] },
                { address: skillsNFTAddress, name: "GameifiedMarketplaceSkillsV2", path: "contracts/Marketplace/GameifiedMarketplaceSkillsV2.sol:GameifiedMarketplaceSkillsV2", args: [proxyAddress] },
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

        // Prepare complete deployment data with all addresses
        const completeDeploymentData = {
            deployment: {
                network: network.name,
                chainId: (await ethers.provider.getNetwork()).chainId.toString(),
                deployer: deployer.address,
                treasury: TREASURY_ADDRESS,
                timestamp: new Date().toISOString(),
                blockNumber: await ethers.provider.getBlockNumber()
            },
            staking: {
                core: {
                    address: deploymentData.staking.core,
                    name: "EnhancedSmartStakingCore",
                    contract: "EnhancedSmartStaking",
                    description: "Core staking contract - Orchestrator"
                },
                rewards: {
                    address: deploymentData.staking.rewards,
                    name: "EnhancedSmartStakingRewards",
                    contract: "EnhancedSmartStakingRewards",
                    description: "Rewards & APY calculation module"
                },
                skills: {
                    address: deploymentData.staking.skills,
                    name: "EnhancedSmartStakingSkills",
                    contract: "EnhancedSmartStakingSkills",
                    description: "Skill activation & management module"
                },
                gamification: {
                    address: deploymentData.staking.gamification,
                    name: "EnhancedSmartStakingGamification",
                    contract: "EnhancedSmartStakingGamification",
                    description: "XP, levels & gamification module"
                },
                view: {
                    address: deploymentData.staking.view,
                    name: "EnhancedSmartStakingView",
                    contract: "EnhancedSmartStakingView",
                    description: "View-only queries contract (Read-only)"
                }
            },
            marketplace: {
                proxy: {
                    address: deploymentData.marketplace.proxy,
                    name: "GameifiedMarketplaceProxy",
                    contract: "GameifiedMarketplaceProxy",
                    description: "UUPS Proxy - Use this for all marketplace interactions",
                    isPrimary: true
                },
                implementation: {
                    address: deploymentData.marketplace.implementation,
                    name: "GameifiedMarketplaceCoreV1",
                    contract: "GameifiedMarketplaceCoreV1",
                    description: "Implementation logic (UUPS)"
                },
                leveling: {
                    address: deploymentData.marketplace.leveling,
                    name: "LevelingSystem",
                    contract: "LevelingSystem",
                    description: "Leveling System (UUPS Proxy)"
                },
                referral: {
                    address: deploymentData.marketplace.referral,
                    name: "ReferralSystem",
                    contract: "ReferralSystem",
                    description: "Referral System (UUPS Proxy)"
                },
                skillsNFT: {
                    address: deploymentData.marketplace.skillsNFT,
                    name: "GameifiedMarketplaceSkillsV2",
                    contract: "GameifiedMarketplaceSkillsV2",
                    description: "NFT-embedded skills marketplace"
                },
                individualSkills: {
                    address: deploymentData.marketplace.individualSkills,
                    name: "IndividualSkillsMarketplace",
                    contract: "IndividualSkillsMarketplace",
                    description: "Direct skill purchase without NFT minting"
                },
                quests: {
                    address: deploymentData.marketplace.quests,
                    name: "GameifiedMarketplaceQuests",
                    contract: "GameifiedMarketplaceQuests",
                    description: "Quest creation, completion & rewards"
                }
            },
            synchronization: {
                bidirectional: {
                    staking_marketplace: {
                        status: "✅ SYNCHRONIZED",
                        staking_to_marketplace: deploymentData.marketplace.proxy,
                        marketplace_to_staking: deploymentData.staking.core
                    },
                    core_modules: {
                        status: "✅ SYNCHRONIZED",
                        core: deploymentData.staking.core,
                        rewards: deploymentData.staking.rewards,
                        skills: deploymentData.staking.skills,
                        gamification: deploymentData.staking.gamification
                    },
                    notifications: {
                        status: "✅ CONFIGURED",
                        skillsNFT_to_staking: deploymentData.marketplace.skillsNFT,
                        individualSkills_to_staking: deploymentData.marketplace.individualSkills,
                        quests_to_staking: deploymentData.marketplace.quests
                    }
                }
            },
            architecture: {
                pattern: "UUPS Proxy + Modular",
                staking_modules: 5,
                marketplace_modules: 4,
                description: "Complete bidirectional synchronization with modular architecture"
            }
        };

        // Save as complete-deployment.json
        const deploymentFile = path.join(deploymentsDir, "complete-deployment.json");
        fs.writeFileSync(deploymentFile, JSON.stringify(completeDeploymentData, null, 2));
        console.log(`💾 Complete deployment saved: ${deploymentFile}\n`);

        // Save as network-specific file (polygon-deployment.json)
        const networkFile = path.join(deploymentsDir, `${network.name}-deployment.json`);
        fs.writeFileSync(networkFile, JSON.stringify(completeDeploymentData, null, 2));
        console.log(`💾 Network deployment saved: ${networkFile}\n`);

        // Save a simple addresses-only file for quick reference
        const addressesOnlyData = {
            network: network.name,
            chainId: (await ethers.provider.getNetwork()).chainId.toString(),
            timestamp: new Date().toISOString(),
            staking: {
                core: deploymentData.staking.core,
                rewards: deploymentData.staking.rewards,
                skills: deploymentData.staking.skills,
                gamification: deploymentData.staking.gamification,
                view: deploymentData.staking.view
            },
            marketplace: {
                proxy: deploymentData.marketplace.proxy,
                implementation: deploymentData.marketplace.implementation,
                skillsNFT: deploymentData.marketplace.skillsNFT,
                individualSkills: deploymentData.marketplace.individualSkills,
                quests: deploymentData.marketplace.quests
            }
        };

        const addressesFile = path.join(deploymentsDir, `${network.name}-addresses.json`);
        fs.writeFileSync(addressesFile, JSON.stringify(addressesOnlyData, null, 2));
        console.log(`💾 Quick reference addresses saved: ${addressesFile}\n`);

        // ═════════════════════════════════════════════════════════════════════════════════
        // RESUMEN FINAL
        // ═════════════════════════════════════════════════════════════════════════════════
        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  ✅ COMPLETE DEPLOYMENT SUCCESSFUL!                                         ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

        console.log("📋 ENHANCED SMART STAKING (5 MODULAR CONTRACTS):");
        console.log(`   Core (Main):       ${deploymentData.staking.core}`);
        console.log(`   Rewards Module:    ${deploymentData.staking.rewards}`);
        console.log(`   Skills Module:     ${deploymentData.staking.skills}`);
        console.log(`   Gamification:      ${deploymentData.staking.gamification}`);
        console.log(`   View Module:       ${deploymentData.staking.view}\n`);

        console.log("📋 GAMEIFIED MARKETPLACE (UUPS PROXY + 4 SUB-MODULES):");
        console.log(`   Proxy (PRIMARY):   ${deploymentData.marketplace.proxy}`);
        console.log(`   Implementation:    ${deploymentData.marketplace.implementation}`);
        console.log(`   Skills NFT:        ${deploymentData.marketplace.skillsNFT}`);
        console.log(`   Individual Skills: ${deploymentData.marketplace.individualSkills}`);
        console.log(`   Quests:            ${deploymentData.marketplace.quests}\n`);

        console.log("🔗 SYNCHRONIZATION STATUS:");
        console.log(`   ✅ Core Staking ↔ All Modules`);
        console.log(`   ✅ Marketplace Proxy ↔ Staking Core`);
        console.log(`   ✅ Skills NFT → Staking Notifications`);
        console.log(`   ✅ Individual Skills → Staking Notifications`);
        console.log(`   ✅ Quests → Staking XP Sync\n`);

        console.log("🛡️ ARCHITECTURE & SECURITY:");
        console.log(`   ✅ Modular & Reusable Design`);
        console.log(`   ✅ UUPS Proxy Pattern (Upgradeable)`);
        console.log(`   ✅ Separated View Contract (Read-Only)`);
        console.log(`   ✅ Bidirectional Integration`);
        console.log(`   ✅ Gas-Optimized Operations\n`);

        console.log("📝 CRITICAL - USE THESE ADDRESSES:\n");
        console.log("🟢 FOR STAKING: Use EnhancedSmartStakingCore");
        console.log(`   Address: ${deploymentData.staking.core}\n`);
        console.log("🟢 FOR MARKETPLACE: Use GameifiedMarketplaceProxy (UUPS)");
        console.log(`   Address: ${deploymentData.marketplace.proxy}\n`);
        console.log("🟢 FOR QUERIES: Use EnhancedSmartStakingView (read-only)");
        console.log(`   Address: ${deploymentData.staking.view}\n`);

        // Calculate and display gas costs
        const finalBalance = await ethers.provider.getBalance(deployer.address);
        const gasCostPOL = ethers.formatEther(initialBalance - finalBalance);
        const gasCostWei = initialBalance - finalBalance;
        
        console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
        console.log("║  💰 DEPLOYMENT COST SUMMARY                                                  ║");
        console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");
        console.log(`Initial Balance:    ${ethers.formatEther(initialBalance)} POL`);
        console.log(`Final Balance:      ${ethers.formatEther(finalBalance)} POL`);
        console.log(`Total Gas Cost:     ${gasCostPOL} POL (${gasCostWei.toString()} Wei)\n`);

        return deploymentData;

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
