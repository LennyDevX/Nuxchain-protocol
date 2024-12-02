// ha// hardhat.config.cjs
require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-gas-reporter');

const POLYGON_MUMBAI = process.env.POLYGON_MUMBAI;
const POLYGON_MAINNET = process.env.POLYGON_MAINNET;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;

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
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${POLYGON_MUMBAI}`,
      accounts: [PRIVATE_KEY],
      chainId: 80001
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${POLYGON_MAINNET}`,
      accounts: [PRIVATE_KEY],
      chainId: 137
    }
  },
  etherscan: {
    apiKey: POLYGONSCAN_API_KEY
  },
  paths: {
    sources: "./contracts",
    tests: "./test", 
    cache: "./cache",
    artifacts: "./artifacts"
  },
  upgrades: {
    // Opcional: configura las opciones de actualización si lo necesitas
    // viaProxy: true,
    // contractName: "MyContract",
    // initArgs: ["arg1", "arg2"]
  }
};