const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

/**
 * 📍 ADDRESS MANAGER
 * 
 * Gestiona direcciones de contratos deployados, backups y actualizaciones
 */

class AddressManager {
    constructor(projectRoot, network) {
        this.projectRoot = projectRoot;
        this.network = network;
        this.deploymentsDir = path.join(projectRoot, "deployments");
        this.envFile = path.join(projectRoot, ".env");
        
        // Asegurar que existe el directorio de deployments
        if (!fs.existsSync(this.deploymentsDir)) {
            fs.mkdirSync(this.deploymentsDir, { recursive: true });
        }
    }

    /**
     * Cargar direcciones existentes desde archivos de deployment
     * @returns {Object} Mapa de contractName -> address
     */
    loadExistingAddresses() {
        const addresses = {
            staking: {},
            marketplace: {},
            treasury: {},
            other: {}
        };

        try {
            // Intentar cargar desde complete-deployment.json
            const completeFile = path.join(this.deploymentsDir, "complete-deployment.json");
            if (fs.existsSync(completeFile)) {
                const deployment = JSON.parse(fs.readFileSync(completeFile, "utf8"));

                const contractGroups = this.getContractGroups(deployment);

                if (contractGroups.staking) {
                    Object.entries(contractGroups.staking).forEach(([key, value]) => {
                        if (typeof value === 'object' && value.address) {
                            addresses.staking[key] = value.address;
                        } else if (typeof value === 'string' && value.startsWith('0x')) {
                            addresses.staking[key] = value;
                        }
                    });
                }

                if (contractGroups.marketplace) {
                    Object.entries(contractGroups.marketplace).forEach(([key, value]) => {
                        if (typeof value === 'object' && value.address) {
                            addresses.marketplace[key] = value.address;
                        } else if (typeof value === 'string' && value.startsWith('0x')) {
                            addresses.marketplace[key] = value;
                        }
                    });
                }

                if (contractGroups.treasury) {
                    Object.entries(contractGroups.treasury).forEach(([key, value]) => {
                        if (typeof value === 'object' && value.address) {
                            addresses.treasury[key] = value.address;
                        } else if (typeof value === 'string' && value.startsWith('0x')) {
                            addresses.treasury[key] = value;
                        }
                    });
                }

                if (contractGroups.other) {
                    Object.entries(contractGroups.other).forEach(([key, value]) => {
                        if (typeof value === 'object' && value.address) {
                            addresses.other[key] = value.address;
                        } else if (typeof value === 'string' && value.startsWith('0x')) {
                            addresses.other[key] = value;
                        }
                    });
                }
            }

            // También cargar desde .env como fallback
            const envAddresses = this.loadFromEnv();
            
            // Merge, priorizando deployment.json
            this.mergeAddresses(addresses, envAddresses);

            console.log(`✅ Loaded ${this.countAddresses(addresses)} existing addresses`);
            
        } catch (error) {
            console.warn("⚠️  Error loading existing addresses:", error.message);
        }

        return addresses;
    }

    /**
     * Normalizar archivos de deployment antiguos y nuevos a la misma forma.
     * @param {Object} deployment
     * @returns {{staking?: Object, marketplace?: Object, treasury?: Object, other?: Object}}
     */
    getContractGroups(deployment) {
        if (deployment.contracts && typeof deployment.contracts === 'object') {
            return deployment.contracts;
        }

        return {
            staking: deployment.staking,
            marketplace: deployment.marketplace,
            treasury: deployment.treasury,
            other: deployment.other
        };
    }

    /**
     * Cargar direcciones desde .env
     * @returns {Object}
     */
    loadFromEnv() {
        const addresses = {
            staking: {},
            marketplace: {},
            treasury: {},
            other: {}
        };

        try {
            if (!fs.existsSync(this.envFile)) {
                return addresses;
            }

            const envContent = fs.readFileSync(this.envFile, 'utf8');
            const lines = envContent.split('\n');

            lines.forEach(line => {
                const trimmed = line.trim();
                if (!trimmed || trimmed.startsWith('#')) return;

                const [key, value] = trimmed.split('=').map(s => s.trim());
                if (!key || !value || !value.startsWith('0x')) return;

                // Mapear variables de .env a categorías
                if (key.includes('STAKING')) {
                    const contractKey = this.envKeyToContractKey(key);
                    addresses.staking[contractKey] = value;
                } else if (key.includes('MARKETPLACE') || key.includes('INDIVIDUAL') || 
                          key.includes('LEVELING') || key.includes('REFERRAL') || 
                          key.includes('QUEST')) {
                    const contractKey = this.envKeyToContractKey(key);
                    addresses.marketplace[contractKey] = value;
                } else if (key.includes('TREASURY')) {
                    addresses.treasury.manager = value;
                } else if (key.includes('COLLABORATOR') || key.includes('BADGE')) {
                    addresses.other.collaboratorBadges = value;
                } else if (key.includes('DYNAMIC_APY')) {
                    addresses.other.dynamicAPY = value;
                }
            });

        } catch (error) {
            console.warn("⚠️  Error reading .env:", error.message);
        }

        return addresses;
    }

    /**
     * Convertir key de .env a key de contrato
     * @param {string} envKey
     * @returns {string}
     */
    envKeyToContractKey(envKey) {
        const mapping = {
            'VITE_ENHANCED_SMARTSTAKING_ADDRESS': 'core',
            'VITE_ENHANCED_SMARTSTAKING_REWARDS_ADDRESS': 'rewards',
            'VITE_ENHANCED_SMARTSTAKING_SKILLS_ADDRESS': 'skills',
            'VITE_ENHANCED_SMARTSTAKING_GAMIFICATION_ADDRESS': 'gamification',
            'VITE_ENHANCED_SMARTSTAKING_VIEWER_ADDRESS': 'view',
            'VITE_GAMEIFIED_MARKETPLACE_PROXY': 'proxy',
            'VITE_GAMEIFIED_MARKETPLACE_CORE': 'implementation',
            'VITE_GAMEIFIED_MARKETPLACE_SKILLS': 'skillsNFT',
            'VITE_INDIVIDUAL_SKILLS': 'nuxPowers',
            'VITE_GAMEIFIED_MARKETPLACE_QUESTS': 'quests',
            'VITE_LEVELING_SYSTEM': 'leveling',
            'VITE_REFERRAL_SYSTEM': 'referral'
        };

        return mapping[envKey] || envKey.toLowerCase().replace(/vite_|_address/g, '');
    }

    /**
     * Validar que un contrato existe en la blockchain
     * @param {string} address
     * @returns {Promise<Object>} {exists, isProxy, codeSize}
     */
    async validateExistingContract(address) {
        try {
            const code = await ethers.provider.getCode(address);
            const exists = code !== '0x';
            const codeSize = code.length;
            
            // Detectar si es un proxy (simplificado - busca patrón de UUPS)
            const isProxy = code.includes('360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc');

            return {
                exists,
                isProxy,
                codeSize,
                address
            };
        } catch (error) {
            console.warn(`⚠️  Error validating ${address}:`, error.message);
            return {
                exists: false,
                isProxy: false,
                codeSize: 0,
                address,
                error: error.message
            };
        }
    }

    /**
     * Crear backup de direcciones actuales
     * @param {Object} addresses
     * @returns {string} Path del archivo de backup
     */
    backupAddresses(addresses = null) {
        try {
            if (!addresses) {
                addresses = this.loadExistingAddresses();
            }

            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const backupFile = path.join(
                this.deploymentsDir, 
                `backup-${this.network}-${timestamp}.json`
            );

            const backupData = {
                network: this.network,
                timestamp: new Date().toISOString(),
                addresses: addresses
            };

            fs.writeFileSync(backupFile, JSON.stringify(backupData, null, 2));
            console.log(`💾 Backup created: ${path.basename(backupFile)}`);

            return backupFile;
        } catch (error) {
            console.error("❌ Error creating backup:", error.message);
            throw error;
        }
    }

    /**
     * Actualizar direcciones con nuevos deployments
     * @param {Object} newAddresses - {category: {contractKey: address}}
     * @param {Object} options - {updateEnv, updateDeployment}
     */
    updateAddresses(newAddresses, options = {}) {
        const { updateEnv = true, updateDeployment = true } = options;

        try {
            // Cargar direcciones existentes
            const existing = this.loadExistingAddresses();

            // Merge nuevas direcciones
            const merged = this.mergeAddresses(existing, newAddresses);

            if (updateDeployment) {
                this.saveToDeploymentFile(merged);
            }

            if (updateEnv) {
                this.updateEnvFile(merged);
            }

            console.log("✅ Addresses updated successfully");

        } catch (error) {
            console.error("❌ Error updating addresses:", error.message);
            throw error;
        }
    }

    /**
     * Guardar direcciones en archivo de deployment
     * @param {Object} addresses
     */
    saveToDeploymentFile(addresses) {
        const deploymentFile = path.join(this.deploymentsDir, "complete-deployment.json");
        const addressesFile = path.join(this.deploymentsDir, "addresses.json");
        
        let deploymentData = {};
        
        // Cargar existente si hay
        if (fs.existsSync(deploymentFile)) {
            deploymentData = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
        }

        // Actualizar con nuevas direcciones manteniendo estructura
        deploymentData.deployment = deploymentData.deployment || {};
        deploymentData.deployment.timestamp = new Date().toISOString();
        deploymentData.deployment.network = this.network;
        deploymentData.contracts = deploymentData.contracts || {};
        deploymentData.contracts.staking = deploymentData.contracts.staking || {};
        deploymentData.contracts.marketplace = deploymentData.contracts.marketplace || {};
        deploymentData.contracts.treasury = deploymentData.contracts.treasury || {};
        deploymentData.contracts.other = deploymentData.contracts.other || {};

        if (addresses.staking) {
            Object.entries(addresses.staking).forEach(([key, value]) => {
                if (typeof deploymentData.contracts.staking[key] === 'object') {
                    deploymentData.contracts.staking[key].address = value;
                } else {
                    deploymentData.contracts.staking[key] = value;
                }
            });
        }

        if (addresses.marketplace) {
            Object.entries(addresses.marketplace).forEach(([key, value]) => {
                if (typeof deploymentData.contracts.marketplace[key] === 'object') {
                    deploymentData.contracts.marketplace[key].address = value;
                } else {
                    deploymentData.contracts.marketplace[key] = value;
                }
            });
        }

        if (addresses.treasury) {
            Object.entries(addresses.treasury).forEach(([key, value]) => {
                if (typeof deploymentData.contracts.treasury[key] === 'object') {
                    deploymentData.contracts.treasury[key].address = value;
                } else {
                    deploymentData.contracts.treasury[key] = value;
                }
            });
        }

        if (addresses.other) {
            Object.entries(addresses.other).forEach(([key, value]) => {
                if (typeof deploymentData.contracts.other[key] === 'object') {
                    deploymentData.contracts.other[key].address = value;
                } else {
                    deploymentData.contracts.other[key] = value;
                }
            });
        }

        fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
        fs.writeFileSync(addressesFile, JSON.stringify(this.flattenAddresses(addresses), null, 2));
        console.log(`💾 Deployment file updated: complete-deployment.json`);
    }

    /**
     * Crear un mapa plano util para frontends.
     * @param {Object} addresses
     * @returns {Object}
     */
    flattenAddresses(addresses) {
        const flat = {};

        ['staking', 'marketplace', 'treasury', 'other'].forEach((category) => {
            if (!addresses[category]) {
                return;
            }

            Object.entries(addresses[category]).forEach(([key, value]) => {
                flat[`${category}.${key}`] = value;
            });
        });

        return flat;
    }

    /**
     * Actualizar archivo .env con nuevas direcciones
     * @param {Object} addresses
     */
    updateEnvFile(addresses) {
        try {
            let envContent = '';
            
            if (fs.existsSync(this.envFile)) {
                envContent = fs.readFileSync(this.envFile, 'utf8');
            }

            const updates = this.generateEnvUpdates(addresses);

            updates.forEach(({ key, value }) => {
                const regex = new RegExp(`^${key}=.*$`, 'm');
                if (regex.test(envContent)) {
                    // Actualizar existente
                    envContent = envContent.replace(regex, `${key}=${value}`);
                } else {
                    // Agregar nuevo
                    envContent += `\n${key}=${value}`;
                }
            });

            fs.writeFileSync(this.envFile, envContent);
            console.log(`💾 .env file updated with ${updates.length} addresses`);

        } catch (error) {
            console.error("❌ Error updating .env:", error.message);
        }
    }

    /**
     * Generar actualizaciones de .env
     * @param {Object} addresses
     * @returns {Array<{key, value}>}
     */
    generateEnvUpdates(addresses) {
        const updates = [];

        // Staking
        if (addresses.staking?.core) {
            updates.push({ key: 'VITE_ENHANCED_SMARTSTAKING_ADDRESS', value: addresses.staking.core });
        }
        if (addresses.staking?.rewards) {
            updates.push({ key: 'VITE_ENHANCED_SMARTSTAKING_REWARDS_ADDRESS', value: addresses.staking.rewards });
        }
        if (addresses.staking?.skills) {
            updates.push({ key: 'VITE_ENHANCED_SMARTSTAKING_SKILLS_ADDRESS', value: addresses.staking.skills });
        }
        if (addresses.staking?.gamification) {
            updates.push({ key: 'VITE_ENHANCED_SMARTSTAKING_GAMIFICATION_ADDRESS', value: addresses.staking.gamification });
        }
        if (addresses.staking?.view) {
            updates.push({ key: 'VITE_ENHANCED_SMARTSTAKING_VIEWER_ADDRESS', value: addresses.staking.view });
        }

        // Marketplace
        if (addresses.marketplace?.proxy) {
            updates.push({ key: 'VITE_GAMEIFIED_MARKETPLACE_PROXY', value: addresses.marketplace.proxy });
            updates.push({ key: 'VITE_GAMEIFIED_MARKETPLACE_CORE', value: addresses.marketplace.proxy });
        }
        if (addresses.marketplace?.skillsNFT) {
            updates.push({ key: 'VITE_GAMEIFIED_MARKETPLACE_SKILLS', value: addresses.marketplace.skillsNFT });
        }
        if (addresses.marketplace?.nuxPowers) {
            updates.push({ key: 'VITE_INDIVIDUAL_SKILLS', value: addresses.marketplace.nuxPowers });
        }
        if (addresses.marketplace?.quests) {
            updates.push({ key: 'VITE_GAMEIFIED_MARKETPLACE_QUESTS', value: addresses.marketplace.quests });
        }
        if (addresses.marketplace?.leveling) {
            updates.push({ key: 'VITE_LEVELING_SYSTEM', value: addresses.marketplace.leveling });
        }
        if (addresses.marketplace?.referral) {
            updates.push({ key: 'VITE_REFERRAL_SYSTEM', value: addresses.marketplace.referral });
        }

        // Treasury
        if (addresses.treasury?.manager) {
            updates.push({ key: 'VITE_TREASURY_MANAGER_ADDRESS', value: addresses.treasury.manager });
        }

        // Other
        if (addresses.other?.collaboratorBadges) {
            updates.push({ key: 'VITE_COLLABORATOR_BADGE_REWARDS_ADDRESS', value: addresses.other.collaboratorBadges });
        }
        if (addresses.other?.dynamicAPY) {
            updates.push({ key: 'VITE_DYNAMIC_APY_CALCULATOR_ADDRESS', value: addresses.other.dynamicAPY });
        }

        return updates;
    }

    /**
     * Merge dos objetos de direcciones
     * @param {Object} target
     * @param {Object} source
     * @returns {Object}
     */
    mergeAddresses(target, source) {
        const merged = JSON.parse(JSON.stringify(target)); // Deep clone

        ['staking', 'marketplace', 'treasury', 'other'].forEach(category => {
            if (source[category]) {
                merged[category] = { ...merged[category], ...source[category] };
            }
        });

        return merged;
    }

    /**
     * Contar total de direcciones
     * @param {Object} addresses
     * @returns {number}
     */
    countAddresses(addresses) {
        let count = 0;
        ['staking', 'marketplace', 'treasury', 'other'].forEach(category => {
            if (addresses[category]) {
                count += Object.keys(addresses[category]).length;
            }
        });
        return count;
    }

    /**
     * Generar reporte de direcciones
     * @param {Object} addresses
     * @returns {string}
     */
    generateAddressReport(addresses) {
        let report = "\n╔════════════════════════════════════════════════════════════════╗\n";
        report += "║  📍 CURRENT CONTRACT ADDRESSES                               ║\n";
        report += "╚════════════════════════════════════════════════════════════════╝\n\n";

        if (addresses.staking && Object.keys(addresses.staking).length > 0) {
            report += "🔷 STAKING CONTRACTS:\n";
            Object.entries(addresses.staking).forEach(([key, addr]) => {
                report += `   ${key.padEnd(20)}: ${addr}\n`;
            });
            report += "\n";
        }

        if (addresses.marketplace && Object.keys(addresses.marketplace).length > 0) {
            report += "🔷 MARKETPLACE CONTRACTS:\n";
            Object.entries(addresses.marketplace).forEach(([key, addr]) => {
                report += `   ${key.padEnd(20)}: ${addr}\n`;
            });
            report += "\n";
        }

        if (addresses.treasury && Object.keys(addresses.treasury).length > 0) {
            report += "🔷 TREASURY:\n";
            Object.entries(addresses.treasury).forEach(([key, addr]) => {
                report += `   ${key.padEnd(20)}: ${addr}\n`;
            });
            report += "\n";
        }

        if (addresses.other && Object.keys(addresses.other).length > 0) {
            report += "🔷 OTHER CONTRACTS:\n";
            Object.entries(addresses.other).forEach(([key, addr]) => {
                report += `   ${key.padEnd(20)}: ${addr}\n`;
            });
            report += "\n";
        }

        return report;
    }
}

module.exports = AddressManager;
