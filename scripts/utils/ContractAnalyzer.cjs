const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

/**
 * 🔍 CONTRACT ANALYZER
 * 
 * Detecta contratos modificados y analiza dependencias
 */

class ContractAnalyzer {
    constructor(projectRoot) {
        this.projectRoot = projectRoot;
        this.contractsDir = path.join(projectRoot, "contracts");
        this.deploymentsDir = path.join(projectRoot, "deployments");
    }

    /**
     * Detectar contratos modificados desde el último deployment
     * @param {Date} sinceDate - Fecha desde la cual buscar cambios
     * @returns {Array<string>} Array de nombres de contratos modificados
     */
    detectModifiedContracts(sinceDate = null) {
        try {
            // Si no se proporciona fecha, usar última deployment
            if (!sinceDate) {
                sinceDate = this.getLastDeploymentDate();
            }

            if (!sinceDate) {
                console.log("⚠️  No previous deployment found. All contracts will be considered modified.");
                return this.getAllContracts();
            }

            const modifiedFiles = this.getModifiedFilesSinceDate(sinceDate);
            const modifiedContracts = this.filterContractFiles(modifiedFiles);

            return modifiedContracts;
        } catch (error) {
            console.error("❌ Error detecting modified contracts:", error.message);
            return [];
        }
    }

    /**
     * Obtener fecha del último deployment
     * @returns {Date|null}
     */
    getLastDeploymentDate() {
        try {
            const deploymentFile = path.join(this.deploymentsDir, "complete-deployment.json");
            
            if (!fs.existsSync(deploymentFile)) {
                return null;
            }

            const deployment = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
            return new Date(deployment.deployment?.timestamp || deployment.timestamp);
        } catch (error) {
            console.warn("⚠️  Could not read deployment date:", error.message);
            return null;
        }
    }

    /**
     * Obtener archivos modificados usando git
     * @param {Date} sinceDate
     * @returns {Array<string>}
     */
    getModifiedFilesSinceDate(sinceDate) {
        try {
            const dateStr = sinceDate.toISOString().split('T')[0];
            
            // Intentar usar git log
            const gitCommand = `git log --since="${dateStr}" --name-only --pretty=format: -- contracts/`;
            const output = execSync(gitCommand, { 
                cwd: this.projectRoot,
                encoding: 'utf8'
            });

            const files = output
                .split('\n')
                .filter(Boolean)
                .filter(f => f.trim().length > 0)
                .map(f => f.trim());

            return [...new Set(files)]; // Eliminar duplicados
        } catch (error) {
            // Si git falla, usar sistema de archivos
            console.warn("⚠️  Git not available, using filesystem modification times");
            return this.getModifiedFilesByTimestamp(sinceDate);
        }
    }

    /**
     * Obtener archivos modificados por timestamp del filesystem
     * @param {Date} sinceDate
     * @returns {Array<string>}
     */
    getModifiedFilesByTimestamp(sinceDate) {
        const modifiedFiles = [];
        const sinceTimestamp = sinceDate.getTime();

        const walkDir = (dir) => {
            const files = fs.readdirSync(dir);
            
            files.forEach(file => {
                const fullPath = path.join(dir, file);
                const stat = fs.statSync(fullPath);
                
                if (stat.isDirectory()) {
                    walkDir(fullPath);
                } else if (file.endsWith('.sol')) {
                    if (stat.mtimeMs > sinceTimestamp) {
                        const relativePath = path.relative(this.projectRoot, fullPath);
                        modifiedFiles.push(relativePath);
                    }
                }
            });
        };

        walkDir(this.contractsDir);
        return modifiedFiles;
    }

    /**
     * Filtrar solo archivos .sol y extraer nombres de contratos
     * @param {Array<string>} files
     * @returns {Array<Object>} Array de {name, path, category}
     */
    filterContractFiles(files) {
        return files
            .filter(f => f.endsWith('.sol'))
            .map(f => {
                const filename = path.basename(f, '.sol');
                const category = this.categorizeContract(f);
                
                return {
                    name: filename,
                    path: f,
                    category: category,
                    fullPath: path.join(this.projectRoot, f)
                };
            });
    }

    /**
     * Categorizar contrato por su ubicación
     * @param {string} filePath
     * @returns {string}
     */
    categorizeContract(filePath) {
        if (filePath.includes('SmartStaking')) return 'staking';
        if (filePath.includes('Marketplace')) return 'marketplace';
        if (filePath.includes('Treasury')) return 'treasury';
        if (filePath.includes('interfaces')) return 'interface';
        return 'other';
    }

    /**
     * Obtener todos los contratos del proyecto
     * @returns {Array<Object>}
     */
    getAllContracts() {
        const allFiles = [];
        
        const walkDir = (dir) => {
            const files = fs.readdirSync(dir);
            
            files.forEach(file => {
                const fullPath = path.join(dir, file);
                const stat = fs.statSync(fullPath);
                
                if (stat.isDirectory() && !file.startsWith('.')) {
                    walkDir(fullPath);
                } else if (file.endsWith('.sol')) {
                    const relativePath = path.relative(this.projectRoot, fullPath);
                    allFiles.push(relativePath);
                }
            });
        };

        walkDir(this.contractsDir);
        return this.filterContractFiles(allFiles);
    }

    /**
     * Obtener dependencias de un contrato parseando imports
     * @param {string} contractPath
     * @returns {Array<string>}
     */
    getContractDependencies(contractPath) {
        try {
            const content = fs.readFileSync(contractPath, 'utf8');
            const importRegex = /import\s+["'](.+?)["'];/g;
            const dependencies = [];
            
            let match;
            while ((match = importRegex.exec(content)) !== null) {
                const importPath = match[1];
                
                // Filtrar solo imports locales (no de node_modules)
                if (!importPath.startsWith('@')) {
                    dependencies.push(importPath);
                }
            }
            
            return dependencies;
        } catch (error) {
            console.warn(`⚠️  Could not read dependencies for ${contractPath}`);
            return [];
        }
    }

    /**
     * Sugerir estrategia de deployment basado en cambios
     * @param {Array<Object>} modifiedContracts
     * @returns {Object}
     */
    suggestDeploymentStrategy(modifiedContracts) {
        const strategy = {
            action: 'SMART',
            contracts: [],
            warnings: [],
            recommendations: []
        };

        const stakingContracts = modifiedContracts.filter(c => c.category === 'staking');
        const marketplaceContracts = modifiedContracts.filter(c => c.category === 'marketplace');

        // Analizar contratos de staking
        stakingContracts.forEach(contract => {
            if (contract.name.includes('Core') || contract.name === 'SmartStaking') {
                strategy.contracts.push({
                    ...contract,
                    action: 'UPGRADE',
                    reason: 'Core contract - preserve address via upgrade'
                });
                strategy.warnings.push(
                    `⚠️  ${contract.name} is a Core contract. Upgrade recommended to preserve address.`
                );
            } else {
                strategy.contracts.push({
                    ...contract,
                    action: 'REDEPLOY',
                    reason: 'Module contract - safe to redeploy with new address'
                });
            }
        });

        // Analizar contratos de marketplace
        marketplaceContracts.forEach(contract => {
            if (contract.name.includes('Proxy') || contract.name.includes('CoreV1')) {
                strategy.contracts.push({
                    ...contract,
                    action: 'UPGRADE',
                    reason: 'UUPS Proxy - should upgrade existing proxy'
                });
                strategy.warnings.push(
                    `⚠️  ${contract.name} is a Proxy contract. Consider upgradeProxy() instead of new deploy.`
                );
            } else {
                strategy.contracts.push({
                    ...contract,
                    action: 'REDEPLOY',
                    reason: 'Module contract - safe to redeploy'
                });
            }
        });

        // Recomendaciones generales
        if (stakingContracts.length > 0) {
            strategy.recommendations.push(
                "💡 Staking contracts detected. Remember to preserve existing addresses for frontend compatibility."
            );
        }

        if (marketplaceContracts.length > 0) {
            strategy.recommendations.push(
                "💡 Marketplace contracts detected. UUPS proxies can be upgraded without changing addresses."
            );
        }

        if (modifiedContracts.length === 0) {
            strategy.action = 'NONE';
            strategy.recommendations.push(
                "✅ No modified contracts detected since last deployment."
            );
        }

        return strategy;
    }

    /**
     * Generar reporte de cambios
     * @param {Array<Object>} modifiedContracts
     * @returns {string}
     */
    generateChangeReport(modifiedContracts) {
        let report = "\n╔════════════════════════════════════════════════════════════════╗\n";
        report += "║  📊 CONTRACT MODIFICATION REPORT                             ║\n";
        report += "╚════════════════════════════════════════════════════════════════╝\n\n";

        if (modifiedContracts.length === 0) {
            report += "✅ No contracts modified since last deployment.\n";
            return report;
        }

        const byCategory = modifiedContracts.reduce((acc, contract) => {
            if (!acc[contract.category]) acc[contract.category] = [];
            acc[contract.category].push(contract);
            return acc;
        }, {});

        Object.entries(byCategory).forEach(([category, contracts]) => {
            report += `\n📁 ${category.toUpperCase()}:\n`;
            contracts.forEach(contract => {
                report += `   • ${contract.name}\n`;
                report += `     Path: ${contract.path}\n`;
            });
        });

        report += `\n📊 Total: ${modifiedContracts.length} contract(s) modified\n`;

        return report;
    }
}

module.exports = ContractAnalyzer;
