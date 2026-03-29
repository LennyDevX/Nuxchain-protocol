const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * ⚡ DEPLOYMENT STRATEGY
 * 
 * Ejecuta deployments y upgrades de contratos según la estrategia definida
 */

class DeploymentStrategy {
    constructor(network, signer) {
        this.network = network;
        this.signer = signer;
        this.deploymentResults = {
            successful: [],
            upgraded: [],
            failed: [],
            gasUsed: 0
        };
    }

    /**
     * Ejecutar upgrade de un contrato UUPS
     * @param {string} contractName
     * @param {string} proxyAddress
     * @param {Object} options
     * @returns {Promise<Object>} {success, address, txHash, error}
     */
    async executeUpgrade(contractName, proxyAddress, options = {}) {
        console.log(`\n🔄 Upgrading ${contractName} at ${proxyAddress}...`);

        try {
            // Validar que el proxy existe
            const code = await ethers.provider.getCode(proxyAddress);
            if (code === '0x') {
                throw new Error(`No contract found at proxy address ${proxyAddress}`);
            }

            // Obtener factory del nuevo contrato
            const ContractFactory = await ethers.getContractFactory(contractName, this.signer);

            // Ejecutar upgrade
            console.log(`   Deploying new implementation...`);
            const upgraded = await upgrades.upgradeProxy(proxyAddress, ContractFactory, {
                kind: 'uups',
                ...options
            });

            await upgraded.waitForDeployment();
            const address = await upgraded.getAddress();

            // Obtener dirección de la nueva implementación
            const implementationAddress = await upgrades.erc1967.getImplementationAddress(address);

            const result = {
                success: true,
                contractName,
                proxyAddress: address,
                implementationAddress,
                action: 'UPGRADE',
                timestamp: new Date().toISOString()
            };

            this.deploymentResults.upgraded.push(result);

            console.log(`   ✅ Upgraded successfully`);
            console.log(`   📍 Proxy: ${address}`);
            console.log(`   📍 Implementation: ${implementationAddress}`);

            return result;

        } catch (error) {
            console.error(`   ❌ Upgrade failed: ${error.message}`);
            
            const result = {
                success: false,
                contractName,
                proxyAddress,
                action: 'UPGRADE',
                error: error.message,
                timestamp: new Date().toISOString()
            };

            this.deploymentResults.failed.push(result);
            return result;
        }
    }

    /**
     * Ejecutar deployment de un nuevo contrato
     * @param {string} contractName
     * @param {Array} constructorArgs
     * @param {Object} options - {isProxy, kind}
     * @returns {Promise<Object>}
     */
    async executeDeploy(contractName, constructorArgs = [], options = {}) {
        console.log(`\n🚀 Deploying ${contractName}...`);

        try {
            const ContractFactory = await ethers.getContractFactory(contractName, this.signer);

            let contract;
            let implementationAddress;

            if (options.isProxy) {
                // Deploy como proxy
                console.log(`   Deploying as ${options.kind || 'uups'} proxy...`);
                contract = await upgrades.deployProxy(ContractFactory, constructorArgs, {
                    kind: options.kind || 'uups',
                    initializer: options.initializer || 'initialize'
                });

                await contract.waitForDeployment();
                const proxyAddress = await contract.getAddress();
                implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);

                console.log(`   ✅ Deployed successfully`);
                console.log(`   📍 Proxy: ${proxyAddress}`);
                console.log(`   📍 Implementation: ${implementationAddress}`);

                const result = {
                    success: true,
                    contractName,
                    address: proxyAddress,
                    implementationAddress,
                    action: 'DEPLOY_PROXY',
                    isProxy: true,
                    timestamp: new Date().toISOString()
                };

                this.deploymentResults.successful.push(result);
                return result;

            } else {
                // Deploy normal
                console.log(`   Deploying as regular contract...`);
                contract = await ContractFactory.deploy(...constructorArgs);
                await contract.waitForDeployment();
                
                const address = await contract.getAddress();

                console.log(`   ✅ Deployed successfully`);
                console.log(`   📍 Address: ${address}`);

                const result = {
                    success: true,
                    contractName,
                    address,
                    action: 'DEPLOY',
                    isProxy: false,
                    timestamp: new Date().toISOString()
                };

                this.deploymentResults.successful.push(result);
                return result;
            }

        } catch (error) {
            console.error(`   ❌ Deployment failed: ${error.message}`);
            
            const result = {
                success: false,
                contractName,
                action: options.isProxy ? 'DEPLOY_PROXY' : 'DEPLOY',
                error: error.message,
                timestamp: new Date().toISOString()
            };

            this.deploymentResults.failed.push(result);
            return result;
        }
    }

    /**
     * Actualizar referencias entre contratos
     * @param {Object} coreContract - Contrato principal
     * @param {Array} moduleAddresses - [{moduleName, address}]
     * @returns {Promise<boolean>}
     */
    async updateModuleReferences(coreContract, moduleAddresses) {
        console.log(`\n🔗 Updating module references in core contract...`);

        try {
            for (const module of moduleAddresses) {
                const functionName = `set${module.moduleName}`;
                
                if (typeof coreContract[functionName] === 'function') {
                    console.log(`   Setting ${module.moduleName} → ${module.address}`);
                    const tx = await coreContract[functionName](module.address);
                    await tx.wait();
                    console.log(`   ✅ ${module.moduleName} updated`);
                } else {
                    console.warn(`   ⚠️  Function ${functionName} not found, skipping`);
                }
            }

            return true;

        } catch (error) {
            console.error(`   ❌ Error updating references: ${error.message}`);
            return false;
        }
    }

    /**
     * Verificar que el deployment fue exitoso
     * @param {string} address
     * @param {string} expectedCodeHash - Optional
     * @returns {Promise<Object>} {valid, bytecodeSize, isProxy}
     */
    async verifyDeployment(address, expectedCodeHash = null) {
        try {
            const code = await ethers.provider.getCode(address);
            
            if (code === '0x') {
                return {
                    valid: false,
                    bytecodeSize: 0,
                    isProxy: false,
                    error: 'No bytecode at address'
                };
            }

            const bytecodeSize = code.length;
            
            // Detectar si es proxy
            const isProxy = code.includes('360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc');

            let implementationValid = true;
            if (isProxy) {
                try {
                    const implAddress = await upgrades.erc1967.getImplementationAddress(address);
                    const implCode = await ethers.provider.getCode(implAddress);
                    implementationValid = implCode !== '0x';
                } catch (e) {
                    implementationValid = false;
                }
            }

            return {
                valid: true && implementationValid,
                bytecodeSize,
                isProxy,
                implementationValid
            };

        } catch (error) {
            return {
                valid: false,
                error: error.message
            };
        }
    }

    /**
     * Ejecutar strategy completa de deployment
     * @param {Array} contracts - Contratos a deployar
     * @param {Object} strategy - Estrategia de deployment
     * @param {Object} existingAddresses - Direcciones existentes
     * @returns {Promise<Object>} Resultados completos
     */
    async executeStrategy(contracts, strategy, existingAddresses = {}) {
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║  ⚡ EXECUTING DEPLOYMENT STRATEGY                            ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");

        const results = {
            successful: [],
            upgraded: [],
            failed: [],
            totalGas: 0
        };

        for (const contract of contracts) {
            // Determinar acción para este contrato
            let action = 'DEPLOY';
            
            if (strategy.action === 'mixed') {
                const strategyContract = strategy.contracts.find(c => c.name === contract.name);
                action = strategyContract?.action || 'DEPLOY';
            } else {
                action = strategy.action;
            }

            // Buscar dirección existente
            const existingAddress = this.findExistingAddress(contract, existingAddresses);

            try {
                let result;

                if (action === 'UPGRADE' && existingAddress) {
                    // Ejecutar upgrade
                    result = await this.executeUpgrade(contract.name, existingAddress);
                    
                    if (result.success) {
                        results.upgraded.push(result);
                    } else {
                        results.failed.push(result);
                    }

                } else {
                    // Ejecutar nuevo deployment
                    const deployConfig = this.getDeployConfig(contract.name, existingAddresses);
                    result = await this.executeDeploy(
                        contract.name,
                        deployConfig.args,
                        deployConfig.options
                    );

                    if (result.success) {
                        results.successful.push(result);
                    } else {
                        results.failed.push(result);
                    }
                }

                // Verificar deployment
                if (result.success) {
                    const verification = await this.verifyDeployment(
                        result.address || result.proxyAddress
                    );
                    
                    if (!verification.valid) {
                        console.warn(`   ⚠️  Verification failed for ${contract.name}`);
                    }
                }

            } catch (error) {
                console.error(`❌ Error processing ${contract.name}: ${error.message}`);
                results.failed.push({
                    contractName: contract.name,
                    error: error.message,
                    action
                });
            }
        }

        this.deploymentResults = results;
        return results;
    }

    /**
     * Buscar dirección existente de un contrato
     * @param {Object} contract
     * @param {Object} existingAddresses
     * @returns {string|null}
     */
    findExistingAddress(contract, existingAddresses) {
        const category = contract.category || 'other';
        
        if (!existingAddresses[category]) {
            return null;
        }

        // Mapeo de nombres de contratos a keys
        const keyMap = {
            'SmartStakingCoreV2': 'core',
            'SmartStakingRewards': 'rewards',
            'SmartStakingSkills': 'skills',
            'SmartStakingGamification': 'gamification',
            'SmartStakingView': 'view',
            'GameifiedMarketplaceCoreV1': 'proxy',
            'GameifiedMarketplaceProxy': 'proxy',
            'GameifiedNuxPowerNft': 'skillsNFT',
            'NuxPowerMarketplace': 'nuxPowers',
            'GameifiedMarketplaceQuests': 'quests',
            'LevelingSystem': 'leveling',
            'ReferralSystem': 'referral',
            'TreasuryManager': 'manager',
            'CollaboratorBadgeRewards': 'collaboratorBadges',
            'DynamicAPYCalculator': 'dynamicAPY'
        };

        const key = keyMap[contract.name];
        return key ? existingAddresses[category][key] : null;
    }

    /**
     * Obtener configuración de deployment para un contrato
     * @param {string} contractName
     * @returns {Object} {args, options}
     */
    getDeployConfig(contractName, existingAddresses = {}) {
        // Obtener direcciones útiles para inicializaciones
        const adminAddress = this.signer.address;
        const treasuryAddress = existingAddresses?.treasury?.manager || ethers.ZeroAddress;
        const marketplaceCore = existingAddresses?.marketplace?.implementation || 
                               existingAddresses?.marketplace?.proxy ||
                               ethers.ZeroAddress;
        const stakingCore = existingAddresses?.staking?.core || ethers.ZeroAddress;
        
        const configs = {
            // STAKING CONTRACTS
            'EnhancedSmartStakingCore': {
                args: [],
                options: { isProxy: true, kind: 'uups', initializer: 'initialize' }
            },
            'SmartStakingRewards': {
                args: [],
                options: { isProxy: false }
            },
            'SmartStakingSkills': {
                args: [],
                options: { isProxy: false }
            },
            'SmartStakingGamification': {
                args: [],
                options: { isProxy: false }
            },
            'SmartStakingView': {
                args: [stakingCore],
                options: { isProxy: false }
            },
            'DynamicAPYCalculator': {
                args: [],
                options: { isProxy: false }
            },
            
            // MARKETPLACE - CORE
            'GameifiedMarketplaceCoreV1': {
                args: [treasuryAddress],
                options: { isProxy: true, kind: 'uups', initializer: 'initialize' }
            },
            'GameifiedMarketplaceProxy': {
                args: [],
                options: { isProxy: false }
            },
            
            // MARKETPLACE - SKILLS & NFTs
            'GameifiedNuxPowerNft': {
                args: [marketplaceCore],
                options: { isProxy: false }
            },
            'NuxPowerMarketplace': {
                args: [treasuryAddress],
                options: { isProxy: false }
            },
            'NuxPowerMarketplaceImpl': {
                args: [treasuryAddress],
                options: { isProxy: false }
            },
            
            // MARKETPLACE - FEATURES
            'GameifiedMarketplaceQuests': {
                args: [marketplaceCore],
                options: { isProxy: false }
            },
            'LevelingSystem': {
                args: [],
                options: { isProxy: false }
            },
            'ReferralSystem': {
                args: [],
                options: { isProxy: false }
            },
            
            // MARKETPLACE - VIEW & ANALYTICS
            'MarketplaceView': {
                args: [adminAddress, marketplaceCore],
                options: { isProxy: false }
            },
            'MarketplaceSocial': {
                args: [adminAddress, marketplaceCore],
                options: { isProxy: false }
            },
            'MarketplaceStatistics': {
                args: [adminAddress, marketplaceCore],
                options: { isProxy: false }
            },
            
            // TREASURY & BADGES
            'TreasuryManager': {
                args: [],
                options: { isProxy: false }
            },
            'CollaboratorBadgeRewards': {
                args: [],
                options: { isProxy: true, kind: 'uups', initializer: 'initialize' }
            }
        };

        return configs[contractName] || { args: [], options: { isProxy: false } };
    }

    /**
     * Obtener resultados del deployment
     * @returns {Object}
     */
    getResults() {
        return this.deploymentResults;
    }

    /**
     * Resetear resultados
     */
    resetResults() {
        this.deploymentResults = {
            successful: [],
            upgraded: [],
            failed: [],
            gasUsed: 0
        };
    }
}

module.exports = DeploymentStrategy;
