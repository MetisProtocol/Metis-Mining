const hre = require('hardhat');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MulticallFactory = await hre.ethers.getContractFactory('Multicall');

    const Multicall = await MulticallFactory.deploy();
    await Multicall.deployed();
    console.log('Multicall deployed to: ', Multicall.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
