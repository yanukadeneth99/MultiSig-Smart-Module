const { ethers } = require("hardhat");
const { expect } = require("chai");
const { BigNumber } = require("ethers");

// TODO : Check whether you can perform alot of other functions when you just made the vault
// TODO : Check whether other members can perform admin only functionality
// TODO : Create a vault, add people, disable and re-enable people
// TODO : Create a vault, make someone admin and change back to user
// TODO : Create a vault, create a tx object and do the tx with positive votes
// TODO : Create a vault, create a tx object and fail the tx with a negative vote

// Main Test Function
describe("MultiSig Contract should succeed every test", function () {
  // Main Contract
  let MultiSig;

  // Multi-Sig deployed contract context
  let multisig;

  // Contract Factory
  let MultiSigFactory;

  // Multi-Sig Factory deployed contract context
  let multisigfactory;

  // Test Users
  let owner; // Owner
  let alice; // Test User 1
  let bob; // Test User 2
  let cara; // Test User 2

  // Test Contracts
  let aliceProxyContract;

  // Runing this function before every test case
  beforeEach(async () => {
    // Get all the test accounts
    [owner, alice, bob, cara] = await ethers.getSigners();

    // Deploy Main Contract
    MultiSig = await ethers.getContractFactory("MultiSig");
    multisig = await MultiSig.deploy(owner.address);
    await multisig.deployed();

    // Deploy Contract Factory
    MultiSigFactory = await ethers.getContractFactory("MultiSigFactory");
    multisigfactory = await MultiSigFactory.deploy(
      multisig.address,
      owner.address
    );
    await multisigfactory.deployed();

    // Deploy one test contract Alice from the main deployed contracts
    await multisigfactory.connect(alice).createInstance(alice.address);
    aliceProxyContract = await MultiSig.attach(
      await multisigfactory.getProxy(alice.address)
    );
  });

  // Master contract
  it("Should match the factory address and main contract", async function () {
    expect(await multisigfactory.masterContract()).to.equal(multisig.address);
  });

  // Checking Vault by creating a vault and then confirming all values are updated
  it("Should be able to create a vault with two addresses", async function () {
    // await expect(
    //   aliceProxyContract.setVotesCount(1, 2)
    // ).to.be.revertedWithCustomError(aliceProxyContract, "AddressNotInAVault");
    // Created once
    expect(await aliceProxyContract.createVault([bob.address, cara.address])).to
      .not.reverted;
    expect(await aliceProxyContract.getNoOfVaults()).to.equal(1);
    expect(await aliceProxyContract.getAllVaultCount()).to.deep.equal([1]);

    // Created again
    expect(await aliceProxyContract.createVault([bob.address, cara.address])).to
      .not.reverted;
    expect(await aliceProxyContract.getNoOfVaults()).to.equal(2);
    expect(await aliceProxyContract.getAllVaultCount()).to.deep.equal([1, 2]);

    // Checking Vault Settings
    const { _status, _transCount, _reqVotes } =
      await aliceProxyContract.getVault(1);
    expect(_status).to.equal(0);
    expect(_transCount).to.equal(0);
    expect(_reqVotes).to.equal(1);
  });
});
