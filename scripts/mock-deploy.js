const hre = require('hardhat');
const fs = require('fs');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MockMetisTokenFactory = await hre.ethers.getContractFactory('MockMetisToken');
    const MockDACFactory = await hre.ethers.getContractFactory('MockDAC');
    const VaultFactory = await hre.ethers.getContractFactory('Vault');
    const MiningFactory = await hre.ethers.getContractFactory('Mining');
    // (10000000 * 1e18)
    const MockMetis = await MockMetisTokenFactory.deploy([signer], '10000000000000000000000000');
    await MockMetis.deployed();
    console.log('MockMetis deployed to: ', MockMetis.address);

    const Vault = await VaultFactory.deploy(MockMetis.address);
    await Vault.deployed();
    console.log('Vault deployed to: ', Vault.address);

    const Mining = await MiningFactory.deploy(
        MockMetis.address,
        Vault.address,
        '18500000000000000',
        Math.round(Date.now() / 1000) + 100,
    );
    await Mining.deployed();
    console.log('Mining deployed to: ', Mining.address);

    const MockDAC = await MockDACFactory.deploy(
        Mining.address,
        MockMetis.address,
    );
    await MockDAC.deployed();
    console.log('MockDAC deployed to: ', MockDAC.address);

    const addresses = {
        MockMetis: MockMetis.address,
        MockDAC: MockDAC.address,
        Mining: Mining.address,
        Vault: Vault.address,
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
