require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("@nomicfoundation/hardhat-chai-matchers");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const accounts =
  process.env.NEXT_PRIVATE_KEY !== undefined
    ? [process.env.NEXT_PRIVATE_KEY]
    : [];

module.exports = {
  solidity: "0.8.4",
  defaultNetwork: "hardhat",
  // settings: {
  //   optimizer: {
  //     enabled: true,
  //     runs: 2,
  //   },
  // },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    safuux: {
      url: ``,
      accounts,
    },
    goerli: {
      url: process.env.GOERLI_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
