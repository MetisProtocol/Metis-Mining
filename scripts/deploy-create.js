const hre = require("hardhat");

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const Creator = await hre.ethers.getContractFactory('CreateERC20');
    const creator = await Creator.deploy();
    await creator.deployed();
    console.log("creator deployed to:", creator.address);

    const createResult = await creator.functions['create'](
        'Test template ERC20 Token',
        'TestERC20',
        '10000000000000000000000',
    );
    console.log('create result of ERC20', createResult);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
