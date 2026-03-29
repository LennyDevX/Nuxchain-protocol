/**
 * 📋 EXPORT ABIs SCRIPT
 * 
 * Extrae todos los ABIs de los contratos compilados y los guarda en un archivo JSON centralizado
 * 
 * Uso:
 *   npx hardhat run scripts/ExportABIs.cjs
 * 
 * Output:
 *   frontend/abis/all-abis.json        - Todos los ABIs en un solo archivo
 *   frontend/abis/abis-by-category.json - ABIs organizados por categoría
 */

const fs = require('fs');
const path = require('path');

// ════════════════════════════════════════════════════════════════════════════════════════
// RUTAS
// ════════════════════════════════════════════════════════════════════════════════════════

const ARTIFACTS_DIR = path.join(__dirname, '..', 'artifacts', 'contracts');
const ABIS_OUTPUT_DIR = path.join(__dirname, '..', 'frontend', 'abis');

// ════════════════════════════════════════════════════════════════════════════════════════
// UTILIDADES
// ════════════════════════════════════════════════════════════════════════════════════════

/**
 * Busca recursivamente todos los archivos .json en un directorio
 */
function findJsonFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);

    files.forEach(file => {
        const filepath = path.join(dir, file);
        const stat = fs.statSync(filepath);

        if (stat.isDirectory()) {
            findJsonFiles(filepath, fileList);
        } else if (file.endsWith('.json') && !file.endsWith('.dbg.json')) {
            fileList.push(filepath);
        }
    });

    return fileList;
}

/**
 * Extrae el ABI de un archivo artifact
 */
function extractABI(filePath) {
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const artifact = JSON.parse(content);

        if (!artifact.abi) {
            console.warn(`⚠️  No ABI found in ${filePath}`);
            return null;
        }

        return {
            contractName: artifact.contractName,
            sourceName: artifact.sourceName,
            abi: artifact.abi
        };
    } catch (error) {
        console.error(`❌ Error reading ${filePath}:`, error.message);
        return null;
    }
}

/**
 * Determina la categoría basada en el path del archivo
 */
function getCategory(filePath) {
    const parts = filePath.split(path.sep);
    const index = parts.indexOf('contracts');
    
    if (index !== -1 && index + 1 < parts.length) {
        return parts[index + 1]; // SmartStaking, Marketplace, Treasury, etc.
    }
    return 'other';
}

// ════════════════════════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════════════════════════

async function main() {
    console.log("╔════════════════════════════════════════════════════════════════╗");
    console.log("║  📋 EXPORTING ABIs FROM COMPILED CONTRACTS                    ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    // 1. Crear directorio de output si no existe
    if (!fs.existsSync(ABIS_OUTPUT_DIR)) {
        fs.mkdirSync(ABIS_OUTPUT_DIR, { recursive: true });
        console.log(`✅ Created output directory: ${ABIS_OUTPUT_DIR}\n`);
    }

    // 2. Buscar todos los artifacts
    console.log("🔍 Searching for compiled artifacts...\n");
    const jsonFiles = findJsonFiles(ARTIFACTS_DIR);
    console.log(`✅ Found ${jsonFiles.length} artifact files\n`);

    // 3. Extraer ABIs
    console.log("📦 Extracting ABIs...\n");
    const allABIs = {};
    const abisByCategory = {};
    let successCount = 0;

    jsonFiles.forEach(filePath => {
        const abiData = extractABI(filePath);
        
        if (abiData) {
            const contractName = abiData.contractName;
            const category = getCategory(filePath);

            // Agregar a la colección general
            allABIs[contractName] = {
                name: contractName,
                category: category,
                source: abiData.sourceName,
                abi: abiData.abi
            };

            // Agregar a la colección por categoría
            if (!abisByCategory[category]) {
                abisByCategory[category] = {};
            }
            abisByCategory[category][contractName] = {
                name: contractName,
                source: abiData.sourceName,
                abi: abiData.abi
            };

            console.log(`   ✅ ${contractName.padEnd(40)} (${category})`);
            successCount++;
        }
    });

    console.log(`\n✅ Successfully extracted ${successCount} ABIs\n`);

    // 4. Guardar archivo unificado
    const allAbisPath = path.join(ABIS_OUTPUT_DIR, 'all-abis.json');
    fs.writeFileSync(allAbisPath, JSON.stringify(allABIs, null, 2));
    console.log(`💾 Saved all ABIs: ${allAbisPath}`);
    console.log(`   Size: ${(fs.statSync(allAbisPath).size / 1024).toFixed(2)} KB\n`);

    // 5. Guardar archivo por categorías
    const abisByCategoryPath = path.join(ABIS_OUTPUT_DIR, 'abis-by-category.json');
    fs.writeFileSync(abisByCategoryPath, JSON.stringify(abisByCategory, null, 2));
    console.log(`💾 Saved ABIs by category: ${abisByCategoryPath}`);
    console.log(`   Size: ${(fs.statSync(abisByCategoryPath).size / 1024).toFixed(2)} KB\n`);

    // 6. Generar index.ts para fácil importación
    const indexPath = path.join(ABIS_OUTPUT_DIR, 'index.ts');
    generateIndexFile(indexPath, allABIs);
    console.log(`💾 Generated TypeScript index: ${indexPath}\n`);

    // 7. Resumen por categoría
    console.log("📊 SUMMARY BY CATEGORY:\n");
    Object.entries(abisByCategory).forEach(([category, contracts]) => {
        console.log(`   🔷 ${category}: ${Object.keys(contracts).length} contract(s)`);
        Object.keys(contracts).forEach(name => {
            console.log(`      • ${name}`);
        });
    });

    console.log("\n╔════════════════════════════════════════════════════════════════╗");
    console.log("║  ✅ ABI EXPORT COMPLETED SUCCESSFULLY                         ║");
    console.log("╚════════════════════════════════════════════════════════════════╝\n");

    // 8. Imprimir instrucciones de uso
    console.log("📚 USAGE EXAMPLES:\n");
    console.log("   // Import all ABIs");
    console.log("   import allABIs from './abis/all-abis.json';\n");
    
    console.log("   // Access specific contract ABI");
    console.log("   const core = allABIs['SmartStaking'];\n");
    
    console.log("   // Use with ethers.js (v6)");
    console.log("   const contract = new ethers.Contract(address, core.abi, signer);\n");

    console.log("   // TypeScript import (from index.ts)");
    console.log("   import { SmartStaking } from './abis';\n");
}

/**
 * Genera un archivo index.ts para importación TypeScript
 */
function generateIndexFile(outputPath, allABIs) {
    let content = `/**
 * Auto-generated ABI Index
 * This file provides TypeScript-safe imports for all contract ABIs
 * 
 * Generated: ${new Date().toISOString()}
 */

`;

    // Generar exports para cada contrato
    Object.entries(allABIs).forEach(([contractName, data]) => {
        content += `export const ${contractName} = ${JSON.stringify(data.abi)} as const;\n`;
    });

    content += `\n// Export all ABIs as object\nexport const AllABIs = {\n`;
    Object.keys(allABIs).forEach(contractName => {
        content += `    ${contractName},\n`;
    });
    content += `};\n`;

    fs.writeFileSync(outputPath, content);
}

// ════════════════════════════════════════════════════════════════════════════════════════
// EJECUTAR
// ════════════════════════════════════════════════════════════════════════════════════════

main().catch(error => {
    console.error("❌ Error:", error);
    process.exit(1);
});
