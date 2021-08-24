const hre = require("hardhat");

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const Multicall = await hre.ethers.getContractFactory('Multicall');
    const multicall = await Multicall.deploy();
    await multicall.deployed();
    console.log("multicall deployed to:", multicall.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
