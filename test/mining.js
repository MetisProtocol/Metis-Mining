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

        this.MockMetisTokenFactory = await hre.ethers.getContractFactory('MockMetisToken');
        this.MockDACFactory = await hre.ethers.getContractFactory('MockDAC');
        this.VaultFactory = await hre.ethers.getContractFactory('Vault');
        this.MiningFactory = await hre.ethers.getContractFactory('Mining');
        this.DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');
    });

    beforeEach(async function () {
        this.metis = await this.MockMetisTokenFactory.deploy([this.minter.address], '10000000000000000000000000');
        // mint 100000 MockMetis Token to minter
        await this.metis.functions['mint'](this.minter.address, '100000000000000000000000');

        this.vault = await this.VaultFactory.deploy(this.metis.address);
        await this.vault.deployed();

        this.DACRecorder = await this.DACRecorderFactory.deploy();
        await this.DACRecorder.deployed();
        
        this.mockDAC = await this.MockDACFactory.deploy(
            ADDRESS_ZERO,
            this.metis.address,
        );
        await this.mockDAC.deployed();
    })

    context("With MockMetis token added to the field", function () {
        beforeEach(async function () {
            await this.metis.connect(this.minter).transfer(this.alice.address, "3000000000000000000000");

            await this.metis.connect(this.minter).transfer(this.bob.address, "3000000000000000000000");

            await this.metis.connect(this.minter).transfer(this.carol.address, "3000000000000000000000");

            // 18500000000000000 per second farming rate starting at 100 seconds after the current time
            this.mining = await this.MiningFactory.deploy(
                this.metis.address,
                this.vault.address,
                this.DACRecorder.address,
                "18500000000000000",
                (await TimeHelper.latestBlockTimestamp()).toNumber() + 100,
            );
            await this.mining.deployed();

            // config for related contracts
            await this.DACRecorder.setMining(this.mining.address);
            await this.mockDAC.setMiningContract(this.mining.address);
            await this.vault.setMiningContract(this.mining.address);
            await this.mining.setDAC(this.mockDAC.address);
            // await this.mining.setVault(this.vault.address);
            // await this.mining.setDACRecorder(this.DACRecorder.address);

            await this.metis.functions['addMinter'](this.mining.address);

            await this.mining.add(100, this.metis.address, false);

            await this.metis.connect(this.alice).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.bob).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.carol).approve(this.mining.address, hre.ethers.constants.MaxUint256);
        });

        it("should deposit Metis between 100 and 2000 for creator and member", async function () {
            await expect(this.mockDAC.connect(this.alice).creatorDeposit(
                '1',
                '1',
                '80',
            )).to.be.revertedWith('Deposit amount is invalid');

            await expect(this.mockDAC.connect(this.alice).creatorDeposit(
                '2001000000000000000000',
                '1',
                '80'
            )).to.be.revertedWith('Deposit amount is invalid');

            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");

            await expect(this.mockDAC.connect(this.bob).memberDeposit(
                this.alice.address,
                '1',
                '2',
                '80'
            )).to.be.revertedWith('Deposit amount is invalid');

            await expect(this.mockDAC.connect(this.bob).memberDeposit(
                this.alice.address,
                '2001000000000000000000',
                '2',
                '80'
            )).to.be.revertedWith('Deposit amount is invalid');

            await this.mockDAC.connect(this.bob).creatorDeposit(
                '2000000000000000000000',
                '2',
                '80'
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("1000000000000000000000");
        });

        it("should give out Metis only after farming time", async function () {
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '2000000000000000000000',
                '1',
                '80'
            );
            const startTime = (await this.mining.startTimestamp()).toNumber();
            // console.log('start block.timestamp: ', startTime);
            // const initialTime = (await TimeHelper.latestBlockTimestamp()).toNumber();
            // console.log('initial block.timestamp: ', initialTime);

            await TimeHelper.advanceTimeAndBlock(10);
            // console.log('first move block.timestamp: ', (await TimeHelper.latestBlockTimestamp()).toNumber());
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(20);
            // console.log('second move block.timestamp: ', (await TimeHelper.latestBlockTimestamp()).toNumber());
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(30);
            // console.log('third move block.timestamp: ', (await TimeHelper.latestBlockTimestamp()).toNumber());
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(40);
            // const fouthTime = (await TimeHelper.latestBlockTimestamp()).toNumber();
            // console.log('fouth move block.timestamp: ', fouthTime);
            // console.log(((await this.mining.poolInfo(0)).lastRewardTimestamp).toNumber());
            const accTime = ((await this.mining.calcMetisReward(startTime, '100')).accTime.toNumber());
            // console.log('======accTime', accTime);
            console.log('======reward', ((await this.mining.calcMetisReward(startTime, '100')).MetisReward.toString()));
            const pendingAlice = (await this.mining.pendingMetis('0', this.alice.address)).toString();
            console.log('alice pending rewards: ', pendingAlice);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            // console.log(((await this.mining.poolInfo(0)).lastRewardTimestamp).toNumber());
            // console.log(((await this.mining.poolInfo(0)).accMetisPerShare).toString());
            const userReward = (accTime + 1) * 185 * 1e14;
            console.log('alice rewards: ', userReward.toString());
            expect(await this.vault.shares(this.alice.address)).to.equal(userReward.toString());
        });
        it("should distribute Metis properly for each creator", async function () {
            const startTime = (await this.mining.startTimestamp()).toNumber();
            console.log('start block.timestamp: ', startTime);
            const initialTime = (await TimeHelper.latestBlockTimestamp()).toNumber();
            console.log('initial block.timestamp: ', initialTime);
            // alice deposit 1000 Metis at initial time
            await this.mockDAC.connect(this.alice).creatorDeposit(
                '1000000000000000000000',
                '1',
                '80'
            );
            const secondTime = (await TimeHelper.latestBlockTimestamp()).toNumber();
            console.log('second block.timestamp: ', secondTime);
            // bob deposit 1000 Metis at second time
            await this.mockDAC.connect(this.bob).creatorDeposit(
                '1000000000000000000000',
                '1',
                '90'
            );
            const aliceAmount = (await this.mining.userInfo('0', this.alice.address)).amount.toString();
            console.log('alice amount: ', aliceAmount);
            const bobAmount = (await this.mining.userInfo('0', this.bob.address)).amount.toString();
            console.log('bob amount: ',bobAmount);
            const aliceAccPower = (await this.DACRecorder.checkUserInfo(this.alice.address)).accPower.toString();
            console.log('alice acc power: ', aliceAccPower);
            const bobAccPower = (await this.DACRecorder.checkUserInfo(this.bob.address)).accPower.toString();
            console.log('alice acc power: ', bobAccPower);
            // advance 100 to block.timestamp and one block
            await TimeHelper.advanceTimeAndBlock(100);
            const pendingAlice = (await this.mining.pendingMetis('0', this.alice.address)).toString();
            console.log('alice pending rewards: ', pendingAlice);
            const pendingBob = (await this.mining.pendingMetis('0', this.bob.address)).toString();
            console.log('bob pending rewards: ', pendingBob);
            const accTime = ((await this.mining.calcMetisReward(startTime, '100')).accTime.toNumber());
            const totalReward = ((await this.mining.calcMetisReward(startTime, '100')).MetisReward.toString());
            console.log('accTime: ', accTime);
            console.log('totalReward: ', totalReward);
            // const aliceReward = (accTime + 1) * 185 * 1e14 * 0.5;
            // await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            // expect(await this.vault.shares(this.alice.address)).to.equal(aliceReward.toString());
            // await this.mining.connect(this.bob).withdraw(ADDRESS_ZERO, '0', '0');
        });
    });
});