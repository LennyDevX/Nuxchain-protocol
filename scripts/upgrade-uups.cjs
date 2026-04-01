#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { ethers, upgrades, network } = require("hardhat");
require("dotenv").config({ override: true });

function parseArgs(argv) {
    const parsed = {};

    for (let i = 0; i < argv.length; i++) {
        const token = argv[i];
        if (!token.startsWith("--")) continue;

        const key = token.slice(2);
        const next = argv[i + 1];
        if (!next || next.startsWith("--")) {
            parsed[key] = true;
            continue;
        }

        parsed[key] = next;
        i++;
    }

    return parsed;
}

function loadDeployment() {
    const file = path.join(__dirname, "..", "deployments", "complete-deployment.json");
    if (!fs.existsSync(file)) {
        return null;
    }

    return JSON.parse(fs.readFileSync(file, "utf8"));
}

function resolvePathValue(root, dottedPath) {
    if (!root || !dottedPath) return undefined;

    const parts = dottedPath.split(".");
    let current = root;
    for (const part of parts) {
        if (!current || typeof current !== "object" || !(part in current)) {
            return undefined;
        }
        current = current[part];
    }

    return current;
}

function resolveDeploymentEntry(deployment, key) {
    if (!deployment || !key) return undefined;

    const direct = resolvePathValue(deployment, key);
    if (direct !== undefined) return direct;

    if (deployment.contracts) {
        const nested = resolvePathValue(deployment.contracts, key);
        if (nested !== undefined) return nested;
    }

    return undefined;
}

function extractAddress(entry) {
    if (!entry) return undefined;
    if (typeof entry === "string") return entry;
    if (typeof entry === "object" && typeof entry.address === "string") return entry.address;
    return undefined;
}

function parseJsonArray(value, flagName) {
    if (!value) return [];

    let parsed;
    try {
        parsed = JSON.parse(value);
    } catch (error) {
        throw new Error(`Invalid JSON for --${flagName}: ${error.message}`);
    }

    if (!Array.isArray(parsed)) {
        throw new Error(`--${flagName} must be a JSON array`);
    }

    return parsed;
}

function saveUpgradeHistory(record) {
    const dir = path.join(__dirname, "..", "deployments");
    const file = path.join(dir, "upgrade-history.json");

    fs.mkdirSync(dir, { recursive: true });

    let history = [];
    if (fs.existsSync(file)) {
        const raw = JSON.parse(fs.readFileSync(file, "utf8"));
        history = Array.isArray(raw) ? raw : raw.history || [];
    }

    history.push(record);
    fs.writeFileSync(file, JSON.stringify({ history }, null, 2));
}

async function main() {
    const args = parseArgs(process.argv.slice(2));
    const contractName = args.contract;
    const deploymentKey = args.key;
    const deployment = loadDeployment();

    if (!contractName) {
        throw new Error("Missing required --contract <ContractName>");
    }

    let proxyAddress = args.proxy;
    if (!proxyAddress && deploymentKey) {
        proxyAddress = extractAddress(resolveDeploymentEntry(deployment, deploymentKey));
    }

    if (!proxyAddress) {
        throw new Error("Provide --proxy <address> or --key <group.path>");
    }

    proxyAddress = ethers.getAddress(proxyAddress);

    const allowLinkedLibraries = Boolean(args["unsafe-linked-libraries"]);
    const skipValidation = Boolean(args["skip-validation"]);
    const postUpgradeCall = args.call;
    const postUpgradeArgs = parseJsonArray(args["call-args"], "call-args");

    console.log("\n╔══════════════════════════════════════════════════════════════════════╗");
    console.log("║  UUPS PROXY UPGRADE                                                 ║");
    console.log("╚══════════════════════════════════════════════════════════════════════╝");
    console.log(`Network     : ${network.name}`);
    console.log(`Contract    : ${contractName}`);
    console.log(`Proxy       : ${proxyAddress}`);
    if (deploymentKey) console.log(`Deployment  : ${deploymentKey}`);

    const code = await ethers.provider.getCode(proxyAddress);
    if (code === "0x") {
        throw new Error(`No contract found at proxy address ${proxyAddress}`);
    }

    const factory = await ethers.getContractFactory(contractName);
    const upgradeOptions = { kind: "uups" };
    if (allowLinkedLibraries) {
        upgradeOptions.unsafeAllowLinkedLibraries = true;
    }

    const previousImplementation = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log(`Current impl: ${previousImplementation}`);

    if (!skipValidation) {
        console.log("\n🔍 Validating upgrade compatibility...");
        await upgrades.validateUpgrade(proxyAddress, factory, upgradeOptions);
        console.log("   ✅ Validation passed");
    }

    console.log("\n🔄 Executing upgrade...");
    const upgraded = await upgrades.upgradeProxy(proxyAddress, factory, upgradeOptions);
    await upgraded.waitForDeployment();

    const newImplementation = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log(`   ✅ Proxy preserved: ${await upgraded.getAddress()}`);
    console.log(`   ✅ New impl       : ${newImplementation}`);

    let postUpgradeTxHash = null;
    if (postUpgradeCall) {
        if (typeof upgraded[postUpgradeCall] !== "function") {
            throw new Error(`Function ${postUpgradeCall} does not exist on ${contractName}`);
        }

        console.log(`\n🧩 Running post-upgrade call: ${postUpgradeCall}(${postUpgradeArgs.length} args)`);
        const tx = await upgraded[postUpgradeCall](...postUpgradeArgs);
        await tx.wait();
        postUpgradeTxHash = tx.hash;
        console.log(`   ✅ Call confirmed: ${tx.hash}`);
    }

    saveUpgradeHistory({
        timestamp: new Date().toISOString(),
        network: network.name,
        contractName,
        deploymentKey: deploymentKey || null,
        proxyAddress,
        previousImplementation,
        newImplementation,
        allowLinkedLibraries,
        postUpgradeCall: postUpgradeCall || null,
        postUpgradeTxHash,
    });

    console.log("\n📝 Upgrade recorded in deployments/upgrade-history.json");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});