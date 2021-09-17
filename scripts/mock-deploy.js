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
    // (10000000 * 1e18)
    const MockMetis = await MockMetisTokenFactory.deploy([signer], '10000000000000000000000000');
    await MockMetis.deployed();
    console.log('MockMetis deployed to: ', MockMetis.address);

    const Distributor = await DistributorFactory.deploy(MockMetis.address);
    await Distributor.deployed();
    console.log('Distributor deployed to: ', Distributor.address);

    // await MockMetis.mint(Distributor.address, '1000000000000000000000000');
    // console.log('Mint 1000000 Mock Metis token to distributor');

    // await MockMetis.mint(signer, '1000000000000000000000000');
    // console.log('Mint 1000000 Mock Metis token to signer');

    // await MockMetis.mint('0x6cFB8E9B1c625a8CccC315A8dffA476069557cfd', '10000000000000000000000');
    // console.log('Mint 10000 Mock Metis token to 0x6cFB8E9B1c625a8CccC315A8dffA476069557cfd');
    // await MockMetis.mint('0x1838Be1Ce335f3658072a1db6AD3A6b04629bF5C', '10000000000000000000000');
    // console.log('Mint 10000 Mock Metis token to 0x1838Be1Ce335f3658072a1db6AD3A6b04629bF5C');
    // await MockMetis.mint('0x7DbaCf78739bd74e7Eb89BeC0F3F526dcE694ca0', '10000000000000000000000');
    // console.log('Mint 10000 Mock Metis token to 0x7DbaCf78739bd74e7Eb89BeC0F3F526dcE694ca0');
    // await MockMetis.mint('0xc180Dc7C826e023C8C7CA5BA38F340D7a5dA1421', '10000000000000000000000');
    // console.log('Mint 10000 Mock Metis token to 0xc180Dc7C826e023C8C7CA5BA38F340D7a5dA1421');
    // await MockMetis.mint('0x9d7C0E06147D8340eebC92F541b446F30b6F7F40', '10000000000000000000000');
    // console.log('Mint 10000 Mock Metis token to 0x9d7C0E06147D8340eebC92F541b446F30b6F7F40');

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

    const addresses = {
        MockMetis: MockMetis.address,
        DAC: '0x72D34bF71BfCDD95273F48FE03a73f7B880B94b7',
        DACRecorder: DACRecorder.address,
        Mining: Mining.address,
        Vault: Vault.address,
        Distributor: Distributor.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/mock-addresses.json`, JSON.stringify(addresses, null, 4));

    // // set Mining contract for Distributor
    // await Distributor.setMiningContract(Mining.address);
    // // set Mining contract for DACRecorder
    // await DACRecorder.setMiningContract(Mining.address);
    // console.log('Set Mining contract for DACRecorder');
    // // set DACRecorder for Vault
    // await Vault.setDACRecorder(DACRecorder.address);
    // console.log('Set DACRecorder contract for Vault');
    // // set DAC for Mining contract
    // await Mining.functions['setDAC']('0x72D34bF71BfCDD95273F48FE03a73f7B880B94b7');
    // console.log('Set DAC contract for Mining');
    // // add Metis pool
    // await Mining.add(100, MockMetis.address, false, );
    // console.log('Add MockMetis pool');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
