const inquirer = require('inquirer');

/**
 * 🎯 INTERACTIVE MENU
 * 
 * Sistema de menús interactivos para selección de contratos y opciones de deployment
 */

class InteractiveMenu {
    constructor() {
        this.selections = {
            mode: null,
            contracts: [],
            options: {}
        };
    }

    /**
     * Mostrar menú principal
     * @returns {Promise<string>} Modo seleccionado
     */
    async showMainMenu() {
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║  🚀 NUXCHAIN SMART DEPLOYMENT SYSTEM                        ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");

        const { mode } = await inquirer.prompt([
            {
                type: 'list',
                name: 'mode',
                message: '📋 Select deployment mode:',
                choices: [
                    {
                        name: '🎯 Smart Deploy (Only modified contracts)',
                        value: 'smart',
                        short: 'Smart'
                    },
                    {
                        name: '🔄 Upgrade Only (Preserve all addresses)',
                        value: 'upgrade',
                        short: 'Upgrade'
                    },
                    {
                        name: '🆕 Deploy New (Fresh deployment)',
                        value: 'fresh',
                        short: 'Fresh'
                    },
                    {
                        name: '✅ Custom Selection (Manual choice)',
                        value: 'custom',
                        short: 'Custom'
                    },
                    {
                        name: '❌ Cancel',
                        value: 'cancel',
                        short: 'Cancel'
                    }
                ],
                default: 'smart'
            }
        ]);

        this.selections.mode = mode;
        return mode;
    }

    /**
     * Mostrar selección de contratos con checkboxes
     * @param {Array} contracts - Lista de contratos disponibles
     * @param {Array} preselected - Contratos preseleccionados
     * @returns {Promise<Array>} Contratos seleccionados
     */
    async showContractSelection(contracts, preselected = []) {
        if (!contracts || contracts.length === 0) {
            console.log("⚠️  No contracts available for selection");
            return [];
        }

        // Agrupar por categoría
        const grouped = this.groupContractsByCategory(contracts);

        console.log("\n📦 Available contracts:");
        
        const choices = [];

        // Crear choices con separadores por categoría
        Object.entries(grouped).forEach(([category, categoryContracts]) => {
            if (categoryContracts.length > 0) {
                // Separador de categoría
                choices.push(new inquirer.Separator(`\n━━ ${category.toUpperCase()} ━━`));
                
                categoryContracts.forEach(contract => {
                    const isPreselected = preselected.some(p => p.name === contract.name);
                    const statusIcon = isPreselected ? '🟢' : '⚪';
                    
                    choices.push({
                        name: `${statusIcon} ${contract.name.padEnd(35)} (${contract.path})`,
                        value: contract,
                        checked: isPreselected
                    });
                });
            }
        });

        const { selected } = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'selected',
                message: '✅ Select contracts to deploy (use Space to select, Enter to confirm):',
                choices: choices,
                pageSize: 15,
                validate: (answer) => {
                    if (answer.length === 0) {
                        return 'You must select at least one contract';
                    }
                    return true;
                }
            }
        ]);

        this.selections.contracts = selected;
        return selected;
    }

    /**
     * Mostrar confirmación de deployment con estrategia
     * @param {Array} contracts - Contratos a deployar
     * @param {Object} strategy - Estrategia de deployment
     * @param {Object} gasEstimate - Estimación de gas
     * @returns {Promise<boolean>} Confirmación
     */
    async confirmDeployment(contracts, strategy, gasEstimate = null) {
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║  📋 DEPLOYMENT PLAN SUMMARY                                   ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");

        console.log(`Mode: ${this.selections.mode?.toUpperCase() || 'N/A'}`);
        console.log(`Total contracts: ${contracts.length}\n`);

        // Mostrar contratos por acción
        const upgradeContracts = contracts.filter(c => 
            strategy && strategy.action === 'mixed' 
                ? strategy.contracts.some(sc => sc.name === c.name && sc.action === 'UPGRADE')
                : strategy?.action === 'UPGRADE'
        );

        const deployContracts = contracts.filter(c => 
            strategy && strategy.action === 'mixed' 
                ? strategy.contracts.some(sc => sc.name === c.name && sc.action === 'REDEPLOY')
                : strategy?.action !== 'UPGRADE'
        );

        if (upgradeContracts.length > 0) {
            console.log("🔄 UPGRADE (Preserve addresses):");
            upgradeContracts.forEach(c => {
                console.log(`   • ${c.name} (${c.category})`);
            });
            console.log();
        }

        if (deployContracts.length > 0) {
            console.log("🆕 NEW DEPLOYMENT (New addresses):");
            deployContracts.forEach(c => {
                console.log(`   • ${c.name} (${c.category})`);
            });
            console.log();
        }

        // Mostrar warnings
        if (strategy?.warnings && strategy.warnings.length > 0) {
            console.log("⚠️  WARNINGS:");
            strategy.warnings.forEach(w => console.log(`   ${w}`));
            console.log();
        }

        // Mostrar estimación de gas
        if (gasEstimate) {
            console.log("⛽ GAS ESTIMATION:");
            console.log(`   Estimated cost: ${gasEstimate.total} MATIC`);
            console.log(`   Gas price: ${gasEstimate.gasPrice} Gwei`);
            console.log();
        }

        const { confirm } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirm',
                message: '🚀 Proceed with deployment?',
                default: false
            }
        ]);

        return confirm;
    }

    /**
     * Preguntar por opciones adicionales
     * @returns {Promise<Object>} Opciones seleccionadas
     */
    async showOptions() {
        const { options } = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'options',
                message: '⚙️  Select additional options:',
                choices: [
                    {
                        name: '📸 Create backup before deployment',
                        value: 'backup',
                        checked: true
                    },
                    {
                        name: '🔍 Verify contracts on Polygonscan',
                        value: 'verify',
                        checked: true
                    },
                    {
                        name: '🌡️  Show gas optimization suggestions',
                        value: 'gasOptimize',
                        checked: false
                    },
                    {
                        name: '🧪 Dry run (simulate without deploying)',
                        value: 'dryRun',
                        checked: false
                    },
                    {
                        name: '💾 Update .env file automatically',
                        value: 'updateEnv',
                        checked: true
                    }
                ]
            }
        ]);

        this.selections.options = {
            backup: options.includes('backup'),
            verify: options.includes('verify'),
            gasOptimize: options.includes('gasOptimize'),
            dryRun: options.includes('dryRun'),
            updateEnv: options.includes('updateEnv')
        };

        return this.selections.options;
    }

    /**
     * Preguntar por confirmación de upgrade específico
     * @param {string} contractName
     * @param {string} currentAddress
     * @param {string} newImplementation
     * @returns {Promise<boolean>}
     */
    async confirmUpgrade(contractName, currentAddress, newImplementation) {
        console.log(`\n🔄 Upgrading ${contractName}:`);
        console.log(`   Current proxy: ${currentAddress}`);
        console.log(`   New implementation: ${newImplementation}`);

        const { confirm } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirm',
                message: 'Confirm upgrade?',
                default: true
            }
        ]);

        return confirm;
    }

    /**
     * Mostrar progreso de deployment
     * @param {string} contractName
     * @param {string} status - 'pending', 'deploying', 'success', 'error'
     * @param {Object} details
     */
    showProgress(contractName, status, details = {}) {
        const icons = {
            pending: '⏳',
            deploying: '🚀',
            success: '✅',
            error: '❌',
            warning: '⚠️'
        };

        const icon = icons[status] || '•';
        let message = `${icon} ${contractName}`;

        if (details.address) {
            message += ` → ${details.address}`;
        }
        if (details.txHash) {
            message += ` (tx: ${details.txHash.substring(0, 10)}...)`;
        }
        if (details.error) {
            message += ` - Error: ${details.error}`;
        }

        console.log(message);
    }

    /**
     * Agrupar contratos por categoría
     * @param {Array} contracts
     * @returns {Object}
     */
    groupContractsByCategory(contracts) {
        const grouped = {
            staking: [],
            marketplace: [],
            treasury: [],
            other: []
        };

        contracts.forEach(contract => {
            const category = contract.category || 'other';
            if (grouped[category]) {
                grouped[category].push(contract);
            } else {
                grouped.other.push(contract);
            }
        });

        return grouped;
    }

    /**
     * Solicitar input de texto
     * @param {string} message
     * @param {string} defaultValue
     * @returns {Promise<string>}
     */
    async promptInput(message, defaultValue = '') {
        const { input } = await inquirer.prompt([
            {
                type: 'input',
                name: 'input',
                message: message,
                default: defaultValue
            }
        ]);

        return input;
    }

    /**
     * Mostrar menú de selección simple
     * @param {string} message
     * @param {Array} choices
     * @returns {Promise<string>}
     */
    async promptSelect(message, choices) {
        const { selection } = await inquirer.prompt([
            {
                type: 'list',
                name: 'selection',
                message: message,
                choices: choices
            }
        ]);

        return selection;
    }

    /**
     * Mostrar resultado final del deployment
     * @param {Object} result
     */
    showFinalResult(result) {
        console.log("\n╔════════════════════════════════════════════════════════════════╗");
        console.log("║  ✅ DEPLOYMENT COMPLETED                                      ║");
        console.log("╚════════════════════════════════════════════════════════════════╝\n");

        if (result.successful && result.successful.length > 0) {
            console.log("✅ SUCCESSFULLY DEPLOYED:");
            result.successful.forEach(c => {
                const contractName = c.contractName || c.name || 'Unknown';
                console.log(`   ${contractName.padEnd(35)} → ${c.address}`);
            });
            console.log();
        }

        if (result.upgraded && result.upgraded.length > 0) {
            console.log("🔄 SUCCESSFULLY UPGRADED:");
            result.upgraded.forEach(c => {
                const contractName = c.contractName || c.name || 'Unknown';
                console.log(`   ${contractName.padEnd(35)} → ${c.address}`);
            });
            console.log();
        }

        if (result.failed && result.failed.length > 0) {
            console.log("❌ FAILED:");
            result.failed.forEach(c => {
                const contractName = c.contractName || c.name || 'Unknown';
                console.log(`   ${contractName}: ${c.error}`);
            });
            console.log();
        }

        if (result.gasUsed) {
            console.log(`⛽ Total gas used: ${result.gasUsed} MATIC`);
        }

        if (result.backupFile) {
            console.log(`💾 Backup saved: ${result.backupFile}`);
        }

        console.log(`\n🎉 Deployment session completed at ${new Date().toLocaleString()}\n`);
    }

    /**
     * Mostrar mensaje de error
     * @param {string} error
     */
    showError(error) {
        console.log("\n❌ ERROR:");
        console.log(`   ${error}\n`);
    }

    /**
     * Limpiar pantalla
     */
    clear() {
        console.clear();
    }
}

module.exports = InteractiveMenu;
