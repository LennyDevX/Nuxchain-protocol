/**
 * @fileoverview Helper de verificación de contratos en exploradores de bloques
 * @description Proporciona una función reutilizable para verificar contratos con reintentos automáticos
 * @module verifyHelper
 */

const { run } = require("hardhat");

/**
 * Verifica un contrato en el explorador de bloques usando el plugin hardhat-etherscan con reintentos automáticos
 * 
 * @param {string} address - Dirección del contrato desplegado
 * @param {string} fullyQualifiedName - Nombre completo del contrato (ej: "contracts/Token.sol:Token")
 * @param {Array} constructorArgs - Array con los argumentos del constructor (default: [])
 * @param {number} maxAttempts - Número máximo de intentos (default: 3)
 * @param {number} delayMs - Delay en milisegundos entre intentos (default: 7000)
 * @returns {Promise<boolean>} - true si la verificación fue exitosa
 * @throws {Error} - Lanza el último error si todos los intentos fallan
 * 
 * @example
 * // Verificar contrato sin argumentos constructor
 * await verifyContract(
 *   "0x1234...",
 *   "contracts/MyToken.sol:MyToken"
 * );
 * 
 * @example
 * // Verificar contrato con argumentos constructor
 * await verifyContract(
 *   "0x1234...",
 *   "contracts/MyContract.sol:MyContract",
 *   ["0xTokenAddress", 100, true]
 * );
 * 
 * @example
 * // Verificar con más intentos y mayor delay
 * await verifyContract(
 *   "0x1234...",
 *   "contracts/MyContract.sol:MyContract",
 *   [],
 *   5,  // 5 intentos
 *   10000  // 10 segundos entre intentos
 * );
 */
async function verifyContract(
  address,
  fullyQualifiedName,
  constructorArgs = [],
  maxAttempts = 3,
  delayMs = 7000
) {
  let attempt = 0;
  
  // Validar parámetros
  if (!address || typeof address !== 'string') {
    throw new Error('La dirección del contrato es requerida y debe ser un string');
  }
  
  if (!fullyQualifiedName || typeof fullyQualifiedName !== 'string') {
    throw new Error('El nombre fully-qualified del contrato es requerido');
  }
  
  if (!Array.isArray(constructorArgs)) {
    throw new Error('constructorArgs debe ser un array');
  }

  console.log(`\n🔍 Iniciando verificación de contrato:`);
  console.log(`   📍 Dirección: ${address}`);
  console.log(`   📄 Contrato: ${fullyQualifiedName}`);
  if (constructorArgs.length > 0) {
    console.log(`   🔧 Constructor args: ${JSON.stringify(constructorArgs)}`);
  }

  while (attempt < maxAttempts) {
    try {
      attempt++;
      console.log(`\n🔄 Intento ${attempt}/${maxAttempts}...`);
      
      await run("verify:verify", {
        address: address,
        constructorArguments: constructorArgs,
        contract: fullyQualifiedName
      });
      
      // Si llega aquí, la verificación fue exitosa
      console.log(`✅ ¡Verificación exitosa!`);
      return true;
      
    } catch (err) {
      const msg = err && err.message ? err.message : String(err);
      
      // Casos de éxito (contrato ya verificado)
      if (
        msg.toLowerCase().includes("already verified") ||
        msg.toLowerCase().includes("reason: already verified") ||
        msg.toLowerCase().includes("contract source code already verified")
      ) {
        console.log("ℹ️  Contrato ya verificado anteriormente.");
        return true;
      }
      
      // Casos de error recuperable (reintentar)
      const isRecoverable = 
        msg.toLowerCase().includes("timeout") ||
        msg.toLowerCase().includes("rate limit") ||
        msg.toLowerCase().includes("connection") ||
        msg.toLowerCase().includes("econnreset") ||
        msg.toLowerCase().includes("socket hang up");
      
      // Casos de error no recuperable (no reintentar)
      const isUnrecoverable = 
        msg.toLowerCase().includes("does not match") ||
        msg.toLowerCase().includes("not present in your project") ||
        msg.toLowerCase().includes("invalid api key") ||
        msg.toLowerCase().includes("wrong constructor arguments");
      
      if (isUnrecoverable) {
        console.log(`❌ Error no recuperable: ${msg}`);
        console.log(`💡 Revisa el nombre del contrato, argumentos del constructor y configuración del proyecto`);
        throw err;
      }
      
      // Último intento fallido
      if (attempt >= maxAttempts) {
        console.log(`❌ Intento ${attempt} fallido: ${msg}`);
        console.log(`❌ No quedan más intentos. Verificación manual requerida.`);
        throw err;
      }
      
      // Intento fallido pero hay más intentos disponibles
      console.log(`❗ Intento ${attempt} fallido: ${msg}`);
      
      // Ajustar delay si es error de rate limit
      const currentDelay = msg.toLowerCase().includes("rate limit") ? delayMs * 2 : delayMs;
      console.log(`⏳ Esperando ${currentDelay / 1000} segundos antes de reintentar...`);
      
      await new Promise((resolve) => setTimeout(resolve, currentDelay));
    }
  }
  
  // Este punto no debería alcanzarse nunca, pero por si acaso
  throw new Error('Verificación falló después de todos los intentos');
}

/**
 * Verifica múltiples contratos en secuencia con manejo de errores individual
 * 
 * @param {Array<Object>} contracts - Array de objetos con la información de cada contrato
 * @param {string} contracts[].address - Dirección del contrato
 * @param {string} contracts[].name - Nombre para logging (ej: "Token")
 * @param {string} contracts[].fullyQualifiedName - Nombre fully-qualified
 * @param {Array} contracts[].constructorArgs - Argumentos del constructor
 * @returns {Promise<Object>} - Objeto con resultados de cada verificación
 * 
 * @example
 * const results = await verifyMultipleContracts([
 *   {
 *     address: "0x1234...",
 *     name: "Token",
 *     fullyQualifiedName: "contracts/Token.sol:Token",
 *     constructorArgs: []
 *   },
 *   {
 *     address: "0x5678...",
 *     name: "NFT",
 *     fullyQualifiedName: "contracts/NFT.sol:NFT",
 *     constructorArgs: ["0x1234..."]
 *   }
 * ]);
 * 
 * console.log(results);
 * // { Token: true, NFT: false }
 */
async function verifyMultipleContracts(contracts) {
  console.log(`\n🔍 Verificando ${contracts.length} contratos...`);
  
  const results = {};
  
  for (const contract of contracts) {
    try {
      console.log(`\n📝 Verificando ${contract.name}...`);
      
      const success = await verifyContract(
        contract.address,
        contract.fullyQualifiedName,
        contract.constructorArgs || []
      );
      
      results[contract.name] = success;
      
    } catch (error) {
      console.log(`❌ Error al verificar ${contract.name}:`, error.message);
      results[contract.name] = false;
    }
  }
  
  // Resumen
  console.log(`\n📊 Resumen de Verificación:`);
  const successful = Object.values(results).filter(r => r === true).length;
  console.log(`   ✅ Exitosas: ${successful}/${contracts.length}`);
  console.log(`   ❌ Fallidas: ${contracts.length - successful}/${contracts.length}`);
  
  return results;
}

module.exports = {
  verifyContract,
  verifyMultipleContracts
};
