require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 300, // Optimizado para deployment gas efficiency
            details: {
              yul: true,
              yulDetails: {
                stackAllocation: true,
                optimizerSteps: "dhfoDgvulfnTUtnIf"
              }
            }
          },
          viaIR: true, // Necesario para contratos complejos (MinerBotNFT)
          evmVersion: "shanghai" // Polygon soporta hasta shanghai
        }
      },
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: true,
              yulDetails: {
                stackAllocation: true,
                optimizerSteps: "dhfoDgvulfnTUtnIf"
              }
            }
          },
          viaIR: true,
          evmVersion: "shanghai"
        }
      }
    ],
    overrides: {
      "contracts/Marketplace/GameifiedMarketplaceV1.sol": {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100,
            details: {
              yul: true
            }
          },
          viaIR: true,
          evmVersion: "shanghai"
        }
      },
      "contracts/Marketplace/GameifiedMarketplace.sol": {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 50, // Ultra-optimizado
            details: {
              yul: true
            }
          },
          viaIR: true, // Necesario para evitar stack too deep
          evmVersion: "shanghai"
        }
      }
    }
  },
  networks: {
    hardhat: {
      accounts: {
        accountsBalance: "30000000000000000000000" // 30000 ETH in wei
      },
      chainId: 31337,
      gas: "auto",
      gasPrice: "auto"
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 137,
      gas: "auto", // Estimación automática de gas
      gasPrice: "auto", // Precio dinámico de gas
      timeout: 120000, // 2 minutos (no tan largo para detectar problemas rápido)
      confirmations: 3, // 3 confirmaciones para mayor seguridad
      // Configuración EIP-1559 para Polygon
      maxPriorityFeePerGas: null, // Se calcula dinámicamente
      maxFeePerGas: null // Se calcula dinámicamente
    },
    // Red de prueba Polygon Mumbai (ya deprecated, usar Amoy)
    polygonAmoy: {
      url: `https://polygon-amoy.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 80002,
      gas: "auto",
      gasPrice: "auto",
      timeout: 120000,
      confirmations: 2
    }
  },
  etherscan: {
    // Usar un solo API key para todas las redes (Etherscan API v2)
    apiKey: process.env.POLYGONSCAN_API_KEY
  },
  sourcify: {
    enabled: false  // Deshabilitado para evitar warnings
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    token: "MATIC",
    gasPriceApi: "https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice"
  },
  mocha: {
    timeout: 200000 // 200 segundos para tests
  }
};

