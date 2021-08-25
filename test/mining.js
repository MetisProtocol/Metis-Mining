const { expect } = require("chai");

describe("Mining Contract", function () {

    let signer;
    let MockMetisTokenFactory;
    let MockMetis;
    let MockDACFactory;
    let MockDAC;
    let VaultFactory;
    let Vault;
    let MiningFactory;
    let Mining;
    let DACRecorderFactory;
    let DACRecorder;

    beforeEach(async function () {
        const accounts = await ethers.getSigners();
        signer = accounts[0].address;

        MockMetisTokenFactory = await hre.ethers.getContractFactory('MockMetisToken');
        MockDACFactory = await hre.ethers.getContractFactory('MockDAC');
        VaultFactory = await hre.ethers.getContractFactory('Vault');
        MiningFactory = await hre.ethers.getContractFactory('Mining');
        DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');

        MockMetis = await MockMetisTokenFactory.deploy([signer], '10000000000000000000000000');
        await MockMetis.deployed();

        Vault = await VaultFactory.deploy(MockMetis.address);
        await Vault.deployed();

        DACRecorder = await DACRecorderFactory.deploy();
        await DACRecorder.deployed();

        Mining = await MiningFactory.deploy(
            MockMetis.address,
            Vault.address,
            DACRecorder.address,
            '18500000000000000',
            Math.round(Date.now() / 1000) + 100,
        );
        await Mining.deployed();

        MockDAC = await MockDACFactory.deploy(
            Mining.address,
            MockMetis.address,
        );
        await MockDAC.deployed();
    });

    it("Should mint 10000 MockMetis Token to signer", async function () {
        await MockMetis.functions['mint'](signer, '10000000000000000000000');

        const ownerBalance = await MockMetis.balanceOf(signer);
        expect(await MockMetis.totalSupply()).to.equal(ownerBalance);
    });

    it('Add Mining contract to be the second minter of MockMetisToken', async function() {
        await MockMetis.functions['addMinter'](Mining.address);
        expect(await MockMetis.minters_(1)).to.equal(Mining.address);
    });

    it('Set DAC contract to Mining contract', async function () {
        await Mining.functions['setDAC'](MockDAC.address);
        expect(await Mining.DAC()).to.equal(MockDAC.address);
    });

    it('Add Metis Pool to Mining contract', async function () {
        await Mining.functions['add'](100, MockMetis.address, false);
        const poolInfo = await Mining.poolInfo(0);
        expect(poolInfo.token).to.equal(MockMetis.address);
        expect(poolInfo.allocPoint).to.equal(100);
    });

    it('Approve Mining contract to use signer\'s MockMetisToken', async function () {
        await MockMetis.functions['approve'](Mining.address, hre.ethers.constants.MaxUint256);
        expect(await MockMetis.allowance(signer, Mining.address)).to.equal(hre.ethers.constants.MaxUint256);
    });
});