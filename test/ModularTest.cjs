const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GameifiedMarketplace Modularized", function () {
    let NUVO, factory, coreContract, marketplaceContract, tournamentContract;
    let owner, user1, user2, user3;
    let ownerAddress, user1Address, user2Address, user3Address;
    const initialMint = ethers.parseEther("10000");

    // Deploy mock NUVO token
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
        // Mint tokens for users
        for (let i = 0; i < 4; i++) {
            const signer = [owner, user1, user2, user3][i];
            const signerAddr = [ownerAddress, user1Address, user2Address, user3Address][i];
            await NUVO.mint(signerAddr, initialMint);
        }
        
        // Deploy contracts directly
        const AgentMiningSimple = await ethers.getContractFactory("AgentMiningSimple");
        coreContract = await AgentMiningSimple.deploy(await NUVO.getAddress());
        await coreContract.waitForDeployment();
        
        const MarketplaceFactory = await ethers.getContractFactory("AgentMarketplace");
        marketplaceContract = await MarketplaceFactory.deploy(
            await coreContract.getAddress(),
            await NUVO.getAddress()
        );
        await marketplaceContract.waitForDeployment();
        
        const TournamentFactory = await ethers.getContractFactory("TournamentSystem");
        tournamentContract = await TournamentFactory.deploy(await NUVO.getAddress());
        await tournamentContract.waitForDeployment();
        
        // Deploy factory (just for registry)
        const FactoryFactory = await ethers.getContractFactory("AgentMiningFactory");
        factory = await FactoryFactory.deploy(await NUVO.getAddress());
        await factory.waitForDeployment();
        
        // Register contracts in the factory
        await factory.registerCoreContract(await coreContract.getAddress());
        await factory.registerMarketplace(await marketplaceContract.getAddress());
        await factory.registerTournament(await tournamentContract.getAddress());
        
        // Mint extra tokens for the core contract
        await NUVO.mint(await coreContract.getAddress(), ethers.parseEther("5000"));
        
        // Approve tokens for each account
        const coreAddress = await coreContract.getAddress();
        for (let i = 0; i < 4; i++) {
            const signer = [owner, user1, user2, user3][i];
            await NUVO.connect(signer).approve(coreAddress, initialMint);
        }
    });

    describe("Core Contract Functions", function () {
        it("should register a referral", async function () {
            await coreContract.connect(user1).registerReferral(user2Address);
            expect(await coreContract.referrers(user1Address)).to.equal(user2Address);
        });

        it("should reject self-referral", async function() {
            await expect(coreContract.connect(user1).registerReferral(user1Address))
                .to.be.revertedWith("No puedes referirte a ti mismo");
        });
        
        it("should allow purchasing an agent", async function () {
            const tx = await coreContract.connect(user1).purchaseAgent(0);
            await tx.wait();
            expect(await coreContract.totalNetworkHashRate()).to.be.gt(0);

            // Verify agent ownership
            const ownerOfToken = await coreContract.ownerOf(1);
            expect(ownerOfToken).to.equal(user1Address);
            
            // Verify agent details
            const agentDetails = await coreContract.getAgentDetails(1);
            expect(agentDetails.agentType).to.equal(0); // LITE agent
            expect(agentDetails.active).to.equal(true);
        });
        
        it("should process referral commission", async function () {
            await coreContract.connect(user1).registerReferral(user2Address);
            const preBalance = await NUVO.balanceOf(user2Address);
            await coreContract.connect(user1).purchaseAgent(0);
            const commission = ethers.parseEther("300") * 500n / 10000n; // 5% of 300
            const postBalance = await NUVO.balanceOf(user2Address);
            expect(postBalance - preBalance).to.equal(commission);
        });

        it("should burn tokens on purchase", async function() {
            const preBalance = await NUVO.balanceOf(await coreContract.getAddress());
            const preBurned = await coreContract.burnedTokens();
            
            await coreContract.connect(user1).purchaseAgent(0);
            
            const postBalance = await NUVO.balanceOf(await coreContract.getAddress());
            const postBurned = await coreContract.burnedTokens();
            
            // 10% of purchase price should be burned
            const expectedBurn = ethers.parseEther("300") * 10n / 100n; // 10% of 300
            expect(postBurned - preBurned).to.equal(expectedBurn);
        });

        describe("Maintenance and Agent Status", function() {
            let tokenId;
            
            beforeEach(async function() {
                // User1 purchases an agent
                await coreContract.connect(user1).purchaseAgent(0); // LITE Agent
                tokenId = 1; // First token
            });
            
            it("should deactivate agent if maintenance is overdue", async function() {
                // Increase time by 2 days to make maintenance overdue
                await network.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]);
                await network.provider.send("evm_mine");
                
                // Check that agent is deactivated - perform the check and then verify status
                await coreContract.checkAgentStatus(tokenId);
                
                // Now get the agent details to verify it's inactive
                const agentDetails = await coreContract.getAgentDetails(tokenId);
                expect(agentDetails[4]).to.be.false; // active field is at index 4
            });
            
            it("should reactivate agent when maintenance is paid", async function() {
                // Increase time by 2 days to make maintenance overdue
                await network.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]);
                await network.provider.send("evm_mine");
                
                // Check status first to deactivate
                await coreContract.checkAgentStatus(tokenId);
                
                // Pay maintenance
                await coreContract.connect(user1).payMaintenance(tokenId);
                
                // Verify agent is reactivated
                const agentDetails = await coreContract.getAgentDetails(tokenId);
                expect(agentDetails.active).to.be.true;
            });
        });

        describe("Problem Solving and Rewards", function() {
            let tokenId;
            
            beforeEach(async function() {
                await coreContract.connect(user1).purchaseAgent(0); // LITE Agent
                tokenId = 1;
            });
            
            it("should solve a problem and increment problem count", async function() {
                const beforeDetails = await coreContract.getAgentDetails(tokenId);
                await coreContract.connect(owner).solveProblem(tokenId);
                const afterDetails = await coreContract.getAgentDetails(tokenId);
                
                expect(Number(afterDetails.problemsSolved)).to.equal(Number(beforeDetails.problemsSolved) + 1);
            });
            
            it("should distribute rewards based on hashrate", async function() {
                // Solve a problem to increase reward pool
                await coreContract.connect(owner).solveProblem(tokenId);
                
                // Increase time to exceed the minimum distribution interval (15 min)
                await network.provider.send("evm_increaseTime", [16 * 60]);
                await network.provider.send("evm_mine");
                
                // Distribute rewards
                await coreContract.connect(user1).distributeRewards();
                
                // Check unclaimed rewards
                const agentDetails = await coreContract.getAgentDetails(tokenId);
                const unclaimedAmount = await coreContract.unclaimedRewards(tokenId);
                
                expect(unclaimedAmount).to.be.gt(0);
                expect(agentDetails[6]).to.be.gt(0); // totalEarned is at index 6
            });
            
            it("should allow claiming rewards", async function() {
                // Solve a problem and distribute rewards
                await coreContract.connect(owner).solveProblem(tokenId);
                
                // Increase time to exceed the minimum distribution interval
                await network.provider.send("evm_increaseTime", [16 * 60]);
                await network.provider.send("evm_mine");
                
                await coreContract.connect(user1).distributeRewards();
                
                // Check initial balances
                const initialBalance = await NUVO.balanceOf(user1Address);
                const initialUnclaimed = await coreContract.unclaimedRewards(tokenId);
                expect(initialUnclaimed).to.be.gt(0);
                
                // Claim rewards
                await coreContract.connect(user1).claimRewards(tokenId);
                
                // Verify balances after claiming
                const finalBalance = await NUVO.balanceOf(user1Address);
                const finalUnclaimed = await coreContract.unclaimedRewards(tokenId);
                
                expect(finalUnclaimed).to.equal(0);
                expect(finalBalance).to.be.gt(initialBalance);
            });

            it("should take a commission on reward claims", async function() {
                // Solve a problem and distribute rewards
                await coreContract.connect(owner).solveProblem(tokenId);
                
                // Increase time to exceed the minimum distribution interval
                await network.provider.send("evm_increaseTime", [16 * 60]);
                await network.provider.send("evm_mine");
                
                await coreContract.connect(user1).distributeRewards();
                
                const initialUnclaimed = await coreContract.unclaimedRewards(tokenId);
                const initialOwnerBalance = await NUVO.balanceOf(ownerAddress);
                
                // Claim rewards
                await coreContract.connect(user1).claimRewards(tokenId);
                
                // Verify owner received commission
                const finalOwnerBalance = await NUVO.balanceOf(ownerAddress);
                const commission = initialUnclaimed * 2000n / 10000n; // 20%
                
                expect(finalOwnerBalance - initialOwnerBalance).to.equal(commission);
            });
        });
        
        describe("View Functions", function() {
            beforeEach(async function() {
                // User1 purchases an agent
                await coreContract.connect(user1).purchaseAgent(0); // LITE
                // User2 purchases a different agent
                await coreContract.connect(user2).purchaseAgent(2); // MAX
                
                // Generate more substantial network activity
                // Solve multiple problems to increase rewards
                for (let i = 0; i < 5; i++) {
                    await coreContract.connect(owner).solveProblem(1); // LITE agent
                    await coreContract.connect(owner).solveProblem(2); // MAX agent
                }
                
                // Advance time and distribute rewards
                await network.provider.send("evm_increaseTime", [16 * 60]);
                await network.provider.send("evm_mine");
                await coreContract.connect(owner).distributeRewards();
                
                // Wait and solve more problems to establish a pattern
                await network.provider.send("evm_increaseTime", [16 * 60]);
                await network.provider.send("evm_mine");
                for (let i = 0; i < 5; i++) {
                    await coreContract.connect(owner).solveProblem(1);
                    await coreContract.connect(owner).solveProblem(2);
                }
                await coreContract.connect(owner).distributeRewards();
            });
            
            it("should return user stats", async function() {
                const stats = await coreContract.getUserStats(user1Address);
                expect(stats.totalAgents).to.equal(1);
                expect(stats.activeAgents).to.equal(1);
                expect(stats.totalHashRate).to.be.gt(0);
            });
            
            it("should return agent details", async function() {
                const details = await coreContract.getAgentDetails(1);
                expect(details.agentType).to.equal(0); // LITE
                expect(details.hashRate).to.equal(10); // Default hashrate for LITE
            });
            
            it("should predict daily rewards", async function() {
                const dailyReward = await coreContract.predictDailyReward(0); // LITE
                expect(dailyReward).to.be.gt(0);
            });
            
            it("should estimate ROI days", async function() {
                // Now that we have substantial network activity, ROI calculation should work
                
                // For testing purposes, let's check both price, reward data and ROI
                const agentType = 0; // LITE
                
                // Get current price and reward data
                const price = await coreContract.agentPrices(agentType);
                const dailyReward = await coreContract.predictDailyReward(agentType);
                console.log("Daily reward:", ethers.formatEther(dailyReward), "NUVO");
                
                // Check if calculable (reward > maintenance)
                const maintenanceFee = await coreContract.agentMaintenanceFees(agentType);
                console.log("Maintenance fee:", ethers.formatEther(maintenanceFee), "NUVO");
                console.log("Agent price:", ethers.formatEther(price), "NUVO");
                
                // Calculate net daily profit
                const netDailyProfit = dailyReward - maintenanceFee;
                console.log("Net daily profit:", ethers.formatEther(netDailyProfit), "NUVO");
                
                // Calculate manual ROI days
                const manualROIDays = price / netDailyProfit;
                console.log("Manual ROI calculation:", manualROIDays.toString());
                
                // Log the estimated ROI days from contract
                const roiDays = await coreContract.estimateROIDays(agentType);
                console.log("Contract estimated ROI days:", roiDays.toString());
                
                // Our test should allow for ROI of 0 days if the profit is extremely high
                if (dailyReward <= maintenanceFee) {
                    // If maintenance is higher than rewards, ROI is impossible
                    console.log("Daily reward is less than maintenance - ROI is impossible");
                    expect(dailyReward).to.be.gt(0); // Just ensure rewards are calculated
                } else if (netDailyProfit > price) {
                    // If net daily profit exceeds the price, ROI can be achieved in less than a day (0 days)
                    console.log("Net daily profit exceeds price - ROI achievable in less than a day");
                    expect(roiDays).to.equal(0);
                } else {
                    // Normal case - we should have a valid ROI calculation greater than 0
                    expect(roiDays).to.be.gt(0);
                }
            });
        });
    });
    
    describe("Marketplace Functions", function () {
        let tokenId;
        
        beforeEach(async function() {
            // Purchase an agent for marketplace tests
            await coreContract.connect(user1).purchaseAgent(0);
            tokenId = 1; // First token minted
            
            // Approve the marketplace to transfer the token
            await coreContract.connect(user1).approve(await marketplaceContract.getAddress(), tokenId);
        });
        
        it("should list an agent for sale", async function() {
            // List the agent
            const price = ethers.parseEther("500");
            await marketplaceContract.connect(user1).listAgent(tokenId, price);
            
            // Verify listing
            const listingId = 1; // First listing
            const listing = await marketplaceContract.getListingDetails(listingId);
            
            expect(listing.tokenId).to.equal(tokenId);
            expect(listing.price).to.equal(price);
            expect(listing.seller).to.equal(user1Address);
            expect(listing.active).to.be.true;
            
            // Verify token ownership transferred to marketplace
            expect(await coreContract.ownerOf(tokenId)).to.equal(await marketplaceContract.getAddress());
        });

        it("should cancel a listing", async function() {
            // First list the agent
            const price = ethers.parseEther("500");
            await marketplaceContract.connect(user1).listAgent(tokenId, price);
            
            // Then cancel the listing
            await marketplaceContract.connect(user1).cancelListing(tokenId);
            
            // Verify token returned to seller
            expect(await coreContract.ownerOf(tokenId)).to.equal(user1Address);
            
            // Verify listing inactive
            const listingId = 1; // First listing
            const listing = await marketplaceContract.getListingDetails(listingId);
            expect(listing.active).to.be.false;
        });

        it("should allow buying a listed agent", async function() {
            // List the agent
            const price = ethers.parseEther("500");
            await marketplaceContract.connect(user1).listAgent(tokenId, price);
            
            // Approve tokens for buyer
            await NUVO.connect(user2).approve(
                await marketplaceContract.getAddress(), 
                price
            );
            
            // Initial balances
            const initialSellerBalance = await NUVO.balanceOf(user1Address);
            
            // User2 buys the agent
            await marketplaceContract.connect(user2).buyAgent(tokenId);
            
            // Verify ownership transferred to buyer
            expect(await coreContract.ownerOf(tokenId)).to.equal(user2Address);
            
            // Verify seller received payment
            const finalSellerBalance = await NUVO.balanceOf(user1Address);
            expect(finalSellerBalance - initialSellerBalance).to.equal(price);
        });
    });

    describe("Tournament System", function() {
        beforeEach(async function() {
            // Owner needs to approve tokens for tournament creation
            await NUVO.connect(owner).approve(
                await tournamentContract.getAddress(),
                ethers.parseEther("1000")
            );
        });
        
        it("should create a tournament", async function() {
            // Create tournament
            await tournamentContract.connect(owner).createTournament(
                "Test Tournament",
                7, // duration in days
                ethers.parseEther("50"), // entry fee
                ethers.parseEther("200") // initial prize
            );
            
            // Verify tournament created successfully
            const tournamentData = await tournamentContract.getCurrentTournament();
            
            expect(tournamentData.name).to.equal("Test Tournament");
            expect(tournamentData.entryFee).to.equal(ethers.parseEther("50"));
            expect(tournamentData.totalPrize).to.equal(ethers.parseEther("200"));
            expect(tournamentData.active).to.be.true;
        });
        
        it("should allow users to join a tournament", async function() {
            // Create tournament
            await tournamentContract.connect(owner).createTournament(
                "Join Tournament Test",
                7,
                ethers.parseEther("50"),
                ethers.parseEther("200")
            );
            
            // User1 joins tournament
            await NUVO.connect(user1).approve(
                await tournamentContract.getAddress(),
                ethers.parseEther("50")
            );
            await tournamentContract.connect(user1).joinTournament();
            
            // Verify user joined
            const tournamentData = await tournamentContract.getCurrentTournament();
            expect(tournamentData.participantsCount).to.equal(1);
            
            // Verify prize increased by entry fee
            expect(tournamentData.totalPrize).to.equal(ethers.parseEther("250")); // 200 + 50
            
            // Verify initial score
            const score = await tournamentContract.getTournamentScore(user1Address);
            expect(score).to.equal(0);
        });
        
        it("should update tournament scores", async function() {
            // Create tournament
            await tournamentContract.connect(owner).createTournament(
                "Score Tournament Test",
                7,
                ethers.parseEther("50"),
                ethers.parseEther("200")
            );
            
            // User1 joins tournament
            await NUVO.connect(user1).approve(
                await tournamentContract.getAddress(),
                ethers.parseEther("50")
            );
            await tournamentContract.connect(user1).joinTournament();
            
            // Update score
            const newScore = 100;
            await tournamentContract.connect(owner).updateTournamentScore(user1Address, newScore);
            
            // Verify score updated
            const score = await tournamentContract.getTournamentScore(user1Address);
            expect(score).to.equal(newScore);
        });
        
        it("should end tournament and distribute prize to winner", async function() {
            // Create tournament
            await tournamentContract.connect(owner).createTournament(
                "End Tournament Test",
                1, // 1 day duration
                ethers.parseEther("50"),
                ethers.parseEther("200")
            );
            
            // Users join tournament
            for (const user of [user1, user2]) {
                await NUVO.connect(user).approve(
                    await tournamentContract.getAddress(),
                    ethers.parseEther("50")
                );
                await tournamentContract.connect(user).joinTournament();
            }
            
            // Update scores - user1 is the winner
            await tournamentContract.connect(owner).updateTournamentScore(user1Address, 100);
            await tournamentContract.connect(owner).updateTournamentScore(user2Address, 50);
            
            // Get initial balance of winner
            const initialBalance = await NUVO.balanceOf(user1Address);
            
            // Increase time to end tournament naturally
            await network.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 2 days
            await network.provider.send("evm_mine");
            
            // End tournament
            await tournamentContract.connect(owner).endTournament();
            
            // Verify winner received prize
            const finalBalance = await NUVO.balanceOf(user1Address);
            const prize = ethers.parseEther("300"); // 200 initial + 50*2 entries
            expect(finalBalance - initialBalance).to.equal(prize);
        });
    });

    describe("Factory Registry", function() {
        it("should register contract addresses correctly", async function() {
            const addresses = await factory.getContractAddresses();
            
            expect(addresses.core).to.equal(await coreContract.getAddress());
            expect(addresses.marketplace).to.equal(await marketplaceContract.getAddress());
            expect(addresses.tournament).to.equal(await tournamentContract.getAddress());
        });
        
        it("should prevent registering a contract twice", async function() {
            await expect(
                factory.registerCoreContract(await coreContract.getAddress())
            ).to.be.revertedWith("Core contract already registered");
        });
    });
});
