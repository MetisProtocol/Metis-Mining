const hre = require('hardhat');
const fs = require('fs');
const addresses = require('./addresses.json');
const { users } = require('./invited-users.js');

async function main() {
    const accounts = await ethers.getSigners();
    const signer = accounts[0].address;
    console.log('signer:', signer);

    const DACFactory = await hre.ethers.getContractFactory('DAC');

    const DAC = DACFactory.attach(addresses.DAC);
    
    await DAC.addInvitedUsers(users, { gasLimit: 1500000 });
    console.log('added: ', users);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
