const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MetisAddress = '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000';

    const DistributorFactory = await hre.ethers.getContractFactory('Distributor');
    const VaultFactory = await hre.ethers.getContractFactory('Vault');
    const MiningFactory = await hre.ethers.getContractFactory('Mining');
    const DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');
    const DACFactory = await hre.ethers.getContractFactory('DAC');

    // const Distributor = DistributorFactory.attach('0x4F2185589C43ab8e0Ff91E6bbA9921414eDE8Eae');
    // if chain is redeployed, redeploy Distributor
    const Distributor = await DistributorFactory.deploy(MetisAddress);
    await Distributor.deployed();
    console.log('Distributor deployed to: ', Distributor.address);

    const Vault = await VaultFactory.deploy(MetisAddress, );
    await Vault.deployed();
    // const Vault = VaultFactory.attach('0xB9aeb01f1Ed9fE1ffB64C1B74Eeb59D8C4F750dD');
    console.log('Vault deployed to: ', Vault.address);

    const DACRecorder = await DACRecorderFactory.deploy(MetisAddress, Vault.address, );
    await DACRecorder.deployed();
    // const DACRecorder = DACRecorderFactory.attach('0x13eeA7d016B55F423981232Dc4345a2A98CB335D');
    console.log('DACRecorder deployed to: ', DACRecorder.address);

    const Mining = await MiningFactory.deploy(
        MetisAddress,
        DACRecorder.address,
        Distributor.address,
        '18500000000000000',
        // 7PM UTC Nov 26
        1637953200,
    );
    await Mining.deployed();
    // const Mining = MiningFactory.attach('0x3B00912495b52c18324691695DDB015eF8a32195');
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

    fs.writeFileSync(`${__dirname}/addresses-1088-public.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
