require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.30",
        settings: {
          optimizer: {
            enabled: true,
            runs: 800 // Aumentar para reducir impacto de calldata
          },
          evmVersion: "prague"
        }
      },
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 800
          },
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
      chainId: 137
    }
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY
  }
};

