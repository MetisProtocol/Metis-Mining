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
        this.VaultFactory = await hre.ethers.getContractFactory('Vault');
        this.MiningFactory = await hre.ethers.getContractFactory('Mining');
        this.DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');
        this.DistributorFactory = await hre.ethers.getContractFactory('Distributor');
        this.DACFactory = await hre.ethers.getContractFactory('DAC');
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

            this.dac = await this.DACFactory.deploy(this.metis.address, this.mining.address);
            await this.dac.deployed();

            // config for related contracts
            await this.distributor.setMiningContract(this.mining.address);
            await this.DACRecorder.setMiningContract(this.mining.address);
            await this.DACRecorder.setMetisDAC(this.dac.address);
            await this.vault.setDACRecorder(this.DACRecorder.address);
            await this.mining.setDAC(this.dac.address);
            await this.mining.add(100, this.metis.address, false);
            // set `ADMIN_ROLE` admin role
            await this.dac.setRoleAdmin("0x61646d696e000000000000000000000000000000000000000000000000000000", "0x61646d696e000000000000000000000000000000000000000000000000000000");
            // set `MINING_ROLE` admin role
            await this.dac.setRoleAdmin("0x6d696e696e670000000000000000000000000000000000000000000000000000", "0x61646d696e000000000000000000000000000000000000000000000000000000");
            await this.dac.grantRole("0x6d696e696e670000000000000000000000000000000000000000000000000000", this.mining.address);

            // testers approve mining to use their Metis
            await this.metis.connect(this.alice).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.bob).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.carol).approve(this.mining.address, hre.ethers.constants.MaxUint256);
            await this.metis.connect(this.daniel).approve(this.mining.address, hre.ethers.constants.MaxUint256);
        });

        it("should deposit and withdraw properly", async function () {
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            await this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '500000000000000000000',
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1500000000000000000000");
            await this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '1000000000000000000000',
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("2500000000000000000000");
            await this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '500000000000000000000',
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("3000000000000000000000");
        });

        it("member should deposit and withdraw properly", async function () {
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            let aliceInfo = await this.DACRecorder.checkUserInfo(this.alice.address);
            // console.log('alice power 1: ', aliceInfo[1].toString());
            const aliceDACId = await this.dac.userToDAC(this.alice.address);
            const aliceInviteCode = await this.dac.DACToInvitationCode(aliceDACId);
            await this.dac.connect(this.bob).joinDAC(
                aliceDACId,
                '1000000000000000000000',
                aliceInviteCode
            );
            await this.dac.connect(this.bob).increaseDeposit(
                aliceDACId,
                this.alice.address,
                '1000000000000000000000',
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("1000000000000000000000");
            aliceInfo = await this.DACRecorder.checkUserInfo(this.alice.address);
            // console.log('alice power 2: ', aliceInfo[1].toString());
            await this.mining.connect(this.bob).withdraw(
                this.alice.address,
                '0',
                '1000000000000000000000',
            );
            await this.mining.connect(this.bob).withdraw(
                this.alice.address,
                '0',
                '1000000000000000000000',
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("3000000000000000000000");
            
            aliceInfo = await this.DACRecorder.checkUserInfo(this.alice.address);
            // console.log('alice power 3: ', aliceInfo[1].toString());
        });

        it("creator withdraw all without DAO opening", async function () {
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            const aliceDACId = await this.dac.userToDAC(this.alice.address);
            const aliceInviteCode = await this.dac.DACToInvitationCode(aliceDACId);
            console.log(aliceDACId);
            console.log(aliceInviteCode);
            let dacInfo = await this.DACRecorder.checkDACInfo(aliceDACId);
            console.log('======', dacInfo);
            await this.dac.connect(this.bob).joinDAC(
                aliceDACId,
                '2000000000000000000000',
                aliceInviteCode
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("1000000000000000000000");

            await this.dac.connect(this.carol).createDAC(
                'carol',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            );
            expect(await this.metis.balanceOf(this.carol.address)).to.equal("1000000000000000000000");
            const carolDACId = await this.dac.userToDAC(this.carol.address);
            const carolInviteCode = await this.dac.DACToInvitationCode(carolDACId);
            await this.dac.connect(this.daniel).joinDAC(
                carolDACId,
                '2000000000000000000000',
                carolInviteCode
            );
            expect(await this.metis.balanceOf(this.daniel.address)).to.equal("1000000000000000000000");
            
            await this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '2000000000000000000000',
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("3000000000000000000000");
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("1000000000000000000000");
            await TimeHelper.advanceTimeAndBlock(1000);
            const pendingBobRewards = await this.mining.pendingMetis(0, this.bob.address);
            expect(pendingBobRewards).to.equal(0);

            await this.mining.connect(this.bob).withdraw(
                this.alice.address,
                '0',
                '2000000000000000000000',
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("3000000000000000000000");
            expect(await this.vault.shares(this.bob.address)).to.equal("0");
        });

        it("can't withdraw all with DAO opening", async function () {
            await this.DACRecorder.setDAOOpen(true);
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            await expect(this.mining.connect(this.alice).withdraw(
                ADDRESS_ZERO,
                '0',
                '2000000000000000000000',
            )).to.be.revertedWith('not allowed');
        });

        it("dismiss DAC with DAO opening", async function () {
            await this.DACRecorder.setDAOOpen(true);
            await this.dac.setDAOOpening(true);
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            );
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            const aliceDACId = await this.dac.userToDAC(this.alice.address);
            let dacInfo = await this.DACRecorder.checkDACInfo(aliceDACId);
            let dacInfo2 = await this.dac.getDACMemberCount(aliceDACId);
            console.log('first dac-r info', dacInfo.userCount.toString());
            console.log('first dac info', dacInfo2.toString())
            await this.dac.connect(this.alice).DAODismissDAC(aliceDACId);
            dacInfo = await this.DACRecorder.checkDACInfo(aliceDACId);
            dacInfo2 = await this.dac.getDACMemberCount(aliceDACId);
            console.log('second dac-r info', dacInfo.userCount.toString());
            console.log('second dac info', dacInfo2.toString())
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("3000000000000000000000");
        });

        it("should deposit Metis between 100 and 2000 for creator and member", async function () {
            await expect(this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '1'
            )).to.be.revertedWith('amount not allowed');
            await expect(this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2001000000000000000000'
            )).to.be.revertedWith('amount not allowed');

            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            )
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");
            const aliceDACId = await this.dac.userToDAC(this.alice.address);
            const aliceInviteCode = await this.dac.DACToInvitationCode(aliceDACId);
            await expect(this.dac.connect(this.bob).joinDAC(
                aliceDACId,
                '1',
                aliceInviteCode
            )).to.be.revertedWith('amount is invalid');
            await expect(this.dac.connect(this.bob).joinDAC(
                aliceDACId,
                '2001000000000000000000',
                aliceInviteCode
            )).to.be.revertedWith('amount is invalid');

            await this.dac.connect(this.bob).joinDAC(
                aliceDACId,
                '2000000000000000000000',
                aliceInviteCode
            );
            expect(await this.metis.balanceOf(this.bob.address)).to.equal("1000000000000000000000");
        });

        it("should give out Metis only after farming time", async function () {
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '2000000000000000000000'
            )
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("1000000000000000000000");

            await TimeHelper.advanceTimeAndBlock(10);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(20);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(30);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            expect(await this.vault.shares(this.alice.address)).to.equal("0");

            await TimeHelper.advanceTimeAndBlock(40);
            const pending = await this.mining.pendingMetis(0, this.alice.address);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            const aliceReward = pending.add(1e15);
            expect(await this.vault.shares(this.alice.address)).to.equal(aliceReward.toString());
        });

        it("should distribute Metis properly for each creators", async function () {
            // Alice deposit 1000 Metis at the first time
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '1000000000000000000000'
            )
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("2000000000000000000000");

            // Bob deposit 1000 Metis at second time
            await this.dac.connect(this.bob).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '1000000000000000000000'
            )
            expect(await this.metis.balanceOf(this.alice.address)).to.equal("2000000000000000000000");

            // advance 100 to block.timestamp and one block
            await TimeHelper.advanceTimeAndBlock(100);
            const alicePending = await this.mining.pendingMetis(0, this.alice.address);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            const aliceReward = alicePending.add(1e15 * 0.5);
            expect(await this.vault.shares(this.alice.address)).to.equal(aliceReward.toString());
            const bobPending = await this.mining.pendingMetis(0, this.bob.address);
            await this.mining.connect(this.bob).withdraw(ADDRESS_ZERO, '0', '0');
            const bobReward = bobPending.add(1e15 * 0.5);
            expect(await this.vault.shares(this.bob.address)).to.equal(bobReward.toString());
        });

        it("should distribute Metis properly for different cretors and members", async function () {
            // Alice deposit 1000 Metis at the first time
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '1000000000000000000000'
            )
            await TimeHelper.advanceTimeAndBlock(100);
            let alicePending = await this.mining.pendingMetis(0, this.alice.address);
            console.log('alicePending1', alicePending.toString());
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            let aliceReward = alicePending.add(1e15);
            const firstAliceShare = await this.vault.shares(this.alice.address);
            expect(firstAliceShare).to.equal(aliceReward.toString());
            alicePending = await this.mining.pendingMetis(0, this.alice.address);
            console.log('alicePending2', alicePending.toString())
            const aliceDACId = await this.dac.userToDAC(this.alice.address);
            const aliceInviteCode = await this.dac.DACToInvitationCode(aliceDACId);
            // Alice invite Bob to DAC and member Bob deposit 100 Metis with 80 power at this time
            await this.dac.connect(this.bob).joinDAC(
                aliceDACId,
                '100000000000000000000',
                aliceInviteCode
            );
            await TimeHelper.advanceTimeAndBlock(1);
            const currentTime = await TimeHelper.latestBlockTimestamp();
            console.log('currentTime', currentTime.toString());

            const poolInfo = await this.mining.poolInfo(0);
            console.log('last reward time', poolInfo.lastRewardTimestamp.toString());
            console.log('pool share', poolInfo.accMetisPerShare.toString());
            
            const metisReward = await this.mining.calcMetisReward(poolInfo.lastRewardTimestamp, 100);
            console.log('acc time', metisReward.accTime.toString());
            console.log('metisReward', metisReward.MetisReward.toString());

            const totalWeight = await this.DACRecorder.totalWeight();
            console.log('total weight', totalWeight.toString());

            const aliceInfo = await this.mining.userInfo(0, this.alice.address);
            const aliceDACInfo = await this.DACRecorder.checkUserInfo(this.alice.address);
            console.log('alice amount', aliceInfo.amount.toString());
            console.log('alice debt', aliceInfo.rewardDebt.toString());
            console.log('aliceDACInfo amount', aliceDACInfo.amount.toString());
            console.log('aliceDACInfo power', aliceDACInfo.accPower.toString());

            const bobInfo = await this.mining.userInfo(0, this.bob.address);
            const bobDACInfo = await this.DACRecorder.checkUserInfo(this.bob.address);
            console.log('bob amount', bobInfo.amount.toString());
            console.log('bob debt', bobInfo.rewardDebt.toString());
            console.log('bobDACInfo amount', bobDACInfo.amount.toString());
            console.log('bobDACInfo power', bobDACInfo.accPower.toString());

            const alicePerSecond = await this.mining.pendingMetis(0, this.alice.address);
            console.log('alicePerSecond', alicePerSecond.toString())
            const bobPerSecond = await this.mining.pendingMetis(0, this.bob.address);
            console.log('bobPerSecond', bobPerSecond.toString());

            await TimeHelper.advanceTimeAndBlock(99);

            alicePending = await this.mining.pendingMetis(0, this.alice.address);
            aliceReward = alicePending.add(alicePerSecond);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            const secondAliceShare = await this.vault.shares(this.alice.address);
            expect(secondAliceShare.sub(firstAliceShare)).to.equal(aliceReward);

            bobPending = await this.mining.pendingMetis(0, this.bob.address);
            await this.mining.connect(this.bob).withdraw(this.alice.address, '0', '0');
            bobReward = bobPending.add(bobPerSecond);
            expect(await this.vault.shares(this.bob.address)).to.equal(bobReward);
        });

        it("should sub creator power properly", async function () {
            // Alice deposit 1000 Metis at the first time
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '1000000000000000000000'
            );
            await TimeHelper.advanceTimeAndBlock(100);
            const alicePending = await this.mining.pendingMetis(0, this.alice.address);
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
            let aliceReward = alicePending.add(1e15);
            const firstAliceShare = await this.vault.shares(this.alice.address);
            expect(firstAliceShare).to.equal(aliceReward.toString());
            const aliceDACId = await this.dac.userToDAC(this.alice.address);
            const aliceInviteCode = await this.dac.DACToInvitationCode(aliceDACId);
            // Alice invite Bob to DAC and member Bob deposit 100 Metis with 80 power at this time
            await this.dac.connect(this.bob).joinDAC(
                aliceDACId,
                '100000000000000000000',
                aliceInviteCode
            );
            await TimeHelper.advanceTimeAndBlock(100);
            // afeter 100s, bob withdraw all
            await this.mining.connect(this.bob).withdraw(this.alice.address, '0', '100000000000000000000');
            // calculate alice reward per second
            await TimeHelper.advanceTimeAndBlock(1);
            const alicePerSecond = await this.mining.pendingMetis(0, this.alice.address);
            expect(alicePerSecond).to.equal(1e15);
        });

        it("should claim Metis properly from Vault", async function () {
            const startTime = (await this.mining.startTimestamp()).toNumber();
            // Alice deposit 1000 Metis at the first time
            await this.dac.connect(this.alice).createDAC(
                'alice',
                'introduction',
                'category',
                'url',
                'photo',
                '1000000000000000000000'
            )
            await TimeHelper.advanceTimeAndBlock(100);
            let accTime = ((await this.mining.calcMetisReward(startTime, '100')).accTime.toNumber());
            await this.mining.connect(this.alice).withdraw(ADDRESS_ZERO, '0', '0');
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