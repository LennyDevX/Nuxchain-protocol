const { ethers } = require("hardhat");
const hre = require("hardhat");
const path = require("path");

// Importar utilidades
const ContractAnalyzer = require("./utils/ContractAnalyzer.cjs");
const AddressManager = require("./utils/AddressManager.cjs");
const InteractiveMenu = require("./utils/InteractiveMenu.cjs");
const DeploymentStrategy = require("./utils/DeploymentStrategy.cjs");

/**
 * 🚀 NUXCHAIN SMART DEPLOYMENT SYSTEM V2
 * 
 * Sistema inteligente de deployment que:
 * - Detecta contratos modificados automáticamente
 * - Permite selección interactiva de contratos
 * - Preserva direcciones mediante upgrades
 * - Crea backups antes de deployar
 * - Verifica contratos en Polygonscan
 */

class SmartDeployment {
    constructor() {
        this.projectRoot = path.join(__dirname, '..');
        this.network = null;
        this.signer = null;
        
        // Inicializar utilidades
        this.analyzer = new ContractAnalyzer(this.projectRoot);
        this.addressManager = null;
        this.menu = new InteractiveMenu();
        this.strategy = null;
    }

    /**
     * Inicializar sistema de deployment
     */
    async initialize() {
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║       🚀 NUXCHAIN SMART DEPLOYMENT SYSTEM V2 🚀              ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");

        // Obtener red y signer
        this.network = hre.network.name;
        [this.signer] = await ethers.getSigners();

        console.log(`📡 Network: ${this.network}`);
        console.log(`👤 Deployer: ${this.signer.address}`);
        
        // Obtener balance
        const balance = await ethers.provider.getBalance(this.signer.address);
        console.log(`💰 Balance: ${ethers.formatEther(balance)} MATIC\n`);

        // Inicializar managers
        this.addressManager = new AddressManager(this.projectRoot, this.network);
        this.strategy = new DeploymentStrategy(this.network, this.signer);
    }

    /**
     * Ejecutar deployment inteligente
     */
    async run() {
        try {
            // 1. Mostrar menú principal
            const mode = await this.menu.showMainMenu();

            if (mode === 'cancel') {
                console.log("❌ Deployment cancelled by user");
                return;
            }

            // 2. Obtener contratos según el modo
            let contractsToDeploy = [];
            let strategy = null;

            switch (mode) {
                case 'smart':
                    ({ contracts: contractsToDeploy, strategy } = await this.smartMode());
                    break;
                
                case 'upgrade':
                    ({ contracts: contractsToDeploy, strategy } = await this.upgradeMode());
                    break;
                
                case 'fresh':
                    ({ contracts: contractsToDeploy, strategy } = await this.freshMode());
                    break;
                
                case 'custom':
                    ({ contracts: contractsToDeploy, strategy } = await this.customMode());
                    break;
                
                default:
                    console.log("❌ Invalid mode selected");
                    return;
            }

            if (!contractsToDeploy || contractsToDeploy.length === 0) {
                console.log("⚠️  No contracts selected for deployment");
                return;
            }

            // 3. Solicitar opciones adicionales
            const options = await this.menu.showOptions();

            // 4. Confirmación final
            const confirmed = await this.menu.confirmDeployment(
                contractsToDeploy,
                strategy,
                null // TODO: Agregar estimación de gas
            );

            if (!confirmed) {
                console.log("❌ Deployment cancelled by user");
                return;
            }

            // 5. Crear backup si está habilitado
            let backupFile = null;
            if (options.backup) {
                console.log("\n💾 Creating backup of current addresses...");
                backupFile = this.addressManager.backupAddresses();
            }

            // 6. Modo dry-run
            if (options.dryRun) {
                console.log("\n🧪 DRY RUN MODE - No actual deployment will occur\n");
                contractsToDeploy.forEach(contract => {
                    const action = this.getContractAction(contract, strategy);
                    console.log(`   [DRY RUN] ${action}: ${contract.name}`);
                });
                console.log("\n✅ Dry run completed\n");
                return;
            }

            // 7. Ejecutar deployment
            const existingAddresses = this.addressManager.loadExistingAddresses();
            const results = await this.strategy.executeStrategy(
                contractsToDeploy,
                strategy,
                existingAddresses
            );

            // 8. Actualizar direcciones
            if (options.updateEnv && (results.successful.length > 0 || results.upgraded.length > 0)) {
                console.log("\n💾 Updating addresses...");
                const newAddresses = this.extractNewAddresses(results);
                this.addressManager.updateAddresses(newAddresses, {
                    updateEnv: true,
                    updateDeployment: true
                });
            }

            // 9. Verificar contratos en Polygonscan
            if (options.verify && this.network !== 'hardhat' && this.network !== 'localhost') {
                await this.verifyContracts(results);
            }

            // 10. Mostrar resultado final
            this.menu.showFinalResult({
                ...results,
                backupFile: backupFile ? path.basename(backupFile) : null
            });

        } catch (error) {
            console.error("\n❌ DEPLOYMENT ERROR:");
            console.error(error);
            this.menu.showError(error.message);
        }
    }

    /**
     * Modo Smart: Detecta y sugiere cambios
     */
    async smartMode() {
        console.log("\n🎯 SMART MODE: Detecting modified contracts...\n");

        const modifiedContracts = this.analyzer.detectModifiedContracts();

        if (modifiedContracts.length === 0) {
            console.log("✅ No modified contracts detected since last deployment");
            console.log("   All contracts are up to date!\n");
            
            const deploy = await this.menu.promptSelect(
                "Do you want to deploy anyway?",
                [
                    { name: 'No, exit', value: false },
                    { name: 'Yes, select contracts manually', value: true }
                ]
            );

            if (!deploy) {
                return { contracts: [], strategy: null };
            }

            return this.customMode();
        }

        // Mostrar reporte de cambios
        const report = this.analyzer.generateChangeReport(modifiedContracts);
        console.log(report);

        // Sugerir estrategia
        const strategy = this.analyzer.suggestDeploymentStrategy(modifiedContracts);
        
        console.log("\n💡 SUGGESTED STRATEGY:");
        console.log(`   Action: ${strategy.action}`);
        
        if (strategy.warnings.length > 0) {
            console.log("\n   ⚠️  Warnings:");
            strategy.warnings.forEach(w => console.log(`      ${w}`));
        }
        
        if (strategy.recommendations.length > 0) {
            console.log("\n   📋 Recommendations:");
            strategy.recommendations.forEach(r => console.log(`      ${r}`));
        }

        // Permitir selección manual
        const selected = await this.menu.showContractSelection(
            modifiedContracts,
            modifiedContracts // Todos preseleccionados
        );

        return { contracts: selected, strategy };
    }

    /**
     * Modo Upgrade: Solo actualiza contratos existentes
     */
    async upgradeMode() {
        console.log("\n🔄 UPGRADE MODE: Preserving all addresses\n");

        const existingAddresses = this.addressManager.loadExistingAddresses();
        const report = this.addressManager.generateAddressReport(existingAddresses);
        console.log(report);

        // Obtener todos los contratos que tienen dirección existente
        const allContracts = this.getAllDeployableContracts();
        const upgradableContracts = allContracts.filter(contract => 
            this.hasExistingContractAddress(contract, existingAddresses)
        );

        if (upgradableContracts.length === 0) {
            console.log("⚠️  No upgradable contracts found");
            return { contracts: [], strategy: null };
        }

        const selected = await this.menu.showContractSelection(
            upgradableContracts,
            upgradableContracts
        );

        const strategy = {
            action: 'UPGRADE',
            contracts: selected.map(c => ({ name: c.name, action: 'UPGRADE' })),
            warnings: ['All contracts will preserve their current addresses'],
            recommendations: []
        };

        return { contracts: selected, strategy };
    }

    /**
     * Modo Fresh: Deployment nuevo de todos los contratos
     */
    async freshMode() {
        console.log("\n🆕 FRESH MODE: New deployment (new addresses)\n");
        console.log("⚠️  This will create NEW addresses for all contracts");
        console.log("   Your frontend will need to be updated with new addresses\n");

        const confirm = await this.menu.promptSelect(
            "Are you sure you want to continue?",
            [
                { name: 'No, go back', value: false },
                { name: 'Yes, deploy fresh', value: true }
            ]
        );

        if (!confirm) {
            return { contracts: [], strategy: null };
        }

        const allContracts = this.getAllDeployableContracts();
        const selected = await this.menu.showContractSelection(allContracts, allContracts);

        const strategy = {
            action: 'DEPLOY',
            contracts: selected.map(c => ({ name: c.name, action: 'DEPLOY' })),
            warnings: ['All contracts will have NEW addresses'],
            recommendations: ['Update frontend configuration after deployment']
        };

        return { contracts: selected, strategy };
    }

    /**
     * Modo Custom: Selección manual con estrategia mixta
     */
    async customMode() {
        console.log("\n✅ CUSTOM MODE: Manual selection\n");

        const allContracts = this.getAllDeployableContracts();
        const selected = await this.menu.showContractSelection(allContracts);

        if (selected.length === 0) {
            return { contracts: [], strategy: null };
        }

        // Determinar estrategia para cada contrato
        const existingAddresses = this.addressManager.loadExistingAddresses();
        const strategyContracts = selected.map(contract => {
            // Obtener acción recomendada basada en el tipo de contrato
            const recommendedAction = this.getRecommendedAction(contract, existingAddresses);
            
            return {
                name: contract.name,
                action: recommendedAction,
                hasExisting: this.hasExistingContractAddress(contract, existingAddresses)
            };
        });

        // Preguntar acción para cada contrato
        console.log("\n📋 Configure action for each contract:\n");
        
        for (const sc of strategyContracts) {
            const choices = [];
            
            if (sc.hasExisting) {
                choices.push(
                    { name: '🔄 UPGRADE (preserve address)', value: 'UPGRADE' },
                    { name: '🆕 REDEPLOY (new address)', value: 'DEPLOY' }
                );
            } else {
                choices.push(
                    { name: '🆕 DEPLOY (new contract)', value: 'DEPLOY' }
                );
            }

            const action = await this.menu.promptSelect(
                `${sc.name} ${sc.hasExisting ? '(has existing address)' : '(new)'}:`,
                choices
            );

            sc.action = action;
        }

        const strategy = {
            action: 'mixed',
            contracts: strategyContracts,
            warnings: [],
            recommendations: []
        };

        return { contracts: selected, strategy };
    }

    /**
     * Obtener todos los contratos deployables
     */
    getAllDeployableContracts() {
        // Lista de contratos disponibles para deployment
        const contracts = [
            // Staking
            { name: 'EnhancedSmartStakingCore', category: 'staking', path: 'contracts/SmartStaking/EnhancedSmartStakingCore.sol' },
            { name: 'EnhancedSmartStakingRewards', category: 'staking', path: 'contracts/SmartStaking/EnhancedSmartStakingRewards.sol' },
            { name: 'EnhancedSmartStakingSkills', category: 'staking', path: 'contracts/SmartStaking/EnhancedSmartStakingSkills.sol' },
            { name: 'EnhancedSmartStakingGamification', category: 'staking', path: 'contracts/SmartStaking/EnhancedSmartStakingGamification.sol' },
            
            // Marketplace - Core & Proxies
            { name: 'GameifiedMarketplaceCoreV1', category: 'marketplace', path: 'contracts/Marketplace/GameifiedMarketplaceCoreV1.sol' },
            
            // Marketplace - Skills & NFTs
            { name: 'GameifiedMarketplaceSkillsNft', category: 'marketplace', path: 'contracts/Marketplace/GameifiedMarketplaceSkillsNft.sol' },
            { name: 'IndividualSkillsMarketplace', category: 'marketplace', path: 'contracts/Marketplace/IndividualSkillsMarketplace.sol' },
            { name: 'IndividualSkillsMarketplaceImpl', category: 'marketplace', path: 'contracts/Marketplace/IndividualSkillsMarketplaceImpl.sol' },
            
            // Marketplace - Features & Systems
            { name: 'GameifiedMarketplaceQuests', category: 'marketplace', path: 'contracts/Marketplace/GameifiedMarketplaceQuests.sol' },
            { name: 'LevelingSystem', category: 'marketplace', path: 'contracts/Marketplace/LevelingSystem.sol' },
            { name: 'ReferralSystem', category: 'marketplace', path: 'contracts/Marketplace/ReferralSystem.sol' },
            
            // Marketplace - View & Social
            { name: 'MarketplaceView', category: 'marketplace', path: 'contracts/Marketplace/MarketplaceView.sol' },
            { name: 'MarketplaceSocial', category: 'marketplace', path: 'contracts/Marketplace/MarketplaceSocial.sol' },
            { name: 'MarketplaceStatistics', category: 'marketplace', path: 'contracts/Marketplace/MarketplaceStatistics.sol' },
            
            // Treasury
            { name: 'TreasuryManager', category: 'treasury', path: 'contracts/Treasury/TreasuryManager.sol' },
            
            // Other
            { name: 'CollaboratorBadgeRewards', category: 'other', path: 'contracts/Marketplace/CollaboratorBadgeRewards.sol' },
            { name: 'DynamicAPYCalculator', category: 'other', path: 'contracts/SmartStaking/DynamicAPYCalculator.sol' }
        ];

        return contracts;
    }

    /**
     * Obtener acción para un contrato según la estrategia
     */
    getContractAction(contract, strategy) {
        if (!strategy) return 'DEPLOY';
        
        if (strategy.action === 'mixed') {
            const sc = strategy.contracts.find(c => c.name === contract.name);
            return sc?.action || 'DEPLOY';
        }
        
        return strategy.action;
    }

    /**
     * Extraer nuevas direcciones de los resultados
     */
    extractNewAddresses(results) {
        const addresses = {
            staking: {},
            marketplace: {},
            treasury: {},
            other: {}
        };

        [...results.successful, ...results.upgraded].forEach(result => {
            const category = this.getCategoryForContract(result.contractName);
            const key = this.getKeyForContract(result.contractName);
            const address = result.address || result.proxyAddress;
            
            if (category && key && address) {
                addresses[category][key] = address;
            }
        });

        return addresses;
    }

    /**
     * Obtener categoría para un contrato
     */
    getCategoryForContract(contractName) {
        if (contractName.includes('Staking')) return 'staking';
        if (contractName.includes('Marketplace') || contractName.includes('Individual') ||
            contractName.includes('Leveling') || contractName.includes('Referral') || 
            contractName.includes('Quest') || contractName.includes('Social') ||
            contractName.includes('Statistics')) return 'marketplace';
        if (contractName.includes('Treasury')) return 'treasury';
        return 'other';
    }

    /**
     * Obtener key para un contrato
     */
    getKeyForContract(contractName) {
        const keyMap = {
            'EnhancedSmartStakingCore': 'core',
            'EnhancedSmartStakingRewards': 'rewards',
            'EnhancedSmartStakingSkills': 'skills',
            'EnhancedSmartStakingGamification': 'gamification',
            'EnhancedSmartStakingView': 'view',
            'GameifiedMarketplaceCoreV1': 'implementation',
            'GameifiedMarketplaceProxy': 'proxy',
            'GameifiedMarketplaceSkillsNft': 'skillsNFT',
            'IndividualSkillsMarketplace': 'individualSkills',
            'IndividualSkillsMarketplaceImpl': 'individualSkillsImpl',
            'GameifiedMarketplaceQuests': 'quests',
            'LevelingSystem': 'leveling',
            'ReferralSystem': 'referral',
            'MarketplaceView': 'view',
            'MarketplaceSocial': 'social',
            'MarketplaceStatistics': 'statistics',
            'TreasuryManager': 'manager',
            'CollaboratorBadgeRewards': 'collaboratorBadges',
            'DynamicAPYCalculator': 'dynamicAPY'
        };

        return keyMap[contractName];
    }

    /**
     * Verificar contratos en Polygonscan
     */
    async verifyContracts(results) {
        console.log("\n🔍 Verifying contracts on Polygonscan...\n");

        const contractsToVerify = [...results.successful, ...results.upgraded];

        for (const contract of contractsToVerify) {
            try {
                console.log(`   Verifying ${contract.contractName}...`);
                
                await hre.run("verify:verify", {
                    address: contract.address || contract.proxyAddress,
                    constructorArguments: []
                });

                console.log(`   ✅ Verified ${contract.contractName}`);

            } catch (error) {
                if (error.message.includes("Already Verified")) {
                    console.log(`   ℹ️  ${contract.contractName} already verified`);
                } else {
                    console.log(`   ⚠️  Failed to verify ${contract.contractName}: ${error.message}`);
                }
            }
        }
    }

    /**
     * Get recommended action for a contract
     * Staking = UPGRADE (preserve), New = DEPLOY, Others = based on existence
     */
    getRecommendedAction(contract, existingAddresses) {
        const contractName = contract.name || '';
        
        // Staking contracts: ALWAYS UPGRADE to preserve addresses
        if (contractName.includes('EnhancedSmartStaking') || 
            contractName.includes('DynamicAPY')) {
            return 'UPGRADE';
        }
        
        // New contracts: ALWAYS DEPLOY (don't have existing addresses yet)
        const newContracts = ['MarketplaceView', 'MarketplaceSocial', 'MarketplaceStatistics', 
                             'GameifiedMarketplaceProxy', 'IndividualSkillsMarketplaceImpl'];
        if (newContracts.includes(contractName)) {
            return 'DEPLOY';
        }
        
        // Others: UPGRADE if exists, DEPLOY if not
        const hasExisting = this.hasExistingContractAddress(contract, existingAddresses);
        return hasExisting ? 'UPGRADE' : 'DEPLOY';
    }

    /**
     * Check if a contract has an existing address
     * @param {Object} contract - Contract object with name/contractName property
     * @param {Object} existingAddresses - Object with categories of addresses
     * @returns {boolean}
     */
    hasExistingContractAddress(contract, existingAddresses) {
        const contractName = (contract.name || contract.contractName || '').toLowerCase();
        
        // Map contract names to their category keys
        const nameMappings = {
            'enhancedsmartsakingcore': { category: 'staking', key: 'core' },
            'enhancedsmartstakingrewards': { category: 'staking', key: 'rewards' },
            'enhancedsmartskills': { category: 'staking', key: 'skills' },
            'enhancedsmartgamification': { category: 'staking', key: 'gamification' },
            'enhancedsmartview': { category: 'staking', key: 'view' },
            'gameifiedmarketplacecore': { category: 'marketplace', key: 'implementation' },
            'gameifiedmarketplaceproxy': { category: 'marketplace', key: 'proxy' },
            'gameifiedmarketplaceskills': { category: 'marketplace', key: 'skillsNFT' },
            'gameifiedmarketplaceskillsnft': { category: 'marketplace', key: 'skillsNFT' },
            'individualskillsmarketplace': { category: 'marketplace', key: 'individualSkills' },
            'individualskillsmarketplaceimpl': { category: 'marketplace', key: 'individualSkillsImpl' },
            'gameifiedmarketplacequests': { category: 'marketplace', key: 'quests' },
            'levelingsystem': { category: 'marketplace', key: 'leveling' },
            'referralsystem': { category: 'marketplace', key: 'referral' },
            'marketplaceview': { category: 'marketplace', key: 'view' },
            'marketplacesocial': { category: 'marketplace', key: 'social' },
            'marketplacestatistics': { category: 'marketplace', key: 'statistics' },
            'treasurymanager': { category: 'treasury', key: 'manager' },
            'collaboratorbadgerewards': { category: 'other', key: 'collaboratorBadges' },
            'dynamicapycalculator': { category: 'other', key: 'dynamicAPY' },
        };
        
        // Try to find the mapping
        const mapping = nameMappings[contractName];
        if (mapping) {
            const category = existingAddresses[mapping.category];
            if (category && category[mapping.key]) {
                return true;
            }
        }
        
        // Fallback: check if there are ANY existing addresses (conservative approach)
        for (const category in existingAddresses) {
            const categoryAddresses = existingAddresses[category];
            if (!categoryAddresses || typeof categoryAddresses !== 'object') continue;
            
            for (const key in categoryAddresses) {
                const addr = categoryAddresses[key];
                if (addr && typeof addr === 'string' && addr.startsWith('0x')) {
                    return true;
                }
            }
        }
        
        return false;
    }
}

/**
 * Función principal
 */
async function main() {
    const deployment = new SmartDeployment();
    await deployment.initialize();
    await deployment.run();
}

// Ejecutar
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
