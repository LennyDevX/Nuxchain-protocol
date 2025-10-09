require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 800
          },
          viaIR: true,
          evmVersion: "cancun"
        }
      },
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 800
          },
          viaIR: true,
          evmVersion: "cancun"
        }
      }
    ]
  },
  networks: {
    hardhat: {
      accounts: {
        accountsBalance: "30000000000000000000000" // 30000 ETH in wei
      }
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.VITE_ALCHEMY}`,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137,
      gasPrice: 35000000000, // 35 gwei
      gasMultiplier: 1.2
    }
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY
  }
};

