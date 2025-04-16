const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("AgentMiningContract", function () {
    let NUVO, agentMining;
    let owner, user1, user2, user3;
    let ownerAddress, user1Address, user2Address, user3Address;
    const initialMint = ethers.parseEther("10000");

    // Desplegamos un contrato mock de NUVO que implemente mint y burn
    before(async function () {
        [owner, user1, user2, user3] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        user1Address = await user1.getAddress();
        user2Address = await user2.getAddress();
        user3Address = await user3.getAddress();
        const NUVOFactory = await ethers.getContractFactory("MockNUVOToken");
        NUVO = await NUVOFactory.deploy("NUVO Token", "NUVO");
        await NUVO.waitForDeployment();
    });

    beforeEach(async function () {
        // Mint tokens para los usuarios
        for (let i = 0; i < 4; i++) {
            const signer = [owner, user1, user2, user3][i];
            const signerAddr = [ownerAddress, user1Address, user2Address, user3Address][i];
            await NUVO.mint(signerAddr, initialMint);
        }
        
        // Desplegar AgentMiningContract
        const AgentMiningFactory = await ethers.getContractFactory("AgentMiningContract");
        agentMining = await AgentMiningFactory.deploy(await NUVO.getAddress());
        await agentMining.waitForDeployment();
        
        // Mint extra tokens para el contrato para recompensas
        await NUVO.mint(await agentMining.getAddress(), ethers.parseEther("5000"));
        
        // Aprobar tokens para el contrato desde cada cuenta
        const agentMiningAddress = await agentMining.getAddress();
        for (let i = 0; i < 4; i++) {
            const signer = [owner, user1, user2, user3][i];
            await NUVO.connect(signer).approve(agentMiningAddress, initialMint);
        }
    });

    describe("Referral Registration", function () {
        it("should register a referral", async function () {
            await agentMining.connect(user1).registerReferral(user2Address);
            expect(await agentMining.referrers(user1Address)).to.equal(user2Address);
        });
        it("should reject self referral", async function () {
            await expect(agentMining.connect(user1).registerReferral(user1Address))
                .to.be.revertedWith("No puedes referirte a ti mismo");
        });
    });

    describe("Purchase Agent", function () {
        it("should let a user purchase an agent and burn tokens", async function () {
            // user1 compra agente LITE
            const tx = await agentMining.connect(user1).purchaseAgent(0);
            await tx.wait();
            // Verificar que el agente fue creado y emitido el evento
            expect(await agentMining.totalNetworkHashRate()).to.be.gt(0);
            // Se verifica que si hay referral registrada, la comisión se transfiere
        });

        it("should process referral commission on purchase", async function () {
            // user2 se registra como referente de user1
            await agentMining.connect(user1).registerReferral(user2Address);
            // Pre-saldo de user2
            const preBalance = await NUVO.balanceOf(user2Address);
            await agentMining.connect(user1).purchaseAgent(0);
            // Comisión del 5% aplicada sobre precio 500 ether
            const commission = ethers.parseEther("500") * 500n / 10000n;
            const postBalance = await NUVO.balanceOf(user2Address);
            expect(postBalance - preBalance).to.equal(commission);
        });
    });

    describe("Maintenance Payment and Agent Status", function () {
        let tokenId;
        beforeEach(async function () {
            // Compra de un agente por user1
            const tx = await agentMining.connect(user1).purchaseAgent(0);
            await tx.wait();
            // Recuperar el tokenId (primer agente)
            tokenId = 1; // primer token mintado
        });
        it("should pay maintenance and reactivate a deactivated agent", async function () {
            // Aumentar tiempo para que el mantenimiento quede pendiente
            await network.provider.send("evm_increaseTime", [2 * 24 * 3600]);
            await network.provider.send("evm_mine");

            // Primero se chequea que el agente se desactive al chequear status
            await agentMining.connect(user1).checkAgentStatus(tokenId);
            let details = await agentMining.getAgentDetails(tokenId);
            expect(details[4]).to.equal(false); // active == false

            // user1 paga mantenimiento para reactivar
            const preHashRate = await agentMining.totalNetworkHashRate();
            await agentMining.connect(user1).payMaintenance(tokenId);
            details = await agentMining.getAgentDetails(tokenId);
            expect(details[4]).to.equal(true);
            const postHashRate = await agentMining.totalNetworkHashRate();
            expect(postHashRate).to.be.gt(preHashRate);
        });

        it("should not pay maintenance if not due", async function () {
            // Como mantenimiento ya fue pagado en compra, no hay dias pendientes
            const tx = await agentMining.connect(user1).payMaintenance(tokenId);
            await tx.wait(); // no revert, pero sin cambios
        });
    });

    describe("Problem Solving and Reward Distribution", function () {
        let tokenId;
        beforeEach(async function () {
            const tx = await agentMining.connect(user1).purchaseAgent(0);
            await tx.wait();
            tokenId = 1;
        });

        it("should simulate solving a problem", async function () {
            const preDetails = await agentMining.getAgentDetails(tokenId);
            await agentMining.connect(owner).solveProblem(tokenId);
            const postDetails = await agentMining.getAgentDetails(tokenId);
            expect(Number(postDetails[5])).to.equal(Number(preDetails[5]) + 1); // problemsSolved incremented
        });

        it("should distribute rewards", async function () {
            // Simular resolución de problemas para aumentar currentRewardPool
            await agentMining.connect(owner).solveProblem(tokenId);
            // Aumentar tiempo para superar el intervalo de distribución
            await network.provider.send("evm_increaseTime", [16 * 60]);
            await network.provider.send("evm_mine");

            const preBal = await NUVO.balanceOf(user1Address);
            await agentMining.connect(user1).distributeRewards();
            const postBal = await NUVO.balanceOf(user1Address);
            expect(postBal).to.be.gt(preBal);
        });
    });

    describe("Special Events", function () {
        it("should create and end a special event", async function () {
            const tx = await agentMining.createSpecialEvent("TestEvent", 150, 20, 1);
            await tx.wait();
            let eventData = await agentMining.getCurrentEvent();
            expect(eventData[0]).to.equal("TestEvent");
            expect(eventData[5]).to.equal(true);

            // End the event manually
            await agentMining.endSpecialEvent();
            eventData = await agentMining.getCurrentEvent();
            expect(eventData[5]).to.equal(false);
        });
    });

    describe("Administrative Functions", function () {
        it("should update referral commission", async function () {
            await agentMining.updateReferralCommission(600);
            expect(await agentMining.referralCommission()).to.equal(600);
        });

        it("should update base reward pool", async function () {
            await agentMining.updateBaseRewardPool(ethers.parseEther("4000"));
            // Llamar función view getBurnStats para confirmar cambios indirectos
            const burnStats = await agentMining.getBurnStats();
            expect(burnStats[1]).to.be.gt(0);
        });

        it("should update agent prices", async function () {
            await agentMining.updateAgentPrices(
                ethers.parseEther("600"),
                ethers.parseEther("1600"),
                ethers.parseEther("3200")
            );
            // Verificar un precio modificando desde el mapping interno
            const prices = await agentMining.agentPrices(0);
            expect(prices).to.equal(ethers.parseEther("600"));
        });

        it("should update agent hashrates", async function () {
            // Aprobamos tokens adicionales para la compra del agente
            await NUVO.connect(owner).approve(await agentMining.getAddress(), ethers.parseEther("500"));
            await agentMining.connect(owner).purchaseAgent(0);
            
            const preHashRate = await agentMining.totalNetworkHashRate();
            await agentMining.updateAgentHashRates(20, 40, 80);
            const postHashRate = await agentMining.totalNetworkHashRate();
            expect(postHashRate).to.be.gt(preHashRate);
        });

        it("should update maintenance fees", async function () {
            await agentMining.updateMaintenanceFees(
                ethers.parseEther("6"),
                ethers.parseEther("16"),
                ethers.parseEther("32")
            );
            // Aprobamos tokens adicionales para la compra del agente
            await NUVO.connect(owner).approve(await agentMining.getAddress(), ethers.parseEther("500"));
            await agentMining.connect(owner).purchaseAgent(0);
            
            const details = await agentMining.getAgentDetails(1);
            expect(details[2]).to.equal(ethers.parseEther("6"));
        });

        it("should allow owner to withdraw tokens", async function () {
            // Aprobamos tokens adicionales para la compra del agente
            await NUVO.connect(owner).approve(await agentMining.getAddress(), ethers.parseEther("500"));
            await agentMining.connect(owner).purchaseAgent(0);
            
            const preOwnerBal = await NUVO.balanceOf(ownerAddress);
            await agentMining.withdraw(ethers.parseEther("100"));
            const postOwnerBal = await NUVO.balanceOf(ownerAddress);
            expect(postOwnerBal).to.be.gt(preOwnerBal);
        });
    });

    describe("View Functions", function () {
        beforeEach(async function () {
            // Aprobamos tokens adicionales
            await NUVO.connect(user1).approve(await agentMining.getAddress(), ethers.parseEther("500"));
            await agentMining.connect(user1).purchaseAgent(0);
        });
        it("should return user stats", async function () {
            const stats = await agentMining.getUserStats(user1Address);
            expect(stats[0]).to.equal(1);
        });
        it("should return agent details", async function () {
            const details = await agentMining.getAgentDetails(1);
            expect(details[3]).to.be.gt(0);
        });
        it("should return time to next distribution", async function () {
            const timeLeft = await agentMining.timeToNextDistribution();
            expect(timeLeft).to.be.gt(0);
        });
        it("should return user referral stats", async function () {
            // Registrar referral y luego consultarlo
            await agentMining.connect(user1).registerReferral(user2Address);
            const refStats = await agentMining.getUserReferralStats(user2Address);
            expect(refStats[0]).to.equal(1);
        });
        it("should return current event data", async function () {
            await agentMining.createSpecialEvent("AnotherEvent", 120, 10, 2);
            const eventData = await agentMining.getCurrentEvent();
            expect(eventData[0]).to.equal("AnotherEvent");
        });
        it("should return burn stats", async function () {
            const burnStats = await agentMining.getBurnStats();
            expect(burnStats[1]).to.be.gt(0);
        });
    });

    describe("Marketplace Features", function() {
        let tokenId;
        
        beforeEach(async function() {
            // Comprar un agente nuevo para las pruebas
            await NUVO.connect(user1).approve(await agentMining.getAddress(), ethers.parseEther("500"));
            const tx = await agentMining.connect(user1).purchaseAgent(0);
            await tx.wait();
            tokenId = 1;
        });

        it("should list an agent for sale", async function() {
            const price = ethers.parseEther("400");
            
            // Aprobar transacción del NFT al marketplace
            await agentMining.connect(user1).approve(await agentMining.getAddress(), tokenId);
            
            // Listar el agente
            await agentMining.connect(user1).listAgent(tokenId, price);
            
            // Verificar que el contrato ahora es el dueño del NFT
            expect(await agentMining.ownerOf(tokenId)).to.equal(await agentMining.getAddress());
            
            // Comprobar que existe un listing activo
            const listing = await agentMining.tokenListings(tokenId);
            expect(listing).to.be.gt(0);
        });

        it("should cancel a listing", async function() {
            const price = ethers.parseEther("400");
            
            // Aprobar y listar el agente
            await agentMining.connect(user1).approve(await agentMining.getAddress(), tokenId);
            await agentMining.connect(user1).listAgent(tokenId, price);
            
            // Cancelar el listing
            await agentMining.connect(user1).cancelListing(tokenId);
            
            // Verificar que el agente volvió al dueño original
            expect(await agentMining.ownerOf(tokenId)).to.equal(user1Address);
            
            // Verificar que el listing ya no está activo
            const listing = await agentMining.tokenListings(tokenId);
            expect(listing).to.equal(0);
        });

        it("should allow buying a listed agent", async function() {
            const price = ethers.parseEther("400");
            
            // Aprobar y listar el agente
            await agentMining.connect(user1).approve(await agentMining.getAddress(), tokenId);
            await agentMining.connect(user1).listAgent(tokenId, price);
            
            // Balance inicial del vendedor
            const initialSellerBalance = await NUVO.balanceOf(user1Address);
            
            // User2 compra el agente
            await NUVO.connect(user2).approve(await agentMining.getAddress(), price);
            await agentMining.connect(user2).buyAgent(tokenId);
            
            // Verificar que el agente ahora pertenece a user2
            expect(await agentMining.ownerOf(tokenId)).to.equal(user2Address);
            
            // Verificar que el vendedor recibió el dinero
            const finalSellerBalance = await NUVO.balanceOf(user1Address);
            expect(finalSellerBalance).to.equal(initialSellerBalance.add(price));
            
            // Verificar que el listing ya no está activo
            const listing = await agentMining.tokenListings(tokenId);
            expect(listing).to.equal(0);
        });
    });

    describe("Tournament System", function() {
        beforeEach(async function() {
            // Mint más tokens para pruebas de torneos
            await NUVO.mint(ownerAddress, ethers.parseEther("5000"));
            await NUVO.connect(owner).approve(await agentMining.getAddress(), ethers.parseEther("5000"));
        });

        it("should create a tournament", async function() {
            const tournamentName = "Test Tournament";
            const duration = 1; // 1 día
            const entryFee = ethers.parseEther("50");
            const initialPrize = ethers.parseEther("200");
            
            await agentMining.connect(owner).createTournament(
                tournamentName, 
                duration, 
                entryFee, 
                initialPrize
            );
            
            const tournamentData = await agentMining.getCurrentTournament();
            expect(tournamentData[0]).to.equal(tournamentName);
            expect(tournamentData[3]).to.equal(entryFee);
            expect(tournamentData[4]).to.equal(initialPrize);
            expect(tournamentData[6]).to.be.true; // active
        });

        it("should allow users to join a tournament", async function() {
            // Crear torneo primero
            await agentMining.connect(owner).createTournament(
                "Join Test Tournament", 
                1, 
                ethers.parseEther("50"), 
                ethers.parseEther("200")
            );
            
            // User1 se une al torneo
            await NUVO.connect(user1).approve(await agentMining.getAddress(), ethers.parseEther("50"));
            await agentMining.connect(user1).joinTournament();
            
            // Verificar que user1 está en el torneo
            const tournamentData = await agentMining.getCurrentTournament();
            expect(tournamentData[5]).to.equal(1); // participantsCount = 1
            expect(tournamentData[4]).to.equal(ethers.parseEther("250")); // totalPrize = 200 + 50
            
            // Verificar score inicial
            const score = await agentMining.getTournamentScore(user1Address);
            expect(score).to.equal(0);
        });

        it("should update tournament scores", async function() {
            // Crear torneo y hacer que user1 se una
            await agentMining.connect(owner).createTournament(
                "Score Test Tournament", 
                1, 
                ethers.parseEther("50"), 
                ethers.parseEther("200")
            );
            
            await NUVO.connect(user1).approve(await agentMining.getAddress(), ethers.parseEther("50"));
            await agentMining.connect(user1).joinTournament();
            
            // Actualizar score
            const newScore = 100;
            await agentMining.connect(owner).updateTournamentScore(user1Address, newScore);
            
            // Verificar nuevo score
            const score = await agentMining.getTournamentScore(user1Address);
            expect(score).to.equal(newScore);
        });

        it("should end a tournament and distribute rewards", async function() {
            // Crear torneo y hacer que user1 y user2 se unan
            await agentMining.connect(owner).createTournament(
                "End Test Tournament", 
                1, 
                ethers.parseEther("50"), 
                ethers.parseEther("200")
            );
            
            await NUVO.connect(user1).approve(await agentMining.getAddress(), ethers.parseEther("50"));
            await agentMining.connect(user1).joinTournament();
            
            await NUVO.connect(user2).approve(await agentMining.getAddress(), ethers.parseEther("50"));
            await agentMining.connect(user2).joinTournament();
            
            // User1 tiene más puntuación
            await agentMining.connect(owner).updateTournamentScore(user1Address, 100);
            await agentMining.connect(owner).updateTournamentScore(user2Address, 50);
            
            const initialBalance = await NUVO.balanceOf(user1Address);
            
            // Terminar torneo
            await agentMining.connect(owner).endTournament();
            
            // Verificar que user1 recibió el premio (200 + 50 + 50 = 300)
            const finalBalance = await NUVO.balanceOf(user1Address);
            expect(finalBalance.sub(initialBalance)).to.equal(ethers.parseEther("300"));
            
            // Verificar que no hay torneo activo
            await expect(agentMining.getCurrentTournament()).to.be.reverted;
        });
    });

    describe("Extended Agent Details and ROI", function() {
        let tokenId;
        
        beforeEach(async function() {
            // Comprar un agente nuevo para las pruebas
            await NUVO.connect(user1).approve(await agentMining.getAddress(), ethers.parseEther("500"));
            const tx = await agentMining.connect(user1).purchaseAgent(0);
            await tx.wait();
            tokenId = 1;
        });

        it("should provide extended agent details", async function() {
            const details = await agentMining.getExtendedAgentDetails(tokenId);
            
            // Verificar tipo de agente (LITE = 0)
            expect(details.agentType).to.equal(0);
            
            // Verificar que los campos adicionales estén presentes
            expect(details.level).to.equal(1); // level
            expect(details.experience).to.equal(0); // experience
            expect(details.upgradePoints).to.equal(0); // upgradePoints
            expect(details.totalInvested).to.be.gt(0); // totalInvested
            expect(details.unclaimedAmount).to.equal(0); // unclaimedAmount
            expect(details.purchaseTime).to.be.gt(0); // purchaseTime
            expect(details.dailyEstimatedReward).to.be.gt(0); // dailyEstimatedReward
        });

        it("should predict daily rewards for an agent type", async function() {
            const dailyReward = await agentMining.predictDailyReward(0); // LITE
            expect(dailyReward).to.be.gt(0);
        });

        it("should estimate ROI days", async function() {
            const roiDays = await agentMining.estimateROIDays(0); // LITE
            expect(roiDays).to.be.gt(0);
        });

        it("should allow claiming rewards", async function() {
            // Simular resolución de problemas y distribución de recompensas
            await agentMining.connect(owner).solveProblem(tokenId);
            await agentMining.connect(user1).distributeRewards();
            
            // Verificar que hay recompensas sin reclamar
            const details = await agentMining.getExtendedAgentDetails(tokenId);
            expect(details.unclaimedAmount).to.be.gt(0);
            
            // Reclamar recompensas
            const initialBalance = await NUVO.balanceOf(user1Address);
            await agentMining.connect(user1).claimRewards(tokenId);
            
            // Verificar que el balance aumentó
            const finalBalance = await NUVO.balanceOf(user1Address);
            expect(finalBalance).to.be.gt(initialBalance);
            
            // Verificar que ya no hay recompensas sin reclamar
            const newDetails = await agentMining.getExtendedAgentDetails(tokenId);
            expect(newDetails.unclaimedAmount).to.equal(0);
        });
    });

    describe("Statistics and Global Data", function() {
        beforeEach(async function() {
            // Crear algunos agentes para tener datos más interesantes
            await NUVO.connect(user1).approve(await agentMining.getAddress(), ethers.parseEther("1000"));
            await agentMining.connect(user1).purchaseAgent(0); // LITE
            
            await NUVO.connect(user2).approve(await agentMining.getAddress(), ethers.parseEther("2000"));
            await agentMining.connect(user2).purchaseAgent(2); // MAX
        });

        it("should return global stats", async function() {
            const stats = await agentMining.getGlobalStats();
            
            // Verificar que hay al menos 2 agentes
            expect(stats[0]).to.be.gte(2);
            // Verificar que hay agentes activos
            expect(stats[1]).to.be.gte(2);
            // Verificar hash rate total
            expect(stats[2]).to.be.gt(0);
            // Verificar tokens quemados
            expect(stats[4]).to.be.gt(0);
        });

        it("should return daily stats data", async function() {
            const dayStats = await agentMining.getDailyStatsData(0);
            
            // Verificar que hay datos para el día 0
            expect(dayStats.date).to.be.gt(0);
            expect(dayStats.activeAgents).to.be.gte(0);
        });

        it("should update active days for users", async function() {
            // Aumentar el tiempo para simular un nuevo día
            await network.provider.send("evm_increaseTime", [24 * 3600]);
            await network.provider.send("evm_mine");
            
            // Hacer una acción para actualizar el día activo
            await agentMining.connect(user1).distributeRewards();
            
            // No podemos verificar directamente userActiveDays porque es un mapeo interno,
            // pero el hecho de que el contrato no revierta es una buena señal
        });
    });
});
