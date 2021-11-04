const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MetisFactory = await hre.ethers.getContractFactory('MockMetisToken');
    const DistributorFactory = await hre.ethers.getContractFactory('Distributor');
    const VaultFactory = await hre.ethers.getContractFactory('Vault');
    const MiningFactory = await hre.ethers.getContractFactory('Mining');
    const DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');
    const DACFactory = await hre.ethers.getContractFactory('DAC');

    const Metis = MetisFactory.attach('0x48b4d7b9d6EfC3a29Da6b2B2DA22cD743442e2Df');
    // const Metis = await MetisFactory.deploy([signer], '100000000000000000000000000');
    // await Metis.deployed();
    console.log('Mock Metis deployed to: ', Metis.address);
    const MetisAddress = Metis.address;

    const Distributor = DistributorFactory.attach('0x1D2dBfb34Dd106288a2fC837C23412eD7f1A6641');
    // const Distributor = await DistributorFactory.deploy(MetisAddress);
    // await Distributor.deployed();
    console.log('Distributor deployed to: ', Distributor.address);

    // const Vault = await VaultFactory.deploy(MetisAddress, );
    // await Vault.deployed();
    const Vault = VaultFactory.attach('0xDF2C1Fcf92Dada2DeC9D1a250Da9A7b1B990dB9B');
    console.log('Vault deployed to: ', Vault.address);

    // const DACRecorder = await DACRecorderFactory.deploy(MetisAddress, Vault.address, );
    // await DACRecorder.deployed();
    const DACRecorder = DACRecorderFactory.attach('0x2C1422FB645F94c7e7dd3EcC08FFd271453f0CCc');
    console.log('DACRecorder deployed to: ', DACRecorder.address);

    // const Mining = await MiningFactory.deploy(
    //     MetisAddress,
    //     DACRecorder.address,
    //     Distributor.address,
    //     '18500000000000000',
    //     1636017645,
    // );
    // await Mining.deployed();
    const Mining = MiningFactory.attach('0x648dE61413eFf80Df78c684B2352C8D596A7Ce50');
    console.log('Mining deployed to: ', Mining.address);

    const DAC = await hre.upgrades.deployProxy(DACFactory, [MetisAddress, Mining.address], {
        initializer: "initialize"
    });
    await DAC.deployed();
    console.log('DAC deployed to: ', DAC.address);

    const addresses = {
        MetisAddress,
        DAC: DAC.address,
        DACRecorder: DACRecorder.address,
        Mining: Mining.address,
        Vault: Vault.address,
        Distributor: Distributor.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/addresses-rinkeby.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
