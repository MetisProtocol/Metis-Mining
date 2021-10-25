const hre = require('hardhat');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MetisAddress = '0x4200000000000000000000000000000000000006';

    const VaultFactory = await hre.ethers.getContractFactory('TestVault');

    const Vault = await VaultFactory.deploy(MetisAddress);
    await Vault.deployed();
    console.log('TestVault deployed to: ', Vault.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
