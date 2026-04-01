#!/usr/bin/env node
"use strict";

const path = require("path");
const { ethers, upgrades, network } = require("hardhat");
require("dotenv").config({ override: true });

const AddressManager = require("./utils/AddressManager.cjs");

const DEFAULT_ITEMS = [
    {
        itemId: 1,
        kind: 1,
        price: "0.01",
        value: 1,
        duration: 0,
        stock: 0,
        active: true,
        soulbound: true,
        nftContract: ethers.ZeroAddress
    },
    {
        itemId: 2,
        kind: 2,
        price: "0.02",
        value: 2500,
        duration: 3600,
        stock: 0,
        active: true,
        soulbound: true,
        nftContract: ethers.ZeroAddress
    },
    {
        itemId: 3,
        kind: 3,
        price: "0.005",
        value: 1,
        duration: 0,
        stock: 0,
        active: true,
        soulbound: true,
        nftContract: ethers.ZeroAddress
    }
];

const DEFAULT_LEVELS = [
    { scoreRequired: 0, dailyTapCap: 5000, rewardMultiplierBps: 10000 },
    { scoreRequired: 1000, dailyTapCap: 7500, rewardMultiplierBps: 10500 },
    { scoreRequired: 5000, dailyTapCap: 10000, rewardMultiplierBps: 11500 },
    { scoreRequired: 15000, dailyTapCap: 15000, rewardMultiplierBps: 12500 }
];

async function deployProxy(contractName, args) {
    const factory = await ethers.getContractFactory(contractName);
    const instance = await upgrades.deployProxy(factory, args, {
        initializer: "initialize",
        kind: "uups"
    });

    await instance.waitForDeployment();
    return instance;
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const deployerAddress = deployer.address;
    const dashboardAdmin = process.env.NUXTAP_ADMIN || deployerAddress;
    const registryAddress = process.env.NUXTAP_AGENT_REGISTRY || ethers.ZeroAddress;
    const baseUri = process.env.NUXTAP_STORE_BASE_URI || "ipfs://nuxtap-items/{id}.json";
    const initialFunding = process.env.NUXTAP_INITIAL_REWARD_FUND || "0";
    const supportedNfts = (process.env.NUXTAP_SUPPORTED_NFTS || "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean);

    console.log("\n╔══════════════════════════════════════════════════════════════╗");
    console.log("║  NUXTAP DEPLOYMENT                                          ║");
    console.log("╚══════════════════════════════════════════════════════════════╝");
    console.log(`Network        : ${network.name}`);
    console.log(`Deployer       : ${deployerAddress}`);
    console.log(`Dashboard admin: ${dashboardAdmin}`);
    console.log(`Registry       : ${registryAddress}`);

    const treasury = await deployProxy("NuxTapTreasury", [deployerAddress]);
    const treasuryAddress = await treasury.getAddress();
    console.log(`NuxTapTreasury : ${treasuryAddress}`);

    const store = await deployProxy("NuxTapItemStore", [deployerAddress, treasuryAddress, baseUri]);
    const storeAddress = await store.getAddress();
    console.log(`NuxTapItemStore: ${storeAddress}`);

    const game = await deployProxy("NuxTapGame", [deployerAddress, treasuryAddress, storeAddress, registryAddress]);
    const gameAddress = await game.getAddress();
    console.log(`NuxTapGame     : ${gameAddress}`);

    const agentMarketplace = await deployProxy("NuxTapAgentMarketplace", [
        deployerAddress,
        treasuryAddress,
        registryAddress
    ]);
    const agentMarketplaceAddress = await agentMarketplace.getAddress();
    console.log(`NuxTapAgentMarket: ${agentMarketplaceAddress}`);

    await (await treasury.grantStoreRole(storeAddress)).wait();
    await (await treasury.grantGameRole(gameAddress)).wait();
    await (await store.grantGameRole(gameAddress)).wait();

    await (await game.replaceLevelConfigs(DEFAULT_LEVELS)).wait();

    for (const item of DEFAULT_ITEMS) {
        await (
            await store.configureItem(
                item.itemId,
                item.kind,
                ethers.parseEther(item.price),
                item.value,
                item.duration,
                item.stock,
                item.active,
                item.soulbound,
                item.nftContract
            )
        ).wait();
    }

    for (const nftAddress of supportedNfts) {
        await (await game.setSupportedNFTContract(nftAddress, true)).wait();
        await (await agentMarketplace.setSupportedNFTContract(nftAddress, true)).wait();
    }

    if (initialFunding !== "0") {
        await (
            await treasury.fundRewards("initial_reward_seed", {
                value: ethers.parseEther(initialFunding)
            })
        ).wait();
    }

    if (dashboardAdmin.toLowerCase() !== deployerAddress.toLowerCase()) {
        const roleTargets = [
            [treasury, [await treasury.DEFAULT_ADMIN_ROLE(), await treasury.ADMIN_ROLE(), await treasury.UPGRADER_ROLE(), await treasury.PAUSER_ROLE(), await treasury.TREASURER_ROLE()]],
            [store, [await store.DEFAULT_ADMIN_ROLE(), await store.ADMIN_ROLE(), await store.UPGRADER_ROLE(), await store.PAUSER_ROLE()]],
            [game, [await game.DEFAULT_ADMIN_ROLE(), await game.ADMIN_ROLE(), await game.UPGRADER_ROLE(), await game.PAUSER_ROLE(), await game.OPERATOR_ROLE()]],
            [agentMarketplace, [await agentMarketplace.DEFAULT_ADMIN_ROLE(), await agentMarketplace.ADMIN_ROLE(), await agentMarketplace.UPGRADER_ROLE(), await agentMarketplace.PAUSER_ROLE()]]
        ];

        for (const [contract, roles] of roleTargets) {
            for (const role of roles) {
                await (await contract.grantRole(role, dashboardAdmin)).wait();
            }
        }
    }

    const addressManager = new AddressManager(path.join(__dirname, ".."), network.name);
    addressManager.updateAddresses(
        {
            nuxtap: {
                agentMarketplace: agentMarketplaceAddress,
                treasury: treasuryAddress,
                store: storeAddress,
                game: gameAddress
            }
        },
        { updateEnv: true, updateDeployment: true }
    );

    console.log("\nNuxTap deployment completed.");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});