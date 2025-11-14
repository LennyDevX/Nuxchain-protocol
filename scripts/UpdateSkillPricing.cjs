/**
 * @title Update Individual Skills Pricing
 * @dev Script to update skill prices on already deployed IndividualSkillsMarketplace
 * @usage npx hardhat run scripts/UpdateSkillPricing.cjs --network polygon
 */

const hre = require("hardhat");
const ethers = hre.ethers;

// Deployed contract address on Polygon Mainnet
const MARKETPLACE_ADDRESS = "0x33Bf614459a5Eeef31803153f20342C707582364";

// Skill Type Enum
const SkillType = {
  NONE: 0,
  STAKE_BOOST_I: 1,
  STAKE_BOOST_II: 2,
  STAKE_BOOST_III: 3,
  AUTO_COMPOUND: 4,
  LOCK_REDUCER: 5,
  FEE_REDUCER_I: 6,
  FEE_REDUCER_II: 7,
  PRIORITY_LISTING: 8,
  BATCH_MINTER: 9,
  VERIFIED_CREATOR: 10,
  INFLUENCER: 11,
  CURATOR: 12,
  AMBASSADOR: 13,
  VIP_ACCESS: 14,
  EARLY_ACCESS: 15,
  PRIVATE_AUCTIONS: 16,
};

// Rarity Enum
const Rarity = {
  COMMON: 0,
  UNCOMMON: 1,
  RARE: 2,
  EPIC: 3,
  LEGENDARY: 4,
};

const RarityNames = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"];

// Current Prices (in POL)
const CURRENT_PRICES = {
  staking: {
    [Rarity.COMMON]: 50,
    [Rarity.UNCOMMON]: 80,
    [Rarity.RARE]: 100,
    [Rarity.EPIC]: 150,
    [Rarity.LEGENDARY]: 220,
  },
  active: {
    [Rarity.COMMON]: 65,
    [Rarity.UNCOMMON]: 104,
    [Rarity.RARE]: 130,
    [Rarity.EPIC]: 195,
    [Rarity.LEGENDARY]: 286,
  },
};

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("\n========== SKILL PRICING UPDATE SCRIPT ==========");
  console.log("Signer:", signer.address);
  console.log("Network:", hre.network.name);
  console.log("Marketplace:", MARKETPLACE_ADDRESS);

  // Get contract
  const marketplace = await ethers.getContractAt(
    "IndividualSkillsMarketplace",
    MARKETPLACE_ADDRESS,
    signer
  );

  // Verify admin role
  const adminRole = await marketplace.ADMIN_ROLE();
  const hasAdminRole = await marketplace.hasRole(adminRole, signer.address);

  if (!hasAdminRole) {
    console.error("\n❌ Error: Signer does not have ADMIN_ROLE");
    console.error("Current signer:", signer.address);
    throw new Error("Admin role required");
  }

  console.log("✓ Admin role verified\n");

  // Menu
  console.log("Select an option:");
  console.log("1. Update single skill price");
  console.log("2. Update all staking skills");
  console.log("3. Update all active skills");
  console.log("4. Reset to defaults");
  console.log("5. Query current prices");
  console.log("6. Exit\n");

  const option = process.argv[2] || "5";

  switch (option) {
    case "1":
      await updateSinglePrice();
      break;
    case "2":
      await updateStakingSkills();
      break;
    case "3":
      await updateActiveSkills();
      break;
    case "4":
      await resetToDefaults();
      break;
    case "5":
      await queryPrices();
      break;
    default:
      console.log("Exiting...");
  }

  async function updateSinglePrice() {
    console.log("\n---- UPDATE SINGLE SKILL PRICE ----");

    // Example: Update STAKE_BOOST_I LEGENDARY to 250 POL
    const skillType = SkillType.STAKE_BOOST_I;
    const rarity = Rarity.LEGENDARY;
    const newPrice = ethers.parseEther("250");

    console.log(`Updating: Skill #${skillType}, Rarity ${RarityNames[rarity]}`);
    console.log(`New price: 250 POL`);

    const tx = await marketplace.updateSkillPrice(skillType, rarity, newPrice);
    console.log("Transaction hash:", tx.hash);

    const receipt = await tx.wait();
    console.log("✓ Transaction confirmed in block", receipt.blockNumber);

    // Query updated price
    const updatedPrice = await marketplace.getSkillPrice(skillType, rarity);
    console.log(
      `✓ New price: ${ethers.formatEther(updatedPrice)} POL\n`
    );
  }

  async function updateStakingSkills() {
    console.log("\n---- UPDATE ALL STAKING SKILLS ----");

    // New prices (example: increase by 20%)
    const newCommon = ethers.parseEther("60"); // 50 * 1.2
    const newUncommon = ethers.parseEther("96"); // 80 * 1.2
    const newRare = ethers.parseEther("120"); // 100 * 1.2
    const newEpic = ethers.parseEther("180"); // 150 * 1.2
    const newLegendary = ethers.parseEther("264"); // 220 * 1.2

    console.log("New staking skill prices:");
    console.log(`  COMMON:    50 → 60 POL`);
    console.log(`  UNCOMMON:  80 → 96 POL`);
    console.log(`  RARE:      100 → 120 POL`);
    console.log(`  EPIC:      150 → 180 POL`);
    console.log(`  LEGENDARY: 220 → 264 POL`);

    const tx = await marketplace.updateStakingSkillsPricing(
      newCommon,
      newUncommon,
      newRare,
      newEpic,
      newLegendary
    );

    console.log("Transaction hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("✓ Transaction confirmed in block", receipt.blockNumber);
    console.log("✓ All 7 staking skills updated\n");

    // Verify
    await querySkillPrices(1, true);
  }

  async function updateActiveSkills() {
    console.log("\n---- UPDATE ALL ACTIVE SKILLS ----");

    // 30% markup on updated staking prices
    const newCommon = ethers.parseEther("78"); // 60 * 1.3
    const newUncommon = ethers.parseEther("125"); // 96 * 1.3
    const newRare = ethers.parseEther("156"); // 120 * 1.3
    const newEpic = ethers.parseEther("234"); // 180 * 1.3
    const newLegendary = ethers.parseEther("343"); // 264 * 1.3

    console.log("New active skill prices (30% markup):");
    console.log(`  COMMON:    65 → 78 POL`);
    console.log(`  UNCOMMON:  104 → 125 POL`);
    console.log(`  RARE:      130 → 156 POL`);
    console.log(`  EPIC:      195 → 234 POL`);
    console.log(`  LEGENDARY: 286 → 343 POL`);

    const tx = await marketplace.updateActiveSkillsPricing(
      newCommon,
      newUncommon,
      newRare,
      newEpic,
      newLegendary
    );

    console.log("Transaction hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("✓ Transaction confirmed in block", receipt.blockNumber);
    console.log("✓ All 10 active skills updated\n");

    // Verify
    await querySkillPrices(8, true);
  }

  async function resetToDefaults() {
    console.log("\n---- RESET TO DEFAULT PRICES ----");
    console.log("Resetting all skills to default prices...");

    const tx = await marketplace.resetSkillPricingToDefaults();
    console.log("Transaction hash:", tx.hash);

    const receipt = await tx.wait();
    console.log("✓ Transaction confirmed in block", receipt.blockNumber);
    console.log("✓ All prices reset to defaults\n");

    // Show defaults
    console.log("Default prices restored:");
    console.log("\nStaking Skills (1-7):");
    Object.entries(CURRENT_PRICES.staking).forEach(([rarity, price]) => {
      console.log(`  ${RarityNames[rarity]}: ${price} POL`);
    });
    console.log("\nActive Skills (8-17):");
    Object.entries(CURRENT_PRICES.active).forEach(([rarity, price]) => {
      console.log(`  ${RarityNames[rarity]}: ${price} POL`);
    });
    console.log();
  }

  async function queryPrices() {
    console.log("\n---- CURRENT SKILL PRICES ----\n");

    // Get all prices
    const [skillTypes, categories, prices] = await marketplace.getAllSkillsPricing();

    // Organize by category
    const stakingSkills = [];
    const activeSkills = [];

    skillTypes.forEach((skillType, index) => {
      const category = categories[index];
      const skillPrice = prices[index];

      if (category === 0) {
        stakingSkills.push({
          type: skillType,
          prices: skillPrice,
        });
      } else {
        activeSkills.push({
          type: skillType,
          prices: skillPrice,
        });
      }
    });

    // Display staking skills
    console.log("STAKING SKILLS (1-7) - Cheaper:");
    console.log("═".repeat(60));
    stakingSkills.forEach((skill) => {
      console.log(`\nSkill #${skill.type}:`);
      RarityNames.forEach((rarity, index) => {
        const price = ethers.formatEther(skill.prices[index]);
        console.log(`  ${rarity.padEnd(12)}: ${price} POL`);
      });
    });

    // Display active skills
    console.log("\n\nACTIVE SKILLS (8-17) - 30% Premium:");
    console.log("═".repeat(60));
    activeSkills.forEach((skill) => {
      console.log(`\nSkill #${skill.type}:`);
      RarityNames.forEach((rarity, index) => {
        const price = ethers.formatEther(skill.prices[index]);
        console.log(`  ${rarity.padEnd(12)}: ${price} POL`);
      });
    });

    console.log("\n");
  }

  async function querySkillPrices(skillType, detailed = false) {
    const prices = await marketplace.getSkillPricesAllRarities(skillType);

    console.log(`Skill #${skillType} current prices:`);
    RarityNames.forEach((rarity, index) => {
      const price = ethers.formatEther(prices[index]);
      console.log(`  ${rarity.padEnd(12)}: ${price} POL`);
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Error:", error.message);
    process.exit(1);
  });
