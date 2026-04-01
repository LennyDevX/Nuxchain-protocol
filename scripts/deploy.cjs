#!/usr/bin/env node
"use strict";

/**
 * ╔══════════════════════════════════════════════════════════════════╗
 * ║  NUXCHAIN PROTOCOL — FULL DEPLOYMENT SCRIPT                    ║
 * ║                                                                  ║
 * ║  Phase 0 · TreasuryManager                                      ║
 * ║  Phase 1 · SmartStaking (11 contracts + library)                ║
 * ║  Phase 2 · Marketplace   (10 contracts)                         ║
 * ║  Phase 3 · NFT Agents    (10 proxies + 1 TBA impl + 1 view)    ║
 * ║                                                                  ║
 * ║  Total: ~35 contracts deployed + configured                     ║
 * ║                                                                  ║
 * ║  Usage:                                                          ║
 * ║    npx hardhat run scripts/deploy.cjs --network polygon          ║
 * ╚══════════════════════════════════════════════════════════════════╝
 */

const { ethers, network, upgrades } = require("hardhat");
const fs   = require("fs");
const path = require("path");
require("dotenv").config({ override: true });

// ─── helpers ────────────────────────────────────────────────────────────────

const DEPLOYMENTS_DIR = path.join(__dirname, "..", "deployments");
const COMPLETE_DEPLOYMENT_FILE = path.join(DEPLOYMENTS_DIR, "complete-deployment.json");
const IN_PROGRESS_DEPLOYMENT_FILE = path.join(DEPLOYMENTS_DIR, "deployment-in-progress.json");
const ADDRESSES_FILE = path.join(DEPLOYMENTS_DIR, "addresses.json");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function writeJsonSafely(filePath, value) {
    const json = JSON.stringify(value, null, 2);
    const tempFile = `${filePath}.tmp`;
    const backupFile = `${filePath}.bak`;

    fs.writeFileSync(tempFile, json);

    if (fs.existsSync(filePath)) {
        fs.copyFileSync(filePath, backupFile);
        fs.rmSync(filePath, { force: true });
    }

    fs.renameSync(tempFile, filePath);

    if (fs.existsSync(backupFile)) {
        fs.rmSync(backupFile, { force: true });
    }
}

function normalizeForJson(value) {
    if (typeof value === "bigint") {
        return value.toString();
    }

    if (Array.isArray(value)) {
        return value.map((item) => normalizeForJson(item));
    }

    if (value && typeof value === "object") {
        return Object.fromEntries(
            Object.entries(value).map(([key, item]) => [key, normalizeForJson(item)])
        );
    }

    return value;
}

function hashInitializerArgs(args) {
    return ethers.id(JSON.stringify(normalizeForJson(args)));
}

function parseEtherEnv(name, fallbackValue) {
    return ethers.parseEther(process.env[name] ?? fallbackValue);
}

function recordProxyMetadata(data, key, deployment) {
    data.proxyMetadata[key] = {
        contract: deployment.label,
        kind: "uups",
        proxy: deployment.address,
        implementation: deployment.implementation,
        initializerArgsHash: deployment.initializerArgsHash,
        upgraderHolder: deployment.upgraderHolder,
    };
}

async function waitForCode(address, { name = address, retries = 20, delay = 3000 } = {}) {
    for (let i = 0; i < retries; i++) {
        const code = await ethers.provider.getCode(address);
        if (code && code !== "0x") return;
        process.stdout.write(`   ⏳ Waiting for ${name} bytecode... (${i + 1}/${retries})\r`);
        await sleep(delay);
    }
    console.warn(`\n   ⚠️  ${name}: bytecode not detected after ${retries} retries`);
}

async function deployPlain(factory, args, label) {
    process.stdout.write(`\n📦 Deploying ${label}...\n`);
    const c = args.length ? await factory.deploy(...args) : await factory.deploy();
    const tx = c.deploymentTransaction();
    if (tx) console.log(`   TX: ${tx.hash}`);
    await c.waitForDeployment();
    const addr = await c.getAddress();
    console.log(`   ✅ ${label}: ${addr}`);
    await waitForCode(addr, { name: label });
    return { contract: c, address: addr };
}

async function deployUUPS(factory, initArgs, label, upgraderHolder = null) {
    process.stdout.write(`\n📦 Deploying ${label} (UUPS proxy)...\n`);
    const c = await upgrades.deployProxy(factory, initArgs, {
        initializer: "initialize",
        kind: "uups",
        unsafeAllowLinkedLibraries: true,
    });
    await c.waitForDeployment();
    const addr = await c.getAddress();
    const implementation = await upgrades.erc1967.getImplementationAddress(addr);
    console.log(`   ✅ ${label} proxy: ${addr}`);
    console.log(`   ↳ ${label} implementation: ${implementation}`);
    await waitForCode(addr, { name: label });
    await waitForCode(implementation, { name: `${label} implementation` });
    return {
        contract: c,
        address: addr,
        implementation,
        initializerArgsHash: hashInitializerArgs(initArgs),
        upgraderHolder,
        label,
    };
}

function createDeploymentState(networkName, chainId, deployer) {
    return {
        deployment: {
            network: networkName,
            chainId,
            deployer,
            timestamp: new Date().toISOString(),
            status: "in-progress",
            currentPhase: null,
        },
        proxyMetadata: {},
        contracts: {
            treasury: {},
            staking: {},
            marketplace: {},
            nft: {},
        },
    };
}

function validateLoadedDeployment(data, expected) {
    if (!data?.deployment) {
        throw new Error("❌ deployment-in-progress.json is malformed");
    }

    const mismatches = [];
    if (data.deployment.network !== expected.networkName) {
        mismatches.push(`network=${data.deployment.network}`);
    }
    if (String(data.deployment.chainId) !== String(expected.chainId)) {
        mismatches.push(`chainId=${data.deployment.chainId}`);
    }
    if (ethers.getAddress(data.deployment.deployer) !== ethers.getAddress(expected.deployer)) {
        mismatches.push(`deployer=${data.deployment.deployer}`);
    }

    if (mismatches.length > 0) {
        throw new Error(`❌ deployment-in-progress.json belongs to a different deployment context (${mismatches.join(", ")})`);
    }
}

function loadDeploymentState(expected) {
    fs.mkdirSync(DEPLOYMENTS_DIR, { recursive: true });

    if (!fs.existsSync(IN_PROGRESS_DEPLOYMENT_FILE)) {
        return createDeploymentState(expected.networkName, expected.chainId, expected.deployer);
    }

    const data = JSON.parse(fs.readFileSync(IN_PROGRESS_DEPLOYMENT_FILE, "utf8"));
    validateLoadedDeployment(data, expected);

    data.proxyMetadata = data.proxyMetadata || {};
    data.contracts = data.contracts || {};
    data.contracts.treasury = data.contracts.treasury || {};
    data.contracts.staking = data.contracts.staking || {};
    data.contracts.marketplace = data.contracts.marketplace || {};
    data.contracts.nft = data.contracts.nft || {};
    data.deployment.timestamp = data.deployment.timestamp || new Date().toISOString();
    data.deployment.status = "in-progress";

    return data;
}

function writeFlatAddresses(data) {
    const flat = {};
    for (const [section, entries] of Object.entries(data.contracts)) {
        for (const [key, val] of Object.entries(entries)) {
            flat[`${section}.${key}`] = val;
        }
    }
    writeJsonSafely(ADDRESSES_FILE, flat);
}

function persistDeploymentState(data, { complete = false, currentPhase = null } = {}) {
    fs.mkdirSync(DEPLOYMENTS_DIR, { recursive: true });

    data.deployment.timestamp = data.deployment.timestamp || new Date().toISOString();
    data.deployment.status = complete ? "completed" : "in-progress";
    data.deployment.updatedAt = new Date().toISOString();
    if (currentPhase) {
        data.deployment.currentPhase = currentPhase;
    }

    if (complete) {
        data.deployment.completedAt = new Date().toISOString();
        writeJsonSafely(COMPLETE_DEPLOYMENT_FILE, data);
        if (fs.existsSync(IN_PROGRESS_DEPLOYMENT_FILE)) {
            fs.rmSync(IN_PROGRESS_DEPLOYMENT_FILE, { force: true });
        }
        console.log(`\n💾 Deployment data saved to deployments/complete-deployment.json`);
    } else {
        writeJsonSafely(IN_PROGRESS_DEPLOYMENT_FILE, data);
    }

    writeFlatAddresses(data);
}

async function deployOrAttachPlain(data, section, key, factory, args, label, currentPhase) {
    const existingAddress = data.contracts?.[section]?.[key];
    if (existingAddress) {
        console.log(`\n↻ Reusing ${label}: ${existingAddress}`);
        await waitForCode(existingAddress, { name: label });
        return { contract: factory.attach(existingAddress), address: existingAddress };
    }

    const deployment = await deployPlain(factory, args, label);
    data.contracts[section][key] = deployment.address;
    persistDeploymentState(data, { currentPhase });
    return deployment;
}

async function deployOrAttachUUPS(data, section, key, metadataKey, factory, initArgs, label, currentPhase, upgraderHolder = null) {
    const existingAddress = data.contracts?.[section]?.[key];
    if (existingAddress) {
        console.log(`\n↻ Reusing ${label} proxy: ${existingAddress}`);
        await waitForCode(existingAddress, { name: label });
        const implementation = await upgrades.erc1967.getImplementationAddress(existingAddress);
        await waitForCode(implementation, { name: `${label} implementation` });

        const deployment = {
            contract: factory.attach(existingAddress),
            address: existingAddress,
            implementation,
            initializerArgsHash: hashInitializerArgs(initArgs),
            upgraderHolder,
            label,
        };

        if (!data.proxyMetadata[metadataKey]) {
            recordProxyMetadata(data, metadataKey, deployment);
            persistDeploymentState(data, { currentPhase });
        }

        return deployment;
    }

    const deployment = await deployUUPS(factory, initArgs, label, upgraderHolder);
    data.contracts[section][key] = deployment.address;
    recordProxyMetadata(data, metadataKey, deployment);
    persistDeploymentState(data, { currentPhase });
    return deployment;
}

// ─── main ───────────────────────────────────────────────────────────────────

async function main() {
    const TREASURY_ADDRESS = process.env.TREASURY_ADDRESS;
    if (!TREASURY_ADDRESS) throw new Error("❌ TREASURY_ADDRESS not set in .env");

    const [deployer] = await ethers.getSigners();
    const balance    = await ethers.provider.getBalance(deployer.address);
    const chainId    = (await ethers.provider.getNetwork()).chainId;

    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🚀 NUXCHAIN PROTOCOL — FULL DEPLOYMENT                                    ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");
    console.log(`\n   Deployer  : ${deployer.address}`);
    console.log(`   Balance   : ${ethers.formatEther(balance)} POL`);
    console.log(`   Network   : ${network.name} (chainId ${chainId})`);
    console.log(`   Treasury  : ${TREASURY_ADDRESS}\n`);

    const d = loadDeploymentState({
        networkName: network.name,
        chainId: chainId.toString(),
        deployer: deployer.address,
    });

    if (fs.existsSync(IN_PROGRESS_DEPLOYMENT_FILE)) {
        console.log(`   Resume    : deployments/deployment-in-progress.json (${d.deployment.currentPhase || "checkpoint available"})`);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PHASE 0 — TREASURY MANAGER
    // ══════════════════════════════════════════════════════════════════════════
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 0 · TREASURY                                                        ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");

    const nftDefaultValidator = process.env.NUXAGENT_VALIDATOR || deployer.address;
    const nftErc6551ImplementationFromEnv = process.env.NUXAGENT_ERC6551_IMPL || process.env.ERC6551_IMPLEMENTATION || null;
    const defaultAgentMintFee = process.env.NUXAGENT_MINT_FEE || "0";
    const agentMintFees = {
        social: parseEtherEnv("NUXAGENT_SOCIAL_MINT_FEE", defaultAgentMintFee),
        tech: parseEtherEnv("NUXAGENT_TECH_MINT_FEE", defaultAgentMintFee),
        marketing: parseEtherEnv("NUXAGENT_MARKETING_MINT_FEE", defaultAgentMintFee),
        finance: parseEtherEnv("NUXAGENT_FINANCE_MINT_FEE", defaultAgentMintFee),
        business: parseEtherEnv("NUXAGENT_BUSINESS_MINT_FEE", defaultAgentMintFee),
    };

    if (d.contracts?.nft?.erc6551Implementation && nftErc6551ImplementationFromEnv) {
        const checkpointImplementation = ethers.getAddress(d.contracts.nft.erc6551Implementation);
        const configuredImplementation = ethers.getAddress(nftErc6551ImplementationFromEnv);
        if (checkpointImplementation !== configuredImplementation) {
            throw new Error(`❌ ERC-6551 implementation mismatch between checkpoint (${checkpointImplementation}) and env (${configuredImplementation})`);
        }
    }

    if (!d.contracts?.nft?.erc6551Implementation && !nftErc6551ImplementationFromEnv) {
        console.log("   ℹ️  NUXAGENT_ERC6551_IMPL not set; a local NuxAgentAccount6551 implementation will be deployed automatically.");
    }

    const TreasuryF = await ethers.getContractFactory("TreasuryManager");
    const { contract: treasury, address: treasuryAddr } = await deployOrAttachPlain(
        d,
        "treasury",
        "manager",
        TreasuryF,
        [],
        "TreasuryManager",
        "PHASE 0 · TREASURY"
    );

    const QuestRewardsF = await ethers.getContractFactory("QuestRewardsPool");
    const questRewardsDeployment = await deployOrAttachUUPS(
        d,
        "treasury",
        "questRewardsPool",
        "treasury.questRewardsPool",
        QuestRewardsF,
        [deployer.address, treasuryAddr],
        "QuestRewardsPool",
        "PHASE 0 · TREASURY",
        deployer.address
    );
    const { contract: questRewards, address: questRewardsAddr } = questRewardsDeployment;
    persistDeploymentState(d, { currentPhase: "PHASE 0 · TREASURY COMPLETE" });

    // ══════════════════════════════════════════════════════════════════════════
    // PHASE 1 — SMART STAKING (11 contracts + 1 library)
    // ══════════════════════════════════════════════════════════════════════════
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 1 · SMART STAKING                                                   ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");

    // 1.1 Deploy independent modules first (no cross-deps)
    const RewardsF = await ethers.getContractFactory("SmartStakingRewards");
    const { contract: stakingRewards, address: stakingRewardsAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "rewards",
        RewardsF,
        [],
        "SmartStakingRewards",
        "PHASE 1 · SMART STAKING"
    );

    const PowerF = await ethers.getContractFactory("SmartStakingPower");
    const { contract: stakingPower, address: stakingPowerAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "power",
        PowerF,
        [],
        "SmartStakingPower",
        "PHASE 1 · SMART STAKING"
    );

    const GamF = await ethers.getContractFactory("Gamification");
    const { contract: stakingGam, address: stakingGamAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "gamification",
        GamF,
        [],
        "Gamification",
        "PHASE 1 · SMART STAKING"
    );

    const APYF = await ethers.getContractFactory("DynamicAPYCalculator");
    const { address: apyAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "dynamicAPY",
        APYF,
        [],
        "DynamicAPYCalculator",
        "PHASE 1 · SMART STAKING"
    );

    // 1.2 Deploy external libraries required by Core
    const LibF = await ethers.getContractFactory("SkillViewLib");
    const { address: skillViewLibAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "skillViewLib",
        LibF,
        [],
        "SkillViewLib",
        "PHASE 1 · SMART STAKING"
    );

    const CoreLibF = await ethers.getContractFactory("SmartStakingCoreLib");
    const { address: coreLibAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "coreLib",
        CoreLibF,
        [],
        "SmartStakingCoreLib",
        "PHASE 1 · SMART STAKING"
    );

    // 1.3 Deploy Core (UUPS proxy — links to library)
    const CoreF = await ethers.getContractFactory("SmartStakingCore", {
        libraries: {
            SkillViewLib: skillViewLibAddr,
            SmartStakingCoreLib: coreLibAddr,
        },
    });
    const stakingCoreDeployment = await deployOrAttachUUPS(
        d,
        "staking",
        "core",
        "staking.core",
        CoreF,
        [TREASURY_ADDRESS],
        "SmartStakingCore",
        "PHASE 1 · SMART STAKING",
        deployer.address
    );
    const { contract: stakingCore, address: stakingCoreAddr } = stakingCoreDeployment;

    // 1.4 Deploy view contracts (need Core address)
    const ViewCoreF = await ethers.getContractFactory("SmartStakingViewCore");
    const { address: viewCoreAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "viewCore",
        ViewCoreF,
        [stakingCoreAddr],
        "SmartStakingViewCore",
        "PHASE 1 · SMART STAKING"
    );

    const ViewStatsF = await ethers.getContractFactory("SmartStakingViewStats");
    const { address: viewStatsAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "viewStats",
        ViewStatsF,
        [stakingCoreAddr],
        "SmartStakingViewStats",
        "PHASE 1 · SMART STAKING"
    );

    const ViewSkillsF = await ethers.getContractFactory("SmartStakingViewSkills");
    const { address: viewSkillsAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "viewSkills",
        ViewSkillsF,
        [stakingCoreAddr],
        "SmartStakingViewSkills",
        "PHASE 1 · SMART STAKING"
    );

    // 1.5 Deploy SmartStakingViewDashboard (needs core + all module addresses)
    const ViewDashF = await ethers.getContractFactory("SmartStakingViewDashboard");
    const { address: viewDashAddr } = await deployOrAttachPlain(
        d,
        "staking",
        "viewDashboard",
        ViewDashF,
        [stakingCoreAddr, stakingRewardsAddr, stakingPowerAddr, stakingGamAddr],
        "SmartStakingViewDashboard",
        "PHASE 1 · SMART STAKING"
    );

    // ── Staking phase wiring ─────────────────────────────────────────────────
    console.log("\n🔗 Wiring SmartStaking modules...");

    // Core → modules
    const tx1 = await stakingCore.setRewardsModule(stakingRewardsAddr);
    const tx2 = await stakingCore.setPowerModule(stakingPowerAddr);
    const tx3 = await stakingCore.setGamificationModule(stakingGamAddr);
    await Promise.all([tx1.wait(1), tx2.wait(1), tx3.wait(1)]);
    console.log("   ✅ Core → Rewards / Power / Gamification");

    // Core → TreasuryManager
    const tx4 = await stakingCore.setTreasuryManager(treasuryAddr);
    await tx4.wait(1);
    console.log("   ✅ Core → TreasuryManager");

    // Rewards → Core
    const tx5 = await stakingRewards.setCoreContract(stakingCoreAddr);
    await tx5.wait(1);
    console.log("   ✅ Rewards → Core");

    // Power → Core
    const tx6 = await stakingPower.setCoreStakingContract(stakingCoreAddr);
    await tx6.wait(1);
    console.log("   ✅ Power → Core");

    // Gamification → Core
    const tx7 = await stakingGam.setCoreStakingContract(stakingCoreAddr);
    await tx7.wait(1);
    console.log("   ✅ Gamification → Core");

    // TreasuryManager authorizes Core as revenue source
    const tx8 = await treasury.authorizeSource(stakingCoreAddr);
    await tx8.wait(1);
    console.log("   ✅ TreasuryManager: Core authorized");
    persistDeploymentState(d, { currentPhase: "PHASE 1 · SMART STAKING COMPLETE" });

    // ══════════════════════════════════════════════════════════════════════════
    // PHASE 2 — MARKETPLACE (10 contracts)
    // ══════════════════════════════════════════════════════════════════════════
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 2 · MARKETPLACE                                                     ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");

    // 2.1 LevelingSystem + ReferralSystem (UUPS, no deps on marketplace core yet)
    const LevelingF = await ethers.getContractFactory("LevelingSystem");
    const levelingDeployment = await deployOrAttachUUPS(
        d,
        "marketplace",
        "leveling",
        "marketplace.leveling",
        LevelingF,
        [deployer.address],
        "LevelingSystem",
        "PHASE 2 · MARKETPLACE",
        deployer.address
    );
    const { contract: leveling, address: levelingAddr } = levelingDeployment;

    const ReferralF = await ethers.getContractFactory("ReferralSystem");
    const referralDeployment = await deployOrAttachUUPS(
        d,
        "marketplace",
        "referral",
        "marketplace.referral",
        ReferralF,
        [deployer.address],
        "ReferralSystem",
        "PHASE 2 · MARKETPLACE",
        deployer.address
    );
    const { contract: referral, address: referralAddr } = referralDeployment;

    // 2.2 MarketplaceCore (UUPS proxy)
    const MktCoreLibF = await ethers.getContractFactory("MarketplaceCoreLib");
    const { address: marketplaceCoreLibAddr } = await deployOrAttachPlain(
        d,
        "marketplace",
        "coreLib",
        MktCoreLibF,
        [],
        "MarketplaceCoreLib",
        "PHASE 2 · MARKETPLACE"
    );

    const MktCoreF = await ethers.getContractFactory("MarketplaceCore", {
        libraries: { MarketplaceCoreLib: marketplaceCoreLibAddr },
    });
    const marketplaceCoreDeployment = await deployOrAttachUUPS(
        d,
        "marketplace",
        "core",
        "marketplace.core",
        MktCoreF,
        [TREASURY_ADDRESS],
        "MarketplaceCore",
        "PHASE 2 · MARKETPLACE",
        deployer.address
    );
    const { contract: mktCore, address: mktCoreAddr } = marketplaceCoreDeployment;

    // 2.3 Sub-modules that need marketplace core address
    const MktViewF = await ethers.getContractFactory("MarketplaceView");
    const { contract: mktView, address: mktViewAddr } = await deployOrAttachPlain(
        d,
        "marketplace",
        "view",
        MktViewF,
        [deployer.address, mktCoreAddr],
        "MarketplaceView",
        "PHASE 2 · MARKETPLACE"
    );

    const MktStatsF = await ethers.getContractFactory("MarketplaceStatistics");
    const { contract: mktStats, address: mktStatsAddr } = await deployOrAttachPlain(
        d,
        "marketplace",
        "statistics",
        MktStatsF,
        [deployer.address, mktCoreAddr],
        "MarketplaceStatistics",
        "PHASE 2 · MARKETPLACE"
    );

    const MktSocialF = await ethers.getContractFactory("MarketplaceSocial");
    const { contract: mktSocial, address: mktSocialAddr } = await deployOrAttachPlain(
        d,
        "marketplace",
        "social",
        MktSocialF,
        [deployer.address, mktCoreAddr],
        "MarketplaceSocial",
        "PHASE 2 · MARKETPLACE"
    );

    const NuxPowerNftF = await ethers.getContractFactory("NuxPowerNft");
    const { contract: nuxPowerNft, address: nuxPowerNftAddr } = await deployOrAttachPlain(
        d,
        "marketplace",
        "nuxPowerNft",
        NuxPowerNftF,
        [mktCoreAddr],
        "NuxPowerNft",
        "PHASE 2 · MARKETPLACE"
    );

    const NuxPowerMktF = await ethers.getContractFactory("NuxPowerMarketplace");
    const { contract: nuxPowerMkt, address: nuxPowerMktAddr } = await deployOrAttachPlain(
        d,
        "marketplace",
        "nuxPowerMarketplace",
        NuxPowerMktF,
        [treasuryAddr],
        "NuxPowerMarketplace",
        "PHASE 2 · MARKETPLACE"
    );

    // 2.4 QuestCore (UUPS proxy, needs core address)
    const QuestCoreF = await ethers.getContractFactory("QuestCore");
    const questCoreDeployment = await deployOrAttachUUPS(
        d,
        "marketplace",
        "questCore",
        "marketplace.questCore",
        QuestCoreF,
        [deployer.address, mktCoreAddr],
        "QuestCore",
        "PHASE 2 · MARKETPLACE",
        deployer.address
    );
    const { contract: questCore, address: questCoreAddr } = questCoreDeployment;

    // 2.5 CollaboratorBadgeRewards (UUPS proxy)
    const CollabF = await ethers.getContractFactory("CollaboratorBadgeRewards");
    const collabDeployment = await deployOrAttachUUPS(
        d,
        "marketplace",
        "collaboratorRewards",
        "marketplace.collaboratorRewards",
        CollabF,
        [],
        "CollaboratorBadgeRewards",
        "PHASE 2 · MARKETPLACE",
        deployer.address
    );
    const { contract: collab, address: collabAddr } = collabDeployment;

    // ── Marketplace phase wiring ─────────────────────────────────────────────
    console.log("\n🔗 Wiring Marketplace modules...");

    const MARKETPLACE_ROLE = ethers.id("MARKETPLACE_ROLE");
    const ADMIN_ROLE        = await mktCore.ADMIN_ROLE();

    // Connect View / Statistics / Social to Core
    const mw1 = await mktCore.setViewModule(mktViewAddr);
    const mw2 = await mktCore.setStatisticsModule(mktStatsAddr);
    const mw3 = await mktCore.setSocialModule(mktSocialAddr);
    await Promise.all([mw1.wait(1), mw2.wait(1), mw3.wait(1)]);
    console.log("   ✅ Core → View / Statistics / Social");

    // Connect social module to view module (for comment queries)
    const mw4 = await mktView.setSocialModule(mktSocialAddr);
    const mw5 = await mktView.setStatisticsModule(mktStatsAddr);
    await Promise.all([mw4.wait(1), mw5.wait(1)]);
    console.log("   ✅ View → Social / Statistics");

    // Core → TreasuryManager
    const mw6 = await mktCore.setTreasuryManager(treasuryAddr);
    await mw6.wait(1);
    console.log("   ✅ Core → TreasuryManager");

    // Core → external systems
    const mw7 = await mktCore.setSkillsContract(nuxPowerNftAddr);
    const mw8 = await mktCore.setLevelingSystem(levelingAddr);
    const mw9 = await mktCore.setReferralSystem(referralAddr);
    await Promise.all([mw7.wait(1), mw8.wait(1), mw9.wait(1)]);
    console.log("   ✅ Core → Skills / Leveling / Referral");

    // Grant MARKETPLACE_ROLE in Leveling + Referral to Core
    const mr1 = await leveling.grantRole(MARKETPLACE_ROLE, mktCoreAddr);
    const mr2 = await referral.grantRole(MARKETPLACE_ROLE, mktCoreAddr);
    await Promise.all([mr1.wait(1), mr2.wait(1)]);
    console.log("   ✅ Leveling / Referral: MARKETPLACE_ROLE → Core");

    // Grant ADMIN_ROLE to Quest + NuxPowerNft contracts (so they can call updateUserXP etc.)
    const mr3 = await mktCore.grantRole(ADMIN_ROLE, questCoreAddr);
    const mr4 = await mktCore.grantRole(ADMIN_ROLE, nuxPowerNftAddr);
    await Promise.all([mr3.wait(1), mr4.wait(1)]);
    console.log("   ✅ Core: ADMIN_ROLE → QuestCore / NuxPowerNft");

    // NuxPowerNft treasury
    const mr5 = await nuxPowerNft.setTreasuryAddress(TREASURY_ADDRESS);
    await mr5.wait(1);
    console.log("   ✅ NuxPowerNft → treasury");

    // QuestCore → Core
    const mr6 = await questCore.setCoreContract(mktCoreAddr);
    await mr6.wait(1);
    console.log("   ✅ QuestCore → Core");

    // TreasuryManager authorizes Marketplace Core
    const mr7 = await treasury.authorizeSource(mktCoreAddr);
    await mr7.wait(1);
    console.log("   ✅ TreasuryManager: MarketplaceCore authorized");

    // Link staking ↔ marketplace (so staking bonuses apply in MP context)
    const mr8 = await mktCore.setStakingContract(stakingCoreAddr);
    await mr8.wait(1);
    console.log("   ✅ Marketplace Core → StakingCore");
    persistDeploymentState(d, { currentPhase: "PHASE 2 · MARKETPLACE COMPLETE" });

    // ══════════════════════════════════════════════════════════════════════════
    // PHASE 3 — NFT AGENTS
    // ══════════════════════════════════════════════════════════════════════════
    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 3 · NFT AGENTS                                                      ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");

    if (!d.contracts.nft.erc6551Implementation && nftErc6551ImplementationFromEnv) {
        d.contracts.nft.erc6551Implementation = nftErc6551ImplementationFromEnv;
        persistDeploymentState(d, { currentPhase: "PHASE 3 · NFT AGENTS" });
    }

    const Account6551F = await ethers.getContractFactory("NuxAgentAccount6551");
    const { address: nftErc6551Implementation } = await deployOrAttachPlain(
        d,
        "nft",
        "erc6551Implementation",
        Account6551F,
        [],
        "NuxAgentAccount6551",
        "PHASE 3 · NFT AGENTS"
    );

    const RegistryF = await ethers.getContractFactory("NuxAgentRegistry");
    const registryDeployment = await deployOrAttachUUPS(
        d,
        "nft",
        "registry",
        "nft.registry",
        RegistryF,
        [deployer.address],
        "NuxAgentRegistry",
        "PHASE 3 · NFT AGENTS",
        deployer.address
    );
    const { contract: agentRegistry, address: agentRegistryAddr } = registryDeployment;

    const FactoryF = await ethers.getContractFactory("NuxAgentFactory");
    const factoryDeployment = await deployOrAttachUUPS(
        d,
        "nft",
        "factory",
        "nft.factory",
        FactoryF,
        [deployer.address, treasuryAddr],
        "NuxAgentFactory",
        "PHASE 3 · NFT AGENTS",
        deployer.address
    );
    const { contract: agentFactory, address: agentFactoryAddr } = factoryDeployment;

    const PaymasterF = await ethers.getContractFactory("NuxAgentPaymaster");
    const paymasterDeployment = await deployOrAttachUUPS(
        d,
        "nft",
        "paymaster",
        "nft.paymaster",
        PaymasterF,
        [deployer.address, treasuryAddr],
        "NuxAgentPaymaster",
        "PHASE 3 · NFT AGENTS",
        deployer.address
    );
    const { contract: agentPaymaster, address: agentPaymasterAddr } = paymasterDeployment;

    const RentalF = await ethers.getContractFactory("NuxAgentRental");
    const rentalDeployment = await deployOrAttachUUPS(
        d,
        "nft",
        "rental",
        "nft.rental",
        RentalF,
        [deployer.address, treasuryAddr],
        "NuxAgentRental",
        "PHASE 3 · NFT AGENTS",
        deployer.address
    );
    const { contract: agentRental, address: agentRentalAddr } = rentalDeployment;

    const MiniGameF = await ethers.getContractFactory("NuxAgentMiniGame");
    const miniGameDeployment = await deployOrAttachUUPS(
        d,
        "nft",
        "miniGame",
        "nft.miniGame",
        MiniGameF,
        [deployer.address, agentRegistryAddr, nftDefaultValidator],
        "NuxAgentMiniGame",
        "PHASE 3 · NFT AGENTS",
        deployer.address
    );
    const { contract: agentMiniGame, address: agentMiniGameAddr } = miniGameDeployment;

    const categorySpecs = [
        {
            key: "socialAgent",
            contractName: "SocialAgentNFT",
            categoryId: 0,
            mintFee: agentMintFees.social,
        },
        {
            key: "techAgent",
            contractName: "TechAgentNFT",
            categoryId: 1,
            mintFee: agentMintFees.tech,
        },
        {
            key: "marketingAgent",
            contractName: "MarketingAgentNFT",
            categoryId: 2,
            mintFee: agentMintFees.marketing,
        },
        {
            key: "financeAgent",
            contractName: "FinanceAgentNFT",
            categoryId: 3,
            mintFee: agentMintFees.finance,
        },
        {
            key: "businessAgent",
            contractName: "BusinessAgentNFT",
            categoryId: 4,
            mintFee: agentMintFees.business,
        },
    ];

    const deployedCategoryContracts = [];
    for (const spec of categorySpecs) {
        const CategoryF = await ethers.getContractFactory(spec.contractName);
        const categoryDeployment = await deployOrAttachUUPS(
            d,
            "nft",
            spec.key,
            `nft.${spec.key}`,
            CategoryF,
            [
                deployer.address,
                treasuryAddr,
                levelingAddr,
                nftErc6551Implementation,
                spec.mintFee,
            ],
            spec.contractName,
            "PHASE 3 · NFT AGENTS",
            deployer.address
        );
        deployedCategoryContracts.push({
            ...spec,
            contract: categoryDeployment.contract,
            address: categoryDeployment.address,
        });
    }

    const AgentViewF = await ethers.getContractFactory("NuxAgentView");
    const { address: agentViewAddr } = await deployOrAttachPlain(
        d,
        "nft",
        "agentView",
        AgentViewF,
        [],
        "NuxAgentView",
        "PHASE 3 · NFT AGENTS"
    );

    console.log("\n🔗 Wiring NFT agent suite...");

    await (await agentFactory.setAgentRegistry(agentRegistryAddr)).wait(1);
    await (await agentRental.setAgentRegistry(agentRegistryAddr)).wait(1);
    await (await agentMiniGame.setTreasuryManager(treasuryAddr)).wait(1);
    console.log("   ✅ Factory / Rental / MiniGame configured");

    await (await agentRegistry.grantValidatorRole(nftDefaultValidator)).wait(1);
    console.log("   ✅ Registry: VALIDATOR_ROLE → default validator");

    await (await agentRegistry.grantGameRole(agentMiniGameAddr)).wait(1);
    console.log("   ✅ Registry: GAME_ROLE → MiniGame");

    for (const category of deployedCategoryContracts) {
        const factoryRole = await category.contract.FACTORY_ROLE();
        const roleTx = await category.contract.grantRole(factoryRole, agentFactoryAddr);
        const registryTx = await category.contract.setAgentRegistry(agentRegistryAddr);
        const rentalTx = await category.contract.setRentalContract(agentRentalAddr);
        await Promise.all([roleTx.wait(1), registryTx.wait(1), rentalTx.wait(1)]);

        const factoryCategoryTx = await agentFactory.setCategoryContract(category.categoryId, category.address);
        const registerCategoryTx = await agentRegistry.registerNFTContract(category.address);
        const rentalSupportTx = await agentRental.setSupportedNFTContract(category.address, true);
        const miniGameSupportTx = await agentMiniGame.setSupportedNFTContract(category.address, true);
        await Promise.all([
            factoryCategoryTx.wait(1),
            registerCategoryTx.wait(1),
            rentalSupportTx.wait(1),
            miniGameSupportTx.wait(1),
        ]);

        console.log(`   ✅ ${category.contractName}: factory + registry + rental wiring complete`);
    }

    const treasurySources = [
        ...deployedCategoryContracts.map((category) => category.address),
        agentPaymasterAddr,
        agentRentalAddr,
        agentMiniGameAddr,
    ];

    for (const source of treasurySources) {
        await (await treasury.authorizeSource(source)).wait(1);
    }
    console.log("   ✅ TreasuryManager: NFT revenue sources authorized");
    persistDeploymentState(d, { currentPhase: "PHASE 3 · NFT AGENTS COMPLETE" });

    // ══════════════════════════════════════════════════════════════════════════
    // SAVE & SUMMARY
    // ══════════════════════════════════════════════════════════════════════════
    persistDeploymentState(d, { complete: true, currentPhase: "COMPLETED" });

    const finalBal = await ethers.provider.getBalance(deployer.address);
    const spent    = balance - finalBal;

    console.log("\n╔══════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🎉 DEPLOYMENT COMPLETE                                                    ║");
    console.log("╚══════════════════════════════════════════════════════════════════════════════╝");
    console.log(`\n   POL spent   : ${ethers.formatEther(spent)}`);
    console.log(`   Final bal   : ${ethers.formatEther(finalBal)}`);
    console.log("\n   Contract summary:");
    console.log(`     TreasuryManager          : ${d.contracts.treasury.manager}`);
    console.log(`     QuestRewardsPool         : ${d.contracts.treasury.questRewardsPool}`);
    console.log(`     SmartStakingCore         : ${d.contracts.staking.core}`);
    console.log(`     SmartStakingRewards      : ${d.contracts.staking.rewards}`);
    console.log(`     SmartStakingPower        : ${d.contracts.staking.power}`);
    console.log(`     Gamification            : ${d.contracts.staking.gamification}`);
    console.log(`     DynamicAPYCalculator     : ${d.contracts.staking.dynamicAPY}`);
    console.log(`     SmartStakingViewCore     : ${d.contracts.staking.viewCore}`);
    console.log(`     SmartStakingViewStats    : ${d.contracts.staking.viewStats}`);
    console.log(`     SmartStakingViewSkills   : ${d.contracts.staking.viewSkills}`);
    console.log(`     SmartStakingViewDashboard: ${d.contracts.staking.viewDashboard}`);
    console.log(`     MarketplaceCore          : ${d.contracts.marketplace.core}`);
    console.log(`     LevelingSystem           : ${d.contracts.marketplace.leveling}`);
    console.log(`     ReferralSystem           : ${d.contracts.marketplace.referral}`);
    console.log(`     MarketplaceView          : ${d.contracts.marketplace.view}`);
    console.log(`     MarketplaceStatistics    : ${d.contracts.marketplace.statistics}`);
    console.log(`     MarketplaceSocial        : ${d.contracts.marketplace.social}`);
    console.log(`     NuxPowerNft              : ${d.contracts.marketplace.nuxPowerNft}`);
    console.log(`     NuxPowerMarketplace      : ${d.contracts.marketplace.nuxPowerMarketplace}`);
    console.log(`     QuestCore                : ${d.contracts.marketplace.questCore}`);
    console.log(`     CollaboratorBadgeRewards : ${d.contracts.marketplace.collaboratorRewards}`);
    console.log(`     NuxAgentRegistry         : ${d.contracts.nft.registry}`);
    console.log(`     NuxAgentFactory          : ${d.contracts.nft.factory}`);
    console.log(`     NuxAgentPaymaster        : ${d.contracts.nft.paymaster}`);
    console.log(`     NuxAgentRental           : ${d.contracts.nft.rental}`);
    console.log(`     NuxAgentMiniGame         : ${d.contracts.nft.miniGame}`);
    console.log(`     NuxAgentAccount6551      : ${d.contracts.nft.erc6551Implementation}`);
    console.log(`     SocialAgentNFT           : ${d.contracts.nft.socialAgent}`);
    console.log(`     TechAgentNFT             : ${d.contracts.nft.techAgent}`);
    console.log(`     MarketingAgentNFT        : ${d.contracts.nft.marketingAgent}`);
    console.log(`     FinanceAgentNFT          : ${d.contracts.nft.financeAgent}`);
    console.log(`     BusinessAgentNFT         : ${d.contracts.nft.businessAgent}`);
    console.log(`     NuxAgentView             : ${d.contracts.nft.agentView}`);
    console.log("\n   ✅ Run next steps:");
    console.log("      npx hardhat run scripts/fund.cjs --network polygon");
    console.log("      npx hardhat run scripts/verify.cjs --network polygon\n");
}

main()
    .then(() => process.exit(0))
    .catch((err) => { console.error(err); process.exit(1); });
