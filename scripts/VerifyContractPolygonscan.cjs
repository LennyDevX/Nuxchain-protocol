const axios = require('axios');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

/**
 * Script para verificar contratos en Polygonscan usando directamente su API
 * Usa la API v2 de Etherscan/Polygonscan
 */

async function verifyContract() {
  // Configuración
  const contractAddress = "0x1F170b1E441291041A7a62e6231feE7096005302";
  const constructorArgs = "000000000000000000000000ad14c117b51735c072d42571e30bf2c729cd9593";
  const apiKey = process.env.POLYGONSCAN_API_KEY;
  
  console.log('\n🔍 Verificando contrato en Polygonscan...\n');
  console.log(`📋 Contrato: ${contractAddress}`);
  console.log(`🔗 Polygonscan: https://polygonscan.com/address/${contractAddress}\n`);

  // Leer el código del contrato aplanado
  const contractPath = path.join(__dirname, '..', 'contracts', 'SmartStaking', 'SmartStaking.sol');
  
  if (!fs.existsSync(contractPath)) {
    console.error('❌ No se encontró el archivo del contrato');
    console.log('💡 Ejecuta: npx hardhat flatten contracts/SmartStaking/SmartStaking.sol > SmartStaking-flat.sol');
    process.exit(1);
  }

  const sourceCode = fs.readFileSync(contractPath, 'utf8');

  // Parámetros para la API de Polygonscan
  const params = {
    apikey: apiKey,
    module: 'contract',
    action: 'verifysourcecode',
    contractaddress: contractAddress,
    sourceCode: sourceCode,
    codeformat: 'solidity-single-file',
    contractname: 'SmartStaking',
    compilerversion: 'v0.8.28+commit.7893614a', // Verificar versión exacta
    optimizationUsed: 1,
    runs: 200,
    constructorArguements: constructorArgs,
    evmversion: 'shanghai',
    licenseType: 3 // MIT License
  };

  try {
    console.log('📤 Enviando solicitud de verificación...\n');
    
    const response = await axios.post(
      'https://api.polygonscan.com/api',
      new URLSearchParams(params),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );

    console.log('📥 Respuesta recibida:\n');
    console.log(JSON.stringify(response.data, null, 2));

    if (response.data.status === '1') {
      const guid = response.data.result;
      console.log('\n✅ Verificación iniciada exitosamente!');
      console.log(`📝 GUID: ${guid}`);
      console.log('\n⏳ Esperando resultado (esto puede tomar 1-2 minutos)...\n');
      
      // Esperar y verificar el estado
      await checkVerificationStatus(guid, apiKey);
    } else {
      console.error('\n❌ Error en la verificación:');
      console.error(response.data.result);
      
      console.log('\n💡 Soluciones posibles:');
      console.log('1. Verifica que el API key sea válido');
      console.log('2. Genera un nuevo API key en: https://polygonscan.com/myapikey');
      console.log('3. Usa verificación manual en Polygonscan');
    }
  } catch (error) {
    console.error('\n❌ Error al conectar con Polygonscan:');
    console.error(error.message);
    
    if (error.response) {
      console.error('\n📥 Respuesta del servidor:');
      console.error(error.response.data);
    }
  }
}

async function checkVerificationStatus(guid, apiKey) {
  const maxAttempts = 20;
  let attempts = 0;

  while (attempts < maxAttempts) {
    attempts++;
    
    try {
      await new Promise(resolve => setTimeout(resolve, 5000)); // Esperar 5 segundos
      
      const response = await axios.get('https://api.polygonscan.com/api', {
        params: {
          apikey: apiKey,
          module: 'contract',
          action: 'checkverifystatus',
          guid: guid
        }
      });

      console.log(`Intento ${attempts}/${maxAttempts}: ${response.data.result}`);

      if (response.data.status === '1' && response.data.result !== 'Pending in queue') {
        console.log('\n✅ ¡Contrato verificado exitosamente!');
        console.log(`🔗 Ver en: https://polygonscan.com/address/${contractAddress}#code`);
        return;
      }
    } catch (error) {
      console.error(`Error en intento ${attempts}:`, error.message);
    }
  }

  console.log('\n⏰ Tiempo de espera agotado. Verifica manualmente en:');
  console.log(`https://polygonscan.com/address/${contractAddress}#code`);
}

// Ejecutar
verifyContract().catch(console.error);
