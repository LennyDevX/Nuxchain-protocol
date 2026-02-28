const hre = require("hardhat");
const { ethers } = hre;
const fs = require("fs");

// EIP-1967 implementation slot
const IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

async function getImplementationAddress(proxyAddress) {
    const raw = await ethers.provider.getStorage(proxyAddress, IMPL_SLOT);
    return "0x" + raw.slice(-40);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function verifyContract(address, contract, constructorArguments = [], label = "") {
    const tag = label || contract;
    try {
        await hre.run("verify:verify", {
            address,
            contract,
            constructorArguments,
        });
        console.log(`   ✅ ${tag} verified`);
        return true;
    } catch (err) {
        if (
            err.message?.includes("Already Verified") ||
            err.message?.includes("already verified") ||
            err.message?.includes("Contract source code already verified")
        ) {
            console.log(`   ⏭️  ${tag} already verified`);
            return true;
        }
        console.error(`   ❌ ${tag} FAILED: ${err.message}`);
        return false;
    }
}

async function main() {
    console.log("\n╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  🔍 BATCH POLYGONSCAN VERIFICATION - NUXCHAIN PROTOCOL v6.0                 ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    // Load addresses
    const addresses = JSON.parse(fs.readFileSync("./deployments/polygon-addresses.json", "utf8"));
    const complete = JSON.parse(fs.readFileSync("./deployments/polygon-deployment.json", "utf8"));

    let passed = 0;
    let failed = 0;
    const results = [];

    // ──────────────────────────────────────────────────────────────────────────
    // STANDALONE / NON-PROXY CONTRACTS
    // ──────────────────────────────────────────────────────────────────────────

    const STAKING_CORE    = addresses.staking.core;
    const MARKETPLACE     = addresses.marketplace.proxy;
    const TREASURY_WALLET = complete.deployer.address === addresses.wallets?.deployer
        ? (addresses.wallets?.treasury || process.env.TREASURY_ADDRESS)
        : process.env.TREASURY_ADDRESS;
    const DEPLOYER        = complete.deployer.address;
    const TREASURY_MGR    = addresses.treasury.manager;

    const standalones = [
        {
            address: TREASURY_MGR,
            contract: "contracts/Treasury/TreasuryManager.sol:TreasuryManager",
            label: "TreasuryManager",
            args: [],
        },
        {
            address: addresses.staking.rewards,
            contract: "contracts/SmartStaking/EnhancedSmartStakingRewards.sol:EnhancedSmartStakingRewards",
            label: "EnhancedSmartStakingRewards",
            args: [],
        },
        {
            address: addresses.staking.skills,
            contract: "contracts/SmartStaking/EnhancedSmartStakingSkills.sol:EnhancedSmartStakingSkills",
            label: "EnhancedSmartStakingSkills",
            args: [],
        },
        {
            address: addresses.staking.gamification,
            contract: "contracts/SmartStaking/EnhancedSmartStakingGamification.sol:EnhancedSmartStakingGamification",
            label: "EnhancedSmartStakingGamification",
            args: [],
        },
        {
            address: addresses.staking.viewCore || addresses.staking.view,
            contract: "contracts/SmartStaking/EnhancedSmartStakingViewCore.sol:EnhancedSmartStakingViewCore",
            label: "EnhancedSmartStakingViewCore",
            args: [STAKING_CORE],
        },
        {
            address: addresses.staking.viewStats,
            contract: "contracts/SmartStaking/EnhancedSmartStakingViewStats.sol:EnhancedSmartStakingViewStats",
            label: "EnhancedSmartStakingViewStats",
            args: [STAKING_CORE],
        },
        {
            address: addresses.staking.viewSkills,
            contract: "contracts/SmartStaking/EnhancedSmartStakingViewSkills.sol:EnhancedSmartStakingViewSkills",
            label: "EnhancedSmartStakingViewSkills",
            args: [STAKING_CORE],
        },
        {
            address: addresses.staking.dynamicAPY,
            contract: "contracts/SmartStaking/DynamicAPYCalculator.sol:DynamicAPYCalculator",
            label: "DynamicAPYCalculator",
            args: [],
        },
        {
            address: addresses.marketplace.skillsNFT,
            contract: "contracts/Marketplace/GameifiedMarketplaceSkillsNft.sol:GameifiedMarketplaceSkillsNft",
            label: "GameifiedMarketplaceSkillsNft",
            args: [MARKETPLACE],
        },
        {
            address: addresses.marketplace.individualSkills,
            contract: "contracts/Marketplace/IndividualSkillsMarketplace.sol:IndividualSkillsMarketplace",
            label: "IndividualSkillsMarketplace",
            args: [process.env.TREASURY_ADDRESS],
        },
        {
            address: addresses.marketplace.quests,
            contract: "contracts/Marketplace/GameifiedMarketplaceQuests.sol:GameifiedMarketplaceQuests",
            label: "GameifiedMarketplaceQuests",
            args: [MARKETPLACE],
        },
        {
            address: addresses.marketplace.view,
            contract: "contracts/Marketplace/MarketplaceView.sol:MarketplaceView",
            label: "MarketplaceView",
            args: [DEPLOYER, MARKETPLACE],
        },
        {
            address: addresses.marketplace.statistics,
            contract: "contracts/Marketplace/MarketplaceStatistics.sol:MarketplaceStatistics",
            label: "MarketplaceStatistics",
            args: [DEPLOYER, MARKETPLACE],
        },
        {
            address: addresses.marketplace.social,
            contract: "contracts/Marketplace/MarketplaceSocial.sol:MarketplaceSocial",
            label: "MarketplaceSocial",
            args: [DEPLOYER, MARKETPLACE],
        },
    ];

    // Add SkillViewLib if present
    if (addresses.staking?.skillViewLib) {
        standalones.push({
            address: addresses.staking.skillViewLib,
            contract: "contracts/SmartStaking/SkillViewLib.sol:SkillViewLib",
            label: "SkillViewLib",
        });
    }

    console.log("╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 1 — STANDALONE CONTRACTS                                              ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    for (const c of standalones) {
        if (!c.address || c.address === "undefined") {
            console.log(`   ⚠️  ${c.label} — address not found, skipping`);
            continue;
        }
        process.stdout.write(`   ⏳ Verifying ${c.label} (${c.address})...\n`);
        const ok = await verifyContract(c.address, c.contract, c.args || [], c.label);
        ok ? passed++ : failed++;
        results.push({ label: c.label, address: c.address, ok });
        await sleep(1500); // avoid Polygonscan rate limit
    }

    // ──────────────────────────────────────────────────────────────────────────
    // UUPS PROXY CONTRACTS — verify the implementation
    // ──────────────────────────────────────────────────────────────────────────

    const proxies = [
        {
            proxy: addresses.staking.core,
            contract: "contracts/SmartStaking/EnhancedSmartStakingCoreV2.sol:EnhancedSmartStakingCoreV2",
            label: "EnhancedSmartStakingCoreV2 (impl)",
        },
        {
            proxy: addresses.marketplace.proxy,
            contract: "contracts/Marketplace/GameifiedMarketplaceCoreV1.sol:GameifiedMarketplaceCoreV1",
            label: "GameifiedMarketplaceCoreV1 (impl)",
        },
        {
            proxy: addresses.marketplace.leveling,
            contract: "contracts/Marketplace/LevelingSystem.sol:LevelingSystem",
            label: "LevelingSystem (impl)",
        },
        {
            proxy: addresses.marketplace.referral,
            contract: "contracts/Marketplace/ReferralSystem.sol:ReferralSystem",
            label: "ReferralSystem (impl)",
        },
        {
            proxy: addresses.marketplace.collaboratorBadges,
            contract: "contracts/Marketplace/CollaboratorBadgeRewards.sol:CollaboratorBadgeRewards",
            label: "CollaboratorBadgeRewards (impl)",
        },
    ];

    console.log("\n╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  PHASE 2 — UUPS PROXY IMPLEMENTATIONS                                       ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    for (const p of proxies) {
        if (!p.proxy || p.proxy === "undefined") {
            console.log(`   ⚠️  ${p.label} — proxy address not found, skipping`);
            continue;
        }
        let implAddress;
        try {
            implAddress = await getImplementationAddress(p.proxy);
            if (!implAddress || implAddress === "0x0000000000000000000000000000000000000000") {
                throw new Error("zero address");
            }
        } catch (e) {
            console.error(`   ❌ ${p.label} — could not read impl slot: ${e.message}`);
            failed++;
            results.push({ label: p.label, address: p.proxy, ok: false });
            continue;
        }
        console.log(`   🔎 ${p.label}: proxy=${p.proxy} → impl=${implAddress}`);
        const ok = await verifyContract(implAddress, p.contract, [], p.label);
        ok ? passed++ : failed++;
        results.push({ label: p.label, address: implAddress, ok });
        await sleep(1500);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // SUMMARY
    // ──────────────────────────────────────────────────────────────────────────

    console.log("\n╔════════════════════════════════════════════════════════════════════════════════╗");
    console.log("║  VERIFICATION SUMMARY                                                        ║");
    console.log("╚════════════════════════════════════════════════════════════════════════════════╝\n");

    for (const r of results) {
        console.log(`   ${r.ok ? "✅" : "❌"} ${r.label}`);
        if (!r.ok) console.log(`      └─ ${r.address}`);
    }

    console.log(`\n📊 Results: ${passed} passed · ${failed} failed · ${passed + failed} total`);

    if (failed > 0) {
        console.log("\n⚠️  Some contracts failed. Common causes:");
        console.log("   • API rate limit — wait 1 min and re-run (already-verified contracts are skipped)");
        console.log("   • Wrong contract path — check the contracts/ folder structure");
        console.log("   • Compiler settings mismatch — verify hardhat.config.cjs overrides match");
    } else {
        console.log("\n🎉 All contracts verified on Polygonscan!");
    }
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });
