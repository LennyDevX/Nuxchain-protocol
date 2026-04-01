const { ethers } = require("hardhat");

/**
 * Deploy TreasuryManager contract fixture
 * @returns {Promise<{treasury, owner, rewardsAddr, stakingAddr, collaboratorsAddr, developmentAddr, marketplaceAddr, otherAddrs}>}
 */
async function deployTreasuryManager() {
    const [owner, rewardsAddress, stakingAddress, collaboratorsAddress, developmentAddress, marketplaceAddress, ...otherAddrs] = await ethers.getSigners();
    
    const TreasuryManager = await ethers.getContractFactory("TreasuryManager");
    const treasury = await TreasuryManager.deploy();
    await treasury.deployed();
    
    // Set treasury addresses using individual setter calls
    await treasury.setTreasury(0, rewardsAddress.address);        // TreasuryType.REWARDS
    await treasury.setTreasury(1, stakingAddress.address);        // TreasuryType.STAKING
    await treasury.setTreasury(2, collaboratorsAddress.address);  // TreasuryType.COLLABORATORS
    await treasury.setTreasury(3, developmentAddress.address);    // TreasuryType.DEVELOPMENT
    await treasury.setTreasury(4, marketplaceAddress.address);    // TreasuryType.MARKETPLACE
    
    return {
        treasury,
        owner,
        rewardsAddr: rewardsAddress,
        stakingAddr: stakingAddress,
        collaboratorsAddr: collaboratorsAddress,
        developmentAddr: developmentAddress,
        marketplaceAddr: marketplaceAddress,
        otherAddrs
    };
}

/**
 * Deploy TreasuryManager and fund it with initial balance
 * @param {string} initialFunding - Amount in ETH to fund (default: "100")
 * @returns {Promise<{treasury, owner, rewardsAddr, stakingAddr, collaboratorsAddr, developmentAddr, marketplaceAddr, otherAddrs}>}
 */
async function setupTreasuryWithFunding(initialFunding = "100") {
    const contracts = await deployTreasuryManager();
    
    // Fund the treasury
    const fundAmount = ethers.utils.parseEther(initialFunding);
    await contracts.owner.sendTransaction({
        to: contracts.treasury.address,
        value: fundAmount
    });
    
    return contracts;
}

/**
 * Deploy mock contracts for integration testing
 * @returns {Promise<{mockStaking, mockMarketplace, mockCollaborator}>}
 */
async function deployMockProtocols() {
    const [owner] = await ethers.getSigners();
    
    const MockStaking = await ethers.getContractFactory("MockStaking");
    const mockStaking = await MockStaking.deploy();
    await mockStaking.deployed();
    
    const MockCore = await ethers.getContractFactory("MockCore");
    const mockMarketplace = await MockCore.deploy();
    await mockMarketplace.deployed();
    
    const mockCollaborator = await MockCore.deploy();
    await mockCollaborator.deployed();
    
    return {
        mockStaking,
        mockMarketplace,
        mockCollaborator,
        owner
    };
}

module.exports = {
    deployTreasuryManager,
    setupTreasuryWithFunding,
    deployMockProtocols
};
