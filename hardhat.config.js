require("@nomiclabs/hardhat-waffle");
require("@metis.io/hardhat-mvm");
const { config } = require('dotenv');
const { resolve } = require('path');

config({ path: resolve(__dirname, "./.env") });

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

let mnemonic;
if (!process.env.MNEMONIC) {
  throw new Error("Please set your MNEMONIC in a .env file");
} else {
  mnemonic = process.env.MNEMONIC;
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.12",
  networks: {
    hardhat: {
    },
    metis: {
      url: 'https://rocketfuel.metis.io/?owner=435',
      accounts: {
        mnemonic,
      },
      gasPrice: 15000000,
      ovm: true
    },
  },
  ovm: {
    solcVersion: '0.6.12', // Currently, we only support 0.5.16, 0.6.12, and 0.7.6 of the Solidity compiler           
    optimizer: true,
    runs: 20
  },
};

