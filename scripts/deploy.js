const hre = require("hardhat");
const fs = require("fs-extra");
const { constants } = require("ethers");

// Main Function
const main = async () => {
  // Get all deployers
  const [deployer] = await ethers.getSigners();
  console.log("Deployer Address: ", deployer.address);
  const hyperverseAdmin = deployer.address;

  // Deploy Base Contract
  const MultiSig = await hre.ethers.getContractFactory("MultiSig");
  const multisig = await MultiSig.deploy(hyperverseAdmin);
  await multisig.deployed();
  console.log("MultiSig Contract deployed to: ", multisig.address);

  // Deploy Factory
  const MultiSigFactory = await hre.ethers.getContractFactory(
    "MultiSigFactory"
  );
  const multisigfactory = await MultiSigFactory.deploy(
    multisig.address,
    hyperverseAdmin
  );
  await multisigfactory.deployed();

  // Read from JSON
  const env = JSON.parse(fs.readFileSync("contracts.json").toString());
  env[hre.network.name] = env[hre.network.name] || {};
  env[hre.network.name].testnet = env[hre.network.name].testnet || {};

  env[hre.network.name].testnet.contractAddress = multisig.address;
  env[hre.network.name].testnet.factoryAddress = multisigfactory.address;

  // Save contract addresses back to file
  fs.writeJsonSync("contracts.json", env, { spaces: 2 });

  // Deploy default tenant
  let proxyAddress = constants.AddressZero;
  await multisigfactory.createInstance(deployer.address);
  while (proxyAddress === constants.AddressZero) {
    proxyAddress = await multisigfactory.getProxy(deployer.address);
  }
};

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
};

runMain();
