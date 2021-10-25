const hre = require('hardhat');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const MultiERC20SenderFactory = await hre.ethers.getContractFactory('MultiERC20Sender');

    const Sender = await MultiERC20SenderFactory.deploy();
    await Sender.deployed();
    console.log('Sender deployed to: ', Sender.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
