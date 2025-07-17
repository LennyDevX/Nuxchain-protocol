const { expect } = require("chai");
const { ethers, network } = require("hardhat");

// Helper para avanzar el tiempo en la blockchain de prueba
async function advanceTime(seconds) {
    await network.provider.send("evm_increaseTime", [seconds]);
    await network.provider.send("evm_mine");
}

describe("AirdropFactory Contract", function () {
    let AirdropFactory, airdropFactory, TestToken, testToken1, testToken2;
    let owner, user1, user2, user3;
    
    // Parámetros de prueba para airdrops
    const REGISTRATION_DURATION = 60 * 60 * 24 * 7; // 7 días
    const CLAIM_DELAY = 60 * 60 * 24; // 1 día
    const CLAIM_DURATION = 60 * 60 * 24 * 30; // 30 días
    const AIRDROP_NAME_1 = "Test Airdrop #1";
    const AIRDROP_NAME_2 = "Test Airdrop #2";

    beforeEach(async function () {
        // Obtener cuentas de prueba
        [owner, user1, user2, user3] = await ethers.getSigners();

        // Desplegar tokens de prueba
        TestToken = await ethers.getContractFactory("contracts/TestToken.sol:TestToken");
        testToken1 = await TestToken.deploy("Test Token 1", "TT1", ethers.parseEther("1000000"));
        await testToken1.waitForDeployment();
        
        testToken2 = await TestToken.deploy("Test Token 2", "TT2", ethers.parseEther("1000000"));
        await testToken2.waitForDeployment();

        // Desplegar el AirdropFactory
        AirdropFactory = await ethers.getContractFactory("AirdropFactory");
        airdropFactory = await AirdropFactory.deploy();
        await airdropFactory.waitForDeployment();
    });

    describe("Deployment", function () {
        it("Should set the correct owner", async function () {
            expect(await airdropFactory.owner()).to.equal(owner.address);
        });

        it("Should initialize with zero airdrops", async function () {
            expect(await airdropFactory.getTotalAirdrops()).to.equal(0);
        });

        it("Should return empty array for user airdrops", async function () {
            const userAirdrops = await airdropFactory.getAirdropsByOwner(user1.address);
            expect(userAirdrops.length).to.equal(0);
        });
    });

    describe("Airdrop Deployment", function () {
        it("Should deploy a new airdrop contract", async function () {
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            const receipt = await tx.wait();
            
            // Verificar evento emitido
            const event = receipt.logs.find(log => 
                log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
            );
            
            expect(event).to.not.be.undefined;
            
            const decodedEvent = airdropFactory.interface.parseLog(event);
            expect(decodedEvent.args.owner).to.equal(user1.address);
            expect(decodedEvent.args.token).to.equal(await testToken1.getAddress());
            expect(decodedEvent.args.name).to.equal(AIRDROP_NAME_1);
            expect(decodedEvent.args.index).to.equal(0);

            // Verificar que el total de airdrops aumentó
            expect(await airdropFactory.getTotalAirdrops()).to.equal(1);
        });

        it("Should transfer ownership of deployed airdrop to caller", async function () {
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            const receipt = await tx.wait();
            const decodedEvent = airdropFactory.interface.parseLog(
                receipt.logs.find(log => 
                    log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
                )
            );

            const airdropAddress = decodedEvent.args.airdropContract;
            const airdrop = await ethers.getContractAt("Airdrop", airdropAddress);
            
            expect(await airdrop.owner()).to.equal(user1.address);
        });

        it("Should create airdrop with correct parameters", async function () {
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            const receipt = await tx.wait();
            const decodedEvent = airdropFactory.interface.parseLog(
                receipt.logs.find(log => 
                    log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
                )
            );

            const airdropAddress = decodedEvent.args.airdropContract;
            const airdrop = await ethers.getContractAt("Airdrop", airdropAddress);
            
            // Verificar configuración del airdrop
            expect(await airdrop.token()).to.equal(await testToken1.getAddress());
            expect(await airdrop.airdropAmount()).to.equal(ethers.parseEther("5"));
            
            const currentTime = (await ethers.provider.getBlock("latest")).timestamp;
            expect(await airdrop.registrationEndTime()).to.be.closeTo(
                currentTime + REGISTRATION_DURATION, 5
            );
            expect(await airdrop.claimStartTime()).to.be.closeTo(
                currentTime + REGISTRATION_DURATION + CLAIM_DELAY, 5
            );
        });

        it("Should allow multiple users to deploy airdrops", async function () {
            // Usuario 1 despliega un airdrop
            await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            // Usuario 2 despliega otro airdrop
            await airdropFactory.connect(user2).deployAirdrop(
                await testToken2.getAddress(),
                REGISTRATION_DURATION * 2,
                CLAIM_DELAY * 2,
                CLAIM_DURATION * 2,
                AIRDROP_NAME_2
            );

            expect(await airdropFactory.getTotalAirdrops()).to.equal(2);
        });

        it("Should allow same user to deploy multiple airdrops", async function () {
            // Usuario 1 despliega dos airdrops
            await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            await airdropFactory.connect(user1).deployAirdrop(
                await testToken2.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_2
            );

            const userAirdrops = await airdropFactory.getAirdropsByOwner(user1.address);
            expect(userAirdrops.length).to.equal(2);
            expect(await airdropFactory.getTotalAirdrops()).to.equal(2);
        });

        it("Should handle zero claim duration (unlimited)", async function () {
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                0, // Unlimited claim duration
                AIRDROP_NAME_1
            );

            const receipt = await tx.wait();
            const decodedEvent = airdropFactory.interface.parseLog(
                receipt.logs.find(log => 
                    log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
                )
            );

            const airdropAddress = decodedEvent.args.airdropContract;
            const airdrop = await ethers.getContractAt("Airdrop", airdropAddress);
            
            expect(await airdrop.claimEndTime()).to.equal(0);
        });
    });

    describe("Airdrop Information Retrieval", function () {
        let airdropAddress1, airdropAddress2;

        beforeEach(async function () {
            // Desplegar dos airdrops para testing
            const tx1 = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            const receipt1 = await tx1.wait();
            const event1 = airdropFactory.interface.parseLog(
                receipt1.logs.find(log => 
                    log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
                )
            );
            airdropAddress1 = event1.args.airdropContract;

            const tx2 = await airdropFactory.connect(user2).deployAirdrop(
                await testToken2.getAddress(),
                REGISTRATION_DURATION * 2,
                CLAIM_DELAY * 2,
                CLAIM_DURATION * 2,
                AIRDROP_NAME_2
            );

            const receipt2 = await tx2.wait();
            const event2 = airdropFactory.interface.parseLog(
                receipt2.logs.find(log => 
                    log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
                )
            );
            airdropAddress2 = event2.args.airdropContract;
        });

        it("Should return correct airdrop info by index", async function () {
            const airdropInfo = await airdropFactory.getAirdropInfo(0);
            
            expect(airdropInfo.airdropContract).to.equal(airdropAddress1);
            expect(airdropInfo.token).to.equal(await testToken1.getAddress());
            expect(airdropInfo.name).to.equal(AIRDROP_NAME_1);
            expect(airdropInfo.isActive).to.be.true;
            expect(airdropInfo.deploymentTime).to.be.greaterThan(0);
        });

        it("Should return airdrops by owner correctly", async function () {
            const user1Airdrops = await airdropFactory.getAirdropsByOwner(user1.address);
            const user2Airdrops = await airdropFactory.getAirdropsByOwner(user2.address);
            const user3Airdrops = await airdropFactory.getAirdropsByOwner(user3.address);

            expect(user1Airdrops.length).to.equal(1);
            expect(user1Airdrops[0]).to.equal(0); // Index of first airdrop

            expect(user2Airdrops.length).to.equal(1);
            expect(user2Airdrops[0]).to.equal(1); // Index of second airdrop

            expect(user3Airdrops.length).to.equal(0);
        });

        it("Should return correct total airdrops count", async function () {
            expect(await airdropFactory.getTotalAirdrops()).to.equal(2);
        });

        it("Should revert when accessing invalid airdrop index", async function () {
            await expect(airdropFactory.getAirdropInfo(999))
                .to.be.revertedWith("Invalid index");
        });
    });

    describe("Edge Cases and Error Handling", function () {
        it("Should handle invalid token address in airdrop deployment", async function () {
            await expect(
                airdropFactory.connect(user1).deployAirdrop(
                    ethers.ZeroAddress, // Invalid token address
                    REGISTRATION_DURATION,
                    CLAIM_DELAY,
                    CLAIM_DURATION,
                    AIRDROP_NAME_1
                )
            ).to.be.revertedWithCustomError(airdropFactory, "InvalidInput");
        });

        it("Should handle zero registration duration", async function () {
            await expect(
                airdropFactory.connect(user1).deployAirdrop(
                    await testToken1.getAddress(),
                    0, // Invalid registration duration
                    CLAIM_DELAY,
                    CLAIM_DURATION,
                    AIRDROP_NAME_1
                )
            ).to.be.revertedWith("Airdrop: Registration duration must be greater than zero");
        });

        it("Should handle empty airdrop name", async function () {
            // El factory ahora valida el nombre, por lo que debería fallar
            await expect(
                airdropFactory.connect(user1).deployAirdrop(
                    await testToken1.getAddress(),
                    REGISTRATION_DURATION,
                    CLAIM_DELAY,
                    CLAIM_DURATION,
                    "" // Empty name
                )
            ).to.be.revertedWithCustomError(airdropFactory, "InvalidInput");
        });

        it("Should handle very long airdrop name", async function () {
            const longName = "A".repeat(1000);
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                longName
            );

            expect(tx).to.not.be.reverted;
        });
    });

    describe("Integration with Deployed Airdrops", function () {
        let airdropAddress;
        let airdrop;

        beforeEach(async function () {
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            const receipt = await tx.wait();
            const event = airdropFactory.interface.parseLog(
                receipt.logs.find(log => 
                    log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
                )
            );
            airdropAddress = event.args.airdropContract;
            airdrop = await ethers.getContractAt("Airdrop", airdropAddress);
        });

        it("Should allow funding the deployed airdrop", async function () {
            const fundAmount = ethers.parseEther("1000");
            
            // Transfer tokens to user1 and approve airdrop
            await testToken1.transfer(user1.address, fundAmount);
            await testToken1.connect(user1).approve(airdropAddress, fundAmount);
            
            await expect(airdrop.connect(user1).fundContract(fundAmount))
                .to.emit(airdrop, "ContractFunded")
                .withArgs(user1.address, fundAmount);
        });

        it("Should allow user registration in deployed airdrop", async function () {
            await expect(airdrop.connect(user2).register())
                .to.emit(airdrop, "UserRegistered")
                .withArgs(user2.address, await ethers.provider.getBlock("latest").then(b => b.timestamp + 1));
        });

        it("Should handle complete airdrop lifecycle", async function () {
            // 1. Fund the airdrop
            const fundAmount = ethers.parseEther("1000");
            await testToken1.transfer(user1.address, fundAmount);
            await testToken1.connect(user1).approve(airdropAddress, fundAmount);
            await airdrop.connect(user1).fundContract(fundAmount);

            // 2. Users register
            await airdrop.connect(user2).register();
            await airdrop.connect(user3).register();

            // 3. Wait for claim period
            await advanceTime(REGISTRATION_DURATION + CLAIM_DELAY + 1);

            // 4. Users claim
            const initialBalance2 = await testToken1.balanceOf(user2.address);
            const initialBalance3 = await testToken1.balanceOf(user3.address);

            await airdrop.connect(user2).claim();
            await airdrop.connect(user3).claim();

            const finalBalance2 = await testToken1.balanceOf(user2.address);
            const finalBalance3 = await testToken1.balanceOf(user3.address);

            expect(finalBalance2 - initialBalance2).to.equal(ethers.parseEther("5"));
            expect(finalBalance3 - initialBalance3).to.equal(ethers.parseEther("5"));
        });

        it("Should maintain airdrop ownership after deployment", async function () {
            // Verificar que user1 es el owner del airdrop
            expect(await airdrop.owner()).to.equal(user1.address);
            
            // Solo user1 debería poder pausar el airdrop
            await expect(airdrop.connect(user1).pause()).to.not.be.reverted;
            await expect(airdrop.connect(user2).pause())
                .to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Gas Efficiency Tests", function () {
        it("Should deploy airdrops with reasonable gas costs", async function () {
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            const receipt = await tx.wait();
            
            // Gas limit check (should be less than 3M gas)
            expect(receipt.gasUsed).to.be.lessThan(3000000);
            console.log(`Gas used for airdrop deployment: ${receipt.gasUsed}`);
        });
    });

    describe("Multiple Airdrop Scenarios", function () {
        it("Should handle many airdrops from different users", async function () {
            const numAirdrops = 10;
            const users = [user1, user2, user3];
            
            for (let i = 0; i < numAirdrops; i++) {
                const user = users[i % users.length];
                await airdropFactory.connect(user).deployAirdrop(
                    await testToken1.getAddress(),
                    REGISTRATION_DURATION,
                    CLAIM_DELAY,
                    CLAIM_DURATION,
                    `Airdrop #${i}`
                );
            }

            expect(await airdropFactory.getTotalAirdrops()).to.equal(numAirdrops);
            
            // Verificar distribución por usuario
            expect((await airdropFactory.getAirdropsByOwner(user1.address)).length).to.equal(4);
            expect((await airdropFactory.getAirdropsByOwner(user2.address)).length).to.equal(3);
            expect((await airdropFactory.getAirdropsByOwner(user3.address)).length).to.equal(3);
        });

        it("Should track airdrop information correctly for multiple deployments", async function () {
            const airdrops = [
                { user: user1, token: testToken1, name: "Token1 Airdrop" },
                { user: user2, token: testToken2, name: "Token2 Airdrop" },
                { user: user1, token: testToken2, name: "User1 Token2 Airdrop" }
            ];

            for (let i = 0; i < airdrops.length; i++) {
                await airdropFactory.connect(airdrops[i].user).deployAirdrop(
                    await airdrops[i].token.getAddress(),
                    REGISTRATION_DURATION,
                    CLAIM_DELAY,
                    CLAIM_DURATION,
                    airdrops[i].name
                );

                const airdropInfo = await airdropFactory.getAirdropInfo(i);
                expect(airdropInfo.name).to.equal(airdrops[i].name);
                expect(airdropInfo.token).to.equal(await airdrops[i].token.getAddress());
            }
        });
    });

    describe("AirdropFactory Specific Tests", function () {
        let airdropAddress;

        beforeEach(async function () {
            // Desplegar un airdrop para pruebas específicas
            const tx = await airdropFactory.connect(user1).deployAirdrop(
                await testToken1.getAddress(),
                REGISTRATION_DURATION,
                CLAIM_DELAY,
                CLAIM_DURATION,
                AIRDROP_NAME_1
            );

            const receipt = await tx.wait();
            const event = airdropFactory.interface.parseLog(
                receipt.logs.find(log => 
                    log.topics[0] === airdropFactory.interface.getEvent("AirdropDeployed").topicHash
                )
            );
            airdropAddress = event.args.airdropContract;
        });

        it("Should allow owner to deactivate airdrop", async function () {
            await airdropFactory.deactivateAirdrop(0);
            
            const airdropInfo = await airdropFactory.getAirdropInfo(0);
            expect(airdropInfo.isActive).to.be.false;
        });

        it("Should not allow non-owner to deactivate airdrop", async function () {
            await expect(
                airdropFactory.connect(user2).deactivateAirdrop(0)
            ).to.be.revertedWithCustomError(airdropFactory, "Unauthorized");
        });

        it("Should revert deactivation with invalid index", async function () {
            await expect(
                airdropFactory.deactivateAirdrop(5)
            ).to.be.revertedWith("Invalid index");
        });

        it("Should return correct airdrop info by index", async function () {
            const airdropInfo = await airdropFactory.getAirdropInfo(0);
            
            expect(airdropInfo.airdropContract).to.equal(airdropAddress);
            expect(airdropInfo.token).to.equal(await testToken1.getAddress());
            expect(airdropInfo.name).to.equal(AIRDROP_NAME_1);
            expect(airdropInfo.isActive).to.be.true;
            expect(airdropInfo.deploymentTime).to.be.greaterThan(0);
        });
    });
});
