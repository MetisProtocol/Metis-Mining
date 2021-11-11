const hre = require('hardhat');
const fs = require('fs');
// const addresses = require('./addresses.json');
// const addresses = require('./addresses2.json');
const addresses = require('./addresses-588.json');

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

    const Distributor = DistributorFactory.attach(addresses.Distributor);
    const Vault = VaultFactory.attach(addresses.Vault);
    const DACRecorder = DACRecorderFactory.attach(addresses.DACRecorder);
    const Mining = MiningFactory.attach(addresses.Mining);
    const DAC = DACFactory.attach(addresses.DAC);

    // set Mining contract for Distributor
    await Distributor.setMiningContract(Mining.address);
    console.log('Set Mining contract for Distributor');
    // set Mining contract for DACRecorder
    await DACRecorder.setMiningContract(Mining.address);
    console.log('Set Mining contract for DACRecorder');
    // set DAC contract for DACRecorder
    await DACRecorder.setMetisDAC(DAC.address);
    console.log('Set DAC contract for DACRecorder');
    // set DACRecorder for Vault
    await Vault.setDACRecorder(DACRecorder.address);
    console.log('Set DACRecorder contract for Vault');
    // set DAC for Mining contract
    await Mining.functions['setDAC'](DAC.address);
    console.log('Set DAC contract for Mining');
    // add Metis pool
    await Mining.add(100, MetisAddress, false,);
    console.log('Add Metis pool');
    // set `ADMIN_ROLE` admin role
    await DAC.setRoleAdmin("0x61646d696e000000000000000000000000000000000000000000000000000000", "0x61646d696e000000000000000000000000000000000000000000000000000000");
    console.log('set `ADMIN_ROLE` admin role');
    // set `MINING_ROLE` admin role
    await DAC.setRoleAdmin("0x6d696e696e670000000000000000000000000000000000000000000000000000", "0x61646d696e000000000000000000000000000000000000000000000000000000");
    console.log('set `MINING_ROLE` admin role');
    // set `WHITELIST_ROLE` admin role
    await DAC.setRoleAdmin("0x77686974656c6973740000000000000000000000000000000000000000000000", "0x61646d696e000000000000000000000000000000000000000000000000000000");
    console.log('set `WHITELIST_ROLE` admin role');
    // grant `MINING_ROLE` to `MiningAddr`
    await DAC.grantRole("0x6d696e696e670000000000000000000000000000000000000000000000000000", Mining.address);
    console.log('grant `MINING_ROLE` to `MiningAddr`')
    // grant `WHITELIST_ROLE` to `WhitelistAccount`
    await DAC.grantRole("0x77686974656c6973740000000000000000000000000000000000000000000000", '0xFe7A0Ea1662A75771b0122853C4aEaCA7CE55460')
    console.log('grant `WHITELIST_ROLE` to `WhitelistAccount`')
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
