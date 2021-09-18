const hre = require('hardhat');
const fs = require('fs');
const addresses = require('./mock-addresses.json');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MockMetisTokenFactory = await hre.ethers.getContractFactory('MockMetisToken');
    const DistributorFactory = await hre.ethers.getContractFactory('Distributor');
    const VaultFactory = await hre.ethers.getContractFactory('Vault');
    const MiningFactory = await hre.ethers.getContractFactory('Mining');
    const DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');

    const MockMetis = MockMetisTokenFactory.attach(addresses.MockMetis);
    const Distributor = DistributorFactory.attach(addresses.Distributor);
    const Vault = VaultFactory.attach(addresses.Vault);
    const DACRecorder = DACRecorderFactory.attach(addresses.DACRecorder);
    const Mining = MiningFactory.attach(addresses.Mining);

    await MockMetis.mint(Distributor.address, '100000000000000000000000');
    console.log('Mint 100000 Mock Metis token to distributor');
    await MockMetis.mint(signer, '10000000000000000000000');
    console.log('Mint 10000 Mock Metis token to signer');
    await MockMetis.mint('0x6cFB8E9B1c625a8CccC315A8dffA476069557cfd', '10000000000000000000000');
    console.log('Mint 10000 Mock Metis token to 0x6cFB8E9B1c625a8CccC315A8dffA476069557cfd');
    await MockMetis.mint('0x1838Be1Ce335f3658072a1db6AD3A6b04629bF5C', '10000000000000000000000');
    console.log('Mint 10000 Mock Metis token to 0x1838Be1Ce335f3658072a1db6AD3A6b04629bF5C');
    await MockMetis.mint('0x7DbaCf78739bd74e7Eb89BeC0F3F526dcE694ca0', '10000000000000000000000');
    console.log('Mint 10000 Mock Metis token to 0x7DbaCf78739bd74e7Eb89BeC0F3F526dcE694ca0');
    await MockMetis.mint('0xc180Dc7C826e023C8C7CA5BA38F340D7a5dA1421', '10000000000000000000000');
    console.log('Mint 10000 Mock Metis token to 0xc180Dc7C826e023C8C7CA5BA38F340D7a5dA1421');
    await MockMetis.mint('0x9d7C0E06147D8340eebC92F541b446F30b6F7F40', '10000000000000000000000');
    console.log('Mint 10000 Mock Metis token to 0x9d7C0E06147D8340eebC92F541b446F30b6F7F40');

    // set Mining contract for Distributor
    await Distributor.setMiningContract(Mining.address);
    console.log('Set Mining contract for Distributor');
    // set Mining contract for DACRecorder
    await DACRecorder.setMiningContract(Mining.address);
    console.log('Set Mining contract for DACRecorder');
    // set DACRecorder for Vault
    await Vault.setDACRecorder(DACRecorder.address);
    console.log('Set DACRecorder contract for Vault');
    // set DAC for Mining contract
    await Mining.functions['setDAC'](addresses.DAC);
    console.log('Set DAC contract for Mining');
    // add Metis pool
    await Mining.add(100, MockMetis.address, false,);
    console.log('Add MockMetis pool');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
