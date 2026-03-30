#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const FRONTEND_DIR = path.join(ROOT, "frontend");
const ABI_JSON_PATH = path.join(FRONTEND_DIR, "abis", "all-abis.json");
const ABI_RUNTIME_PATH = path.join(FRONTEND_DIR, "abis", "runtime.js");
const CONFIG_TS_PATH = path.join(FRONTEND_DIR, "config", "contracts.config.ts");
const DEPLOYMENT_PATH = path.join(ROOT, "deployments", "complete-deployment.json");
const GENERATED_JSON_PATH = path.join(FRONTEND_DIR, "config", "contracts.generated.json");
const GENERATED_TS_PATH = path.join(FRONTEND_DIR, "config", "contracts.generated.ts");
const GENERATED_JS_PATH = path.join(FRONTEND_DIR, "config", "contracts.generated.js");

const FRONTEND_ADDRESS_MAP = {
    StakingCore: ["staking", "core"],
    StakingRewards: ["staking", "rewards"],
    StakingSkills: ["staking", "power"],
    StakingGamification: ["staking", "gamification"],
    StakingViewCore: ["staking", "viewCore"],
    StakingViewStats: ["staking", "viewStats"],
    StakingViewSkills: ["staking", "viewSkills"],
    StakingViewDashboard: ["staking", "viewDashboard"],
    DynamicAPYCalculator: ["staking", "dynamicAPY"],
    SkillViewLib: ["staking", "skillViewLib"],
    MarketplaceProxy: ["marketplace", "core"],
    MarketplaceLeveling: ["marketplace", "leveling"],
    MarketplaceReferral: ["marketplace", "referral"],
    MarketplaceSkillsNFT: ["marketplace", "nuxPowerNft"],
    IndividualSkills: ["marketplace", "nuxPowerMarketplace"],
    QuestCore: ["marketplace", "questCore"],
    CollaboratorBadges: ["marketplace", "collaboratorRewards"],
    MarketplaceView: ["marketplace", "view"],
    MarketplaceStatistics: ["marketplace", "statistics"],
    MarketplaceSocial: ["marketplace", "social"],
    TreasuryManager: ["treasury", "manager"],
    QuestRewardsPool: ["treasury", "questRewardsPool"]
};

function fileExists(filePath) {
    return fs.existsSync(filePath);
}

function loadJson(filePath) {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function readSource(filePath) {
    return fs.readFileSync(filePath, "utf8");
}

function extractConstObject(source, constName) {
    const regex = new RegExp(`export const ${constName}(?::[^=]+)? = \\{([\\s\\S]*?)\\n\\};`);
    const match = source.match(regex);

    if (!match) {
        return null;
    }

    const objectLiteral = `{${match[1]}\n}`
        .replace(/\/\/.*$/gm, "")
        .trim();

    return Function(`"use strict"; return (${objectLiteral});`)();
}

function normalizeDeploymentContracts(deployment) {
    const contractGroups = deployment.contracts || deployment;
    const addresses = {};

    for (const [frontendKey, [group, key]] of Object.entries(FRONTEND_ADDRESS_MAP)) {
        const value = contractGroups[group] && contractGroups[group][key];
        if (typeof value === "string" && value.startsWith("0x")) {
            addresses[frontendKey] = value;
        }
    }

    return {
        meta: {
            source: "deployment",
            network: deployment.deployment?.network || "polygon",
            chainId: Number(deployment.deployment?.chainId || 137),
            generatedAt: new Date().toISOString(),
            deploymentTimestamp: deployment.deployment?.timestamp || null,
            deployer: deployment.deployment?.deployer || null
        },
        addresses,
        wallets: {}
    };
}

function normalizeManualConfig() {
    const source = readSource(CONFIG_TS_PATH);
    const addresses = extractConstObject(source, "CONTRACT_ADDRESSES") || {};
    const wallets = extractConstObject(source, "WALLET_ADDRESSES") || {};

    return {
        meta: {
            source: "contracts.config.ts",
            network: "polygon",
            chainId: 137,
            generatedAt: new Date().toISOString(),
            deploymentTimestamp: null,
            deployer: wallets.deployer || null
        },
        addresses,
        wallets
    };
}

function buildGeneratedTs(data) {
    return `/**
 * Auto-generated frontend contract config.
 * Source: ${data.meta.source}
 * Generated: ${data.meta.generatedAt}
 */

export interface GeneratedContractAddresses {
${Object.keys(data.addresses).map((key) => `  ${key}: string;`).join("\n")}
}

export interface GeneratedWalletAddresses {
${Object.keys(data.wallets).map((key) => `  ${key}: string;`).join("\n")}
}

export const GENERATED_METADATA = ${JSON.stringify(data.meta, null, 2)} as const;

export const CONTRACT_ADDRESSES: GeneratedContractAddresses = ${JSON.stringify(data.addresses, null, 2)};

export const WALLET_ADDRESSES: GeneratedWalletAddresses = ${JSON.stringify(data.wallets, null, 2)};
`;
}

function buildGeneratedJs(data) {
    return `/**
 * Auto-generated frontend contract config.
 * Source: ${data.meta.source}
 * Generated: ${data.meta.generatedAt}
 */

export const GENERATED_METADATA = ${JSON.stringify(data.meta, null, 2)};

export const CONTRACT_ADDRESSES = ${JSON.stringify(data.addresses, null, 2)};

export const WALLET_ADDRESSES = ${JSON.stringify(data.wallets, null, 2)};
`;
}

function buildAbiRuntime(allAbis) {
    const contractNames = Object.keys(allAbis).sort();
    let content = `/**\n * Auto-generated runtime ABI exports.\n */\n\n`;
    content += `import abiCatalog from "./all-abis.json" with { type: "json" };\n\n`;

    for (const contractName of contractNames) {
        content += `export const ${contractName} = abiCatalog["${contractName}"].abi;\n`;
    }

    content += `\nexport const AllABIs = Object.fromEntries(\n`;
    content += `  Object.entries(abiCatalog).map(([name, value]) => [name, value.abi])\n`;
    content += `);\n\n`;
    content += `export default AllABIs;\n`;

    return content;
}

function main() {
    if (!fileExists(ABI_JSON_PATH)) {
        throw new Error("all-abis.json not found. Run scripts/ExportABIs.cjs first.");
    }

    const allAbis = loadJson(ABI_JSON_PATH);
    const configData = fileExists(DEPLOYMENT_PATH)
        ? normalizeDeploymentContracts(loadJson(DEPLOYMENT_PATH))
        : normalizeManualConfig();

    fs.writeFileSync(ABI_RUNTIME_PATH, buildAbiRuntime(allAbis));
    fs.writeFileSync(GENERATED_JSON_PATH, JSON.stringify(configData, null, 2));
    fs.writeFileSync(GENERATED_TS_PATH, buildGeneratedTs(configData));
    fs.writeFileSync(GENERATED_JS_PATH, buildGeneratedJs(configData));

    console.log("✅ Frontend package artifacts generated");
    console.log(`   ABI runtime: ${path.relative(ROOT, ABI_RUNTIME_PATH)}`);
    console.log(`   Config JSON: ${path.relative(ROOT, GENERATED_JSON_PATH)}`);
    console.log(`   Config TS: ${path.relative(ROOT, GENERATED_TS_PATH)}`);
    console.log(`   Config JS: ${path.relative(ROOT, GENERATED_JS_PATH)}`);
}

main();