const hre = require("hardhat");

async function main() {
  const accounts = await ethers.getSigners();
  const signer = accounts[0].address;
  console.log('signer:', signer);

  const DOG = await hre.ethers.getContractFactory('DOG');
  const dog = await DOG.deploy();
  await dog.deployed();
  console.log("DOG deployed to:", dog.address);

  const DOG2 = await hre.ethers.getContractFactory('DOG2');
  const dog2 = await DOG2.deploy();
  await dog2.deployed();
  console.log("DOG2 deployed to:", dog2.address);

  const balanceOfDOG = await dog.functions.balanceOf(signer);
  const balanceOfDO2 = await dog2.functions.balanceOf(signer);
  console.log('balance of DOG:', balanceOfDOG);
  console.log('balance of DOG2:', balanceOfDO2);

  const Factory = await hre.ethers.getContractFactory('UniswapV2Factory');
  const factory = await Factory.deploy(signer);
  await factory.deployed();
  console.log("Factory depolyed to:", factory.address);
  
  const Router = await hre.ethers.getContractFactory('UniswapV2Router02');
  const router = await Router.deploy(factory.address, "0x4200000000000000000000000000000000000006");
  await router.deployed();
  console.log("Router depolyed to:", router.address);

  await dog.functions['approve'](router.address, hre.ethers.constants.MaxUint256, { gasLimit: 24000000 });
  console.log('Approved router to use DOG');
  await dog2.functions['approve'](router.address, hre.ethers.constants.MaxUint256, { gasLimit: 24000000 });
  console.log('Approved router to use DOG2');

  // add liquidity
  console.log('Adding Liquidity with DOG & DOG2...');
  await router.functions['addLiquidity'](
    dog.address,
    dog2.address,
    '10000000000000000000000',
    '10000000000000000000000',
    '10000000000000000000000',
    '10000000000000000000000',
    signer,
    Math.round(Date.now() / 1000) + 10000,
  );
  console.log('Add liquidity done');
  console.log('Validating balance of DOG...');
  const newBalanceOfDOG = await dog.functions.balanceOf(signer);
  const newBalanceOfDO2 = await dog2.functions.balanceOf(signer);
  console.log('new balance of DOG:', newBalanceOfDOG);
  console.log('new balance of DOG2:', newBalanceOfDO2);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
