require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      accounts: {
        accountsBalance: "10000000000000000000000" // 10000 ETH in wei
      }
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.VITE_ALCHEMY}`,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137
    }
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY
  }
};

