const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MockMetisTokenFactory = await hre.ethers.getContractFactory('MockMetisToken');
    const DistributorFactory = await hre.ethers.getContractFactory('Distributor');
    const VaultFactory = await hre.ethers.getContractFactory('Vault');
    const MiningFactory = await hre.ethers.getContractFactory('Mining');
    const DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');
    const DACFactory = await hre.ethers.getContractFactory('DAC');
    // (10000000 * 1e18)
    const MockMetis = await MockMetisTokenFactory.deploy([signer], '10000000000000000000000000');
    await MockMetis.deployed();
    console.log('MockMetis deployed to: ', MockMetis.address);

    const Distributor = await DistributorFactory.deploy(MockMetis.address);
    await Distributor.deployed();
    console.log('Distributor deployed to: ', Distributor.address);

    const Vault = await VaultFactory.deploy(MockMetis.address, );
    await Vault.deployed();
    console.log('Vault deployed to: ', Vault.address);

    DACRecorder = await DACRecorderFactory.deploy(MockMetis.address, Vault.address, );
    await DACRecorder.deployed();
    console.log('DACRecorder deployed to: ', DACRecorder.address);

    const Mining = await MiningFactory.deploy(
        MockMetis.address,
        DACRecorder.address,
        Distributor.address,
        '18500000000000000',
        Math.round(Date.now() / 1000) + 100, 
    );
    await Mining.deployed();
    console.log('Mining deployed to: ', Mining.address);

    const DAC = await DACFactory.deploy(MockMetis.address, Mining.address);
    await DAC.deployed();
    console.log('DAC deployed to: ', DAC.address);

    const addresses = {
        MockMetis: MockMetis.address,
        DAC: DAC.address,
        DACRecorder: DACRecorder.address,
        Mining: Mining.address,
        Vault: Vault.address,
        Distributor: Distributor.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/mock-addresses.json`, JSON.stringify(addresses, null, 4));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
