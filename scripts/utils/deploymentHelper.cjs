const fs = require("fs");
const path = require("path");
const { run } = require("hardhat");

/**
 * Deployment Helper Utilities
 * Provides common functions for contract deployment, verification, and data persistence
 */

/**
 * Load deployment data from JSON file
 * @param {string} networkName - Network name (e.g., "polygon", "mumbai")
 * @param {string} fileType - File type ("staking", "marketplace", "complete")
 * @returns {Object} Deployment data object
 */
function loadDeployment(networkName, fileType = "staking") {
    const deploymentsDir = path.join(__dirname, "..", "..", "deployments");
    const filePath = path.join(deploymentsDir, `${networkName}-${fileType}.json`);
    
    if (!fs.existsSync(filePath)) {
        throw new Error(`❌ Deployment file not found: ${filePath}`);
    }
    
    try {
        const fileContent = fs.readFileSync(filePath, "utf8");
        const data = JSON.parse(fileContent);
        console.log(`✅ Loaded deployment from: ${filePath}`);
        return data;
    } catch (error) {
        throw new Error(`❌ Failed to parse deployment file: ${error.message}`);
    }
}

/**
 * Save deployment data to JSON file
 * @param {string} networkName - Network name
 * @param {Object} data - Deployment data to save
 * @param {string} fileType - File type suffix
 */
function saveDeployment(networkName, data, fileType = "staking") {
    const deploymentsDir = path.join(__dirname, "..", "..", "deployments");
    
    // Create deployments directory if it doesn't exist
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    const filePath = path.join(deploymentsDir, `${networkName}-${fileType}.json`);
    
    // Add metadata
    const dataWithMetadata = {
        ...data,
        savedAt: new Date().toISOString(),
        network: networkName
    };
    
    try {
        fs.writeFileSync(filePath, JSON.stringify(dataWithMetadata, null, 2));
        console.log(`💾 Saved deployment to: ${filePath}`);
    } catch (error) {
        throw new Error(`❌ Failed to save deployment: ${error.message}`);
    }
}

/**
 * Validate that all required contract references are set
 * @param {Object} contracts - Object containing contract instances
 * @param {Array} validations - Array of validation rules
 * @returns {Promise<boolean>} True if all validations pass
 */
async function validateReferences(contracts, validations) {
    console.log("\n🔍 Validating cross-contract references...\n");
    
    let allValid = true;
    
    for (const validation of validations) {
        try {
            const { name, contract, method, expected, optional } = validation;
            
            if (!contracts[contract]) {
                if (optional) {
                    console.log(`  ⚠️  ${name}: Contract ${contract} not found (optional)`);
                    continue;
                }
                throw new Error(`Contract ${contract} not found`);
            }
            
            // Call the method to get the actual value
            const actual = await contracts[contract][method]();
            
            // Normalize addresses for comparison
            const actualNormalized = actual.toLowerCase();
            const expectedNormalized = expected.toLowerCase();
            
            if (actualNormalized === expectedNormalized) {
                console.log(`  ✅ ${name}: ${actual}`);
            } else {
                console.log(`  ❌ ${name}: Expected ${expected}, got ${actual}`);
                allValid = false;
            }
        } catch (error) {
            console.log(`  ❌ ${validation.name}: ${error.message}`);
            allValid = false;
        }
    }
    
    if (allValid) {
        console.log("\n✅ All validations passed!\n");
    } else {
        console.log("\n❌ Some validations failed\n");
    }
    
    return allValid;
}

/**
 * Verify contract on Polygonscan with retry logic
 * @param {string} address - Contract address
 * @param {string} fullyQualifiedName - Fully qualified contract name
 * @param {Array} constructorArgs - Constructor arguments
 * @param {Object} options - Retry options
 * @returns {Promise<boolean>} True if verification succeeded
 */
async function verifyContract(
    address, 
    fullyQualifiedName, 
    constructorArgs = [], 
    options = {}
) {
    const {
        maxAttempts = 3,
        delayMs = 7000,
        skipIfVerified = true
    } = options;
    
    let attempt = 0;
    
    while (attempt < maxAttempts) {
        try {
            attempt++;
            console.log(`  🔍 Verifying ${fullyQualifiedName} (attempt ${attempt}/${maxAttempts})...`);
            
            await run("verify:verify", {
                address: address,
                constructorArguments: constructorArgs,
                contract: fullyQualifiedName
            });
            
            console.log(`  ✅ Successfully verified: ${address}`);
            return true;
            
        } catch (err) {
            const msg = err && err.message ? err.message : String(err);
            
            // Check if already verified
            if (msg.toLowerCase().includes("already verified")) {
                if (skipIfVerified) {
                    console.log(`  ℹ️  Already verified: ${address}`);
                    return true;
                }
            }
            
            // If not last attempt, wait and retry
            if (attempt < maxAttempts) {
                console.log(`  ⚠️  Attempt ${attempt} failed: ${msg}`);
                console.log(`  ⏳ Retrying in ${delayMs / 1000}s...`);
                await new Promise((resolve) => setTimeout(resolve, delayMs));
            } else {
                console.log(`  ❌ All ${maxAttempts} attempts failed: ${msg}`);
                return false;
            }
        }
    }
    
    return false;
}

/**
 * Wait for contract bytecode to be available on-chain
 * @param {Object} provider - Ethers provider instance
 * @param {string} address - Contract address
 * @param {Object} options - Retry options
 * @returns {Promise<boolean>} True if bytecode found
 */
async function waitForContractCode(provider, address, options = {}) {
    const { retries = 30, delay = 5000, verbose = true } = options;
    
    for (let attempt = 1; attempt <= retries; attempt++) {
        const code = await provider.getCode(address);
        
        if (code !== '0x' && code.length > 2) {
            if (verbose) {
                console.log(`  ✅ Contract bytecode confirmed at ${address}`);
            }
            return true;
        }
        
        if (attempt < retries) {
            if (verbose) {
                console.log(`  ⏳ Waiting for bytecode (${attempt}/${retries})...`);
            }
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }
    
    throw new Error(`❌ No bytecode found at ${address} after ${retries * delay / 1000}s`);
}

/**
 * Check if an address has contract code deployed
 * @param {Object} provider - Ethers provider instance
 * @param {string} address - Address to check
 * @returns {Promise<boolean>} True if address has contract code
 */
async function hasContractCode(provider, address) {
    const code = await provider.getCode(address);
    return code !== '0x' && code.length > 2;
}

/**
 * Validate that an address is not zero address
 * @param {string} address - Address to validate
 * @param {string} name - Name for error message
 * @throws {Error} If address is zero address
 */
function validateNonZeroAddress(address, name) {
    const zeroAddress = "0x0000000000000000000000000000000000000000";
    if (address.toLowerCase() === zeroAddress) {
        throw new Error(`❌ ${name} is zero address`);
    }
}

/**
 * Format deployment summary for console output
 * @param {Object} deployment - Deployment data object
 * @returns {string} Formatted summary
 */
function formatDeploymentSummary(deployment) {
    let summary = "\n════════════════════════════════════════════════════════════════════════════════════════\n";
    summary += "📋 DEPLOYMENT SUMMARY\n";
    summary += "════════════════════════════════════════════════════════════════════════════════════════\n\n";
    
    summary += `Network:     ${deployment.network}\n`;
    summary += `Chain ID:    ${deployment.chainId}\n`;
    summary += `Deployer:    ${deployment.deployer}\n`;
    summary += `Treasury:    ${deployment.treasury || 'N/A'}\n`;
    summary += `Deployed At: ${deployment.deployedAt}\n\n`;
    
    summary += "Contracts:\n";
    for (const [name, info] of Object.entries(deployment.contracts)) {
        summary += `  ${name.padEnd(20)} ${info.address}\n`;
    }
    
    summary += "\n════════════════════════════════════════════════════════════════════════════════════════\n";
    
    return summary;
}

/**
 * Merge two deployment files (useful for combining staking + marketplace)
 * @param {string} networkName - Network name
 * @param {string} sourceType - Source file type
 * @param {string} targetType - Target file type
 */
function mergeDeployments(networkName, sourceType, targetType) {
    const source = loadDeployment(networkName, sourceType);
    const target = loadDeployment(networkName, targetType);
    
    const merged = {
        ...target,
        contracts: {
            ...target.contracts,
            ...source.contracts
        },
        mergedFrom: [sourceType, targetType],
        mergedAt: new Date().toISOString()
    };
    
    saveDeployment(networkName, merged, "complete");
    console.log(`✅ Merged ${sourceType} + ${targetType} → complete`);
    
    return merged;
}

/**
 * Get contract ABI from artifacts
 * @param {string} contractName - Name of the contract
 * @param {string} contractPath - Relative path from contracts/ directory
 * @returns {Object} Contract ABI
 */
function getContractABI(contractName, contractPath = null) {
    const artifactsDir = path.join(__dirname, "..", "..", "artifacts", "contracts");
    
    let abiPath;
    if (contractPath) {
        abiPath = path.join(artifactsDir, contractPath, `${contractName}.sol`, `${contractName}.json`);
    } else {
        // Search for contract in common locations
        const commonPaths = [
            path.join(artifactsDir, "SmartStaking", `${contractName}.sol`, `${contractName}.json`),
            path.join(artifactsDir, "Marketplace", `${contractName}.sol`, `${contractName}.json`),
            path.join(artifactsDir, `${contractName}.sol`, `${contractName}.json`)
        ];
        
        for (const testPath of commonPaths) {
            if (fs.existsSync(testPath)) {
                abiPath = testPath;
                break;
            }
        }
    }
    
    if (!abiPath || !fs.existsSync(abiPath)) {
        throw new Error(`❌ ABI not found for ${contractName}`);
    }
    
    const artifact = JSON.parse(fs.readFileSync(abiPath, "utf8"));
    return artifact.abi;
}

module.exports = {
    loadDeployment,
    saveDeployment,
    validateReferences,
    verifyContract,
    waitForContractCode,
    hasContractCode,
    validateNonZeroAddress,
    formatDeploymentSummary,
    mergeDeployments,
    getContractABI
};
