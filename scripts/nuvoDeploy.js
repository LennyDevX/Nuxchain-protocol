// scripts/nuvoDeploy.js

async function main() {
    // Obtenemos el contrato nuvoLogic a desplegar
    const NuvoLogic = await ethers.getContractFactory("StakingContract");
    const treasuryAddress = "0xc8EA26EC919320912c135f789E83458174c042c9";
    const nuvoLogic = await NuvoLogic.deploy(treasuryAddress); // Pasamos treasuryAddress al constructor

    await nuvoLogic.deployed();
    console.log("StakingContract desplegado en la dirección:", nuvoLogic.address);
    console.log("La dirección de la tesorería asignada al StakingContract es:", treasuryAddress);

    // Obtenemos el contrato NuvoLogicUpdate (contrato de actualización) a desplegar
    const NuvoLogicUpdate = await ethers.getContractFactory("UpdateContract");
    const nuvoLogicUpdate = await NuvoLogicUpdate.deploy(nuvoLogic.address); // Pasamos nuvoLogic.address al constructor

    await nuvoLogicUpdate.deployed();
    console.log("UpdateContract desplegado en la dirección:", nuvoLogicUpdate.address);

    // Si en el futuro necesitas cambiar `treasuryAddress` en el contrato de lógica, puedes utilizar la función
    // `setTreasury` en el contrato de lógica para hacer la actualización.
    // Y si necesitas cambiar a un nuevo contrato de lógica en el contrato 'UpdateContract', puedes utilizar
    // la función `setNewLogicContract` para hacer la actualización.
}

// Ejecutamos nuestra función main de despliegue
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });