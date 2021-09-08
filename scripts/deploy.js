const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    let MetisTokenAddr;
    if (!process.env.MetisToken) {
        throw new Error("Please set your MetisToken contract address in a .env file");
    } else {
        MetisTokenAddr = process.env.MetisToken;
    }

    let DACAddr;
    if (!process.env.DAC) {
        throw new Error("Please set your DAC contract address in a .env file");
    } else {
        DACAddr = process.env.DAC;
    }

    const DistributorFactory = await hre.ethers.getContractFactory('Distributor');
    const VaultFactory = await hre.ethers.getContractFactory('Vault');
    const DACRecorderFactory = await hre.ethers.getContractFactory('DACRecorder');
    const MiningFactory = await hre.ethers.getContractFactory('Mining');

    const Distributor = await DistributorFactory.deploy(MetisTokenAddr);
    await Distributor.deployed();
    console.log('Distributor deployed to: ', Distributor.address);

    const Vault = await VaultFactory.deploy(MockMetis.address);
    await Vault.deployed();
    console.log('Vault deployed to: ', Vault.address);

    DACRecorder = await DACRecorderFactory.deploy(MetisTokenAddr, Vault.address);
    await DACRecorder.deployed();
    console.log('DACRecorder deployed to: ', DACRecorder.address);

    const Mining = await MiningFactory.deploy(
        MetisTokenAddr,
        DACRecorder.address,
        Distributor.address,
        '18500000000000000',
        Math.round(Date.now() / 1000) + 100,
    );
    await Mining.deployed();
    console.log('Mining deployed to: ', Mining.address);

    const addresses = {
        DACRecorder: DACRecorder.address,
        Mining: Mining.address,
        Vault: Vault.address,
        Distributor: Distributor.address,
    };

    console.log(addresses);

    fs.writeFileSync(`${__dirname}/addresses.json`, JSON.stringify(addresses, null, 4));

    // set Mining contract for Distributor
    await Distributor.setMiningContract(Mining.address, { gasLimit: 24000000 });
    // set Mining contract for DACRecorder
    await DACRecorder.setMiningContract(Mining.address, { gasLimit: 24000000 });
    console.log('Set Mining contract for DACRecorder');
    // set DACRecorder for Vault
    await Vault.setDACRecorder(DACRecorder.address, { gasLimit: 24000000 });
    console.log('Set DACRecorder contract for Vault');
    // set DAC for Mining contract
    await Mining.functions['setDAC'](DACAddr, { gasLimit: 24000000 });
    console.log('Set DAC contract for Mining');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
