const { expect } = require("chai");
const TimeHelper = require('./utils/time');

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"

describe("Mining Contract", function () {

    before(async function () {
        this.signers = await ethers.getSigners();
        this.minter = this.signers[0]
        this.alice = this.signers[1]
        this.bob = this.signers[2]
        this.carol = this.signers[3]
        this.daniel = this.signers[4]

        this.MockMetisTokenFactory = await hre.ethers.getContractFactory('MockMetisToken');
        this.MockDACFactory = await hre.ethers.getContractFactory('MockDAC');
        this.VaultFactory = await hre.ethers.getContractFactory('Vault');
        this.MiningFactory = await hre.ethers.getContractFactory('Mining');
        this.DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');
        this.DistributorFactory = await hre.ethers.getContractFactory('Distributor');
    });

    beforeEach(async function () {
        this.metis = await this.MockMetisTokenFactory.deploy([this.minter.address], '10000000000000000000000000');
        // mint 100000 MockMetis Token to minter
        await this.metis.functions['mint'](this.minter.address, '100000000000000000000000');

        this.vault = await this.VaultFactory.deploy(this.metis.address);
        await this.vault.deployed();

        this.DACRecorder = await this.DACRecorderFactory.deploy(
            this.metis.address,
            this.vault.address,
        );
        await this.DACRecorder.deployed();
        
        this.mockDAC = await this.MockDACFactory.deploy(
            ADDRESS_ZERO,
            this.metis.address,
        );
        await this.mockDAC.deployed();

        this.distributor = await this.DistributorFactory.deploy(this.metis.address);
        await this.distributor.deployed();

        // mint 1000000 MockMetis Token to distributor
        await this.metis.functions['mint'](this.distributor.address, '1000000000000000000000000');
    })

    context("With MockMetis token added to the field", function () {
        beforeEach(async function () {
            // transfer 3000 metis from minter to each testers
            await this.metis.connect(this.minter).transfer(this.alice.address, "3000000000000000000000");

            await this.metis.connect(this.minter).transfer(this.bob.address, "3000000000000000000000");

            await this.metis.connect(this.minter).transfer(this.carol.address, "3000000000000000000000");

            await this.metis.connect(this.minter).transfer(this.daniel.address, "3000000000000000000000");

            // 0.001 * 1e18 per second farming rate starting at 100 seconds after the current time
            this.mining = await this.MiningFactory.deploy(
                this.metis.address,
                this.DACRecorder.address,
                this.distributor.address,
                "1000000000000000",
                (await TimeHelper.latestBlockTimestamp()).toNumber() + 100,
            );
            await this.mining.deployed();

            // config for related contracts
            await this.distributor.setMiningContract(this.mining.address);
            await this.DACRecorder.setMiningContract(this.mining.address);
            await this.mockDAC.setMiningContract(this.mining.address);
            await this.vault.setDACRecorder(this.DACRecorder.address);
            await this.mining.setDAC(this.mockDAC.address);
            await this.mining.add(100, this.metis.address, false);

            // testers approve mining to use their Metis
            await this.metis.connect(this.alice).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.bob).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.carol).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.daniel).approve(this.mining.address, hre.ethers.constants.MaxUint256);
        });

        it("should deposit and withdraw properly", async function () {
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80',
                '1'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            await this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '2000000000000000000000',
                '1'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("3000000000000000000000");
        });

        it("creator withdraw all without DAO opening", async function () {
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80',
                '1'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");

            await this.mockDAC.connect(this.bob).memberDeposit(
                this.alice.address,
                '2000000000000000000000',
                '2',
                '80',
                '1'
            );

            await this.mockDAC.connect(this.carol).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80',
                '2'
            );

            await this.mockDAC.connect(this.daniel).memberDeposit(
                this.carol.address,
                '2000000000000000000000',
                '2',
                '80',
                '2'
            );

            // const dacInfo = await this.DACRecorder.checkDACInfo(1);
            // console.log('dac info: ', dacInfo);
            
            await this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '2000000000000000000000',
                '1'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("3000000000000000000000");
            // const dacInfo = await this.DACRecorder.checkDACInfo(1);
            // console.log('dac info: ', dacInfo);
            // expect(dacInfo[0]).to.equal(1);
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("1000000000000000000000");
            await TimeHelper.advanceTimeAndBlock(1000);
            const pendingBobRewards = await this.mining.pendingMetis(1, 0, this.bob.address);
            expect(pendingBobRewards).to.equal(0);
            // const carolWeight = await this.DACRecorder.userWeight(this.carol.address);
            // const danielWeight = await this.DACRecorder.userWeight(this.daniel.address);
            // const totalWeight = await this.DACRecorder.totalWeight();
            // console.log('carol weight: ', carolWeight.toString());
            // console.log('daniel weight: ', danielWeight.toString());
            // console.log('total weight: ', totalWeight.toString());
            // const pendingCarolRewards = await this.mining.pendingMetis(2, 0, this.carol.address);
            // const pendingDanielRewards = await this.mining.pendingMetis(2, 0, this.daniel.address);
            // console.log('pendingCarolRewards: ', pendingCarolRewards.toString());
            // console.log('pendingDanielRewards: ', pendingDanielRewards.toString());
            await this.mining.connect(this.bob).withdraw(
                this.alice.address,
                '0',
                '2000000000000000000000',
                '1'
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("3000000000000000000000");
            expect(await this.vault.shares(this.bob.address)).to.equal("0");
        });

        it("can't withdraw all with DAO opening", async function () {
            await this.DACRecorder.setDAOOpen(true);
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80',
                '1'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            await expect(this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '2000000000000000000000',
                '1'
            )).to.be.revertedWith('creatorWithdraw: Creator can\'t dismiss this DAC');
        });

        it("dismiss DAC with DAO opening", async function () {
            await this.DACRecorder.setDAOOpen(true);
            await this.mockDAC.setDAOOpen(true);
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80',
                '1'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            await this.mockDAC.connect(this.alice).DAODismiss('1');
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("3000000000000000000000");
        });

        it("should deposit Metis between 100 and 2000 for creator and member", async function () {
            await expect(this.mockDAC.connect(this.alice).creatorDeposit(
                '1',
                '1',
                '80',
                '1'
            )).to.be.revertedWith('Deposit amount is invalid');

            await expect(this.mockDAC.connect(this.alice).creatorDeposit(
                '2001000000000000000000',
                '1',
                '80',
                '1'
            )).to.be.revertedWith('Deposit amount is invalid');

            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80',
                '1'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");

            await expect(this.mockDAC.connect(this.bob).memberDeposit(
                this.alice.address,
                '1',
                '2',
                '80',
                '1'
            )).to.be.revertedWith('Deposit amount is invalid');

            await expect(this.mockDAC.connect(this.bob).memberDeposit(
                this.alice.address,
                '2001000000000000000000',
                '2',
                '80',
                '1'
            )).to.be.revertedWith('Deposit amount is invalid');

            await this.mockDAC.connect(this.bob).creatorDeposit(
                '2000000000000000000000',
                '2',
                '80',
                '2'
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("1000000000000000000000");
        });

        it("should give out Metis only after farming time", async function () {
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80',
                '1'
            );
            const startTime = (await this.mining.startTimestamp()).toNumber();

            await TimeHelper.advanceTimeAndBlock(10);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(20);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(30);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(40);
            const accTime = ((await this.mining.calcMetisReward(startTime, '100')).accTime.toNumber());
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');
            const userReward = (accTime + 1) * 1e15;
            expect(await this.vault.shares(this.alice.address)).to.equal(userReward.toString());
        });
        it("should distribute Metis properly for each creators", async function () {
            const startTime = (await this.mining.startTimestamp()).toNumber();

            // Alice deposit 1000 Metis with 100 power at the first time
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '1000000000000000000000',
                '1',
                '100',
                '1'
            );

            // Bob deposit 1000 Metis with 100 power at second time
            await this.mockDAC.connect(this.bob).creatorDeposit(
                '1000000000000000000000',
                '1',
                '100',
                '2'
            );

            // advance 100 to block.timestamp and one block
            await TimeHelper.advanceTimeAndBlock(100);
            const accTime = ((await this.mining.calcMetisReward(startTime, '100')).accTime.toNumber());
            
            const aliceReward = (accTime + 1) * 1e15 * 0.5;
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');
            expect(await this.vault.shares(this.alice.address)).to.equal(aliceReward.toString());

            const bobReward = (accTime + 2) * 1e15 * 0.5;
            await this.mining.connect(this.bob).withdraw(ADDRESS_ZERO, '0', '0', '2');
            expect(await this.vault.shares(this.bob.address)).to.equal(bobReward.toString());
        });
        it("should distribute Metis properly for different cretors and members", async function () {
            // Alice deposit 1000 Metis with 100 power at the first time
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '1000000000000000000000',
                '1',
                '100',
                '1'
            );
            await TimeHelper.advanceTimeAndBlock(100);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');

            const firstAliceShare = await this.vault.shares(this.alice.address);

            // Alice invite Bob to DAC and member Bob deposit 100 Metis with 80 power at this time
            await this.mockDAC.connect(this.bob).memberDeposit(
                this.alice.address,
                '100000000000000000000',
                '2',
                // this is the initialPower of Alice's DAC
                '100',
                '1'
            );
            await TimeHelper.advanceTimeAndBlock(100);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');
            await this.mining.connect(this.bob).withdraw(this.alice.address, '0', '0', '1');
            const secondAliceShare = await this.vault.shares(this.alice.address);
            const bobShare = await this.vault.shares(this.bob.address);
            expect(secondAliceShare.sub(firstAliceShare).add(bobShare)).to.equal('103000000000000000');
        });
        it("should claim Metis properly from Vault", async function () {
            const startTime = (await this.mining.startTimestamp()).toNumber();
            // Alice deposit 1000 Metis with 100 power at the first time
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '1000000000000000000000',
                '1',
                '100',
                '1'
            );
            await TimeHelper.advanceTimeAndBlock(100);
            let accTime = ((await this.mining.calcMetisReward(startTime, '100')).accTime.toNumber());
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0', '1');
            accTime += 1;
            let aliceReward = accTime * 1e15;
            expect(await this.vault.shares(this.alice.address)).to.equal(aliceReward.toString());

            // Alice claim from vault
            const aliceShare = aliceReward;
            // console.log('aliceShare', aliceShare);
            const beforeClaimBal = (await this.metis.balanceOf(this.alice.address));
            // console.log('beforeClaimBal', beforeClaimBal);
            await this.vault.connect(this.alice).leave(aliceShare.toString());
            const afterClaimBal = (await this.metis.balanceOf(this.alice.address));
            // console.log('afterClaimBal', afterClaimBal);
            expect(afterClaimBal.sub(beforeClaimBal)).to.equal((aliceShare * 0.9).toString());
        });
    });
});