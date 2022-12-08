const { ethers } = require("hardhat");
const { expect } = require("chai");
const { BigNumber } = require("ethers");

// TODO : Check whether you can perform alot of other functions when you just made the vault
// TODO : Check whether other members can perform admin only functionality
// TODO : Create a vault, add people, disable and re-enable people
// TODO : Create a vault, make someone admin and change back to user
// TODO : Create a vault, create a tx object and do the tx with positive votes
// TODO : Create a vault, create a tx object and fail the tx with a negative vote
// TODO : Stress test every function with 'it's

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
  let cara; // Test User 3
  let john; // Test User 4

  // Test Contracts
  let aliceProxyContract;

  // Runing this function before every test case
  beforeEach(async () => {
    // Get all the test accounts
    [owner, alice, bob, cara, john] = await ethers.getSigners();

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

  describe("All owner functionality should work", function () {
    // Deploying all and creating a vault before every function
    beforeEach(async () => {
      await aliceProxyContract
        .connect(owner)
        .createVault([cara.address, bob.address]);
    });

    it("Create Vault should work", async () => {
      expect(await aliceProxyContract.createVault([john.address])).to.not
        .reverted;
      expect(await aliceProxyContract.getNoOfVaults()).to.equal(2);
      expect(await aliceProxyContract.getAllVaultCount()).to.deep.equal([1, 2]);
    });

    it("Create Transaction should work", async () => {
      await expect(
        aliceProxyContract.createTransaction(1, cara.address, 2, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      await expect(aliceProxyContract.createTransaction(0, cara.address, 2, []))
        .to.not.be.reverted;

      await expect(
        aliceProxyContract.getTransaction(3, 33)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      await expect(
        aliceProxyContract.getTransaction(0, 33)
      ).to.be.revertedWithCustomError(
        aliceProxyContract,
        "InvalidTransactionID"
      );

      const { _to, _amount, _done, _posVoteCount, _status } =
        await aliceProxyContract.getTransaction(0, 0);

      expect(_to).to.equal(cara.address);
      expect(_amount).to.equal(2);
      expect(_done).to.be.false;
      expect(_posVoteCount).to.equal(0);
      expect(_status).to.equal(0);
    });

    it("Add User should work", async () => {
      await expect(
        aliceProxyContract.connect(john).getAllVaultCount()
      ).to.be.revertedWithCustomError(aliceProxyContract, "AddressNotInAVault");
      await expect(
        aliceProxyContract.connect(bob).addUsers(1, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      await expect(aliceProxyContract.connect(owner).addUsers(0, [])).to.not.be
        .reverted;
      await expect(
        aliceProxyContract.connect(owner).addUsers(0, [john.address])
      ).to.not.be.reverted;
      expect(
        await aliceProxyContract.connect(john).getAllVaultCount()
      ).to.deep.equal([1]);
    });

    it("Should make a member as owner", async () => {
      {
        // Since I know the 0 index is Cara
        const { _allusers } = await aliceProxyContract.getVault(1);
        expect(_allusers[0].person).to.equal(cara.address);
        expect(_allusers[0].position).to.equal(1);
      }

      await expect(
        aliceProxyContract.connect(bob).makeOwner(2, cara.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      await expect(
        aliceProxyContract.connect(bob).makeOwner(0, cara.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");

      await aliceProxyContract.makeOwner(0, cara.address);

      // Since I know the 0 index is Cara
      const { _allusers } = await aliceProxyContract.getVault(1);
      expect(_allusers[0].person).to.equal(cara.address);
      expect(_allusers[0].position).to.equal(0);
    });

    it("Should set votes count", async () => {
      {
        // Since I know the 0 index is Cara
        const { _reqVotes } = await aliceProxyContract.getVault(1);
        expect(_reqVotes).to.equal(1);
      }

      await expect(
        aliceProxyContract.connect(bob).setVotesCount(2, 2)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      await expect(
        aliceProxyContract.connect(bob).setVotesCount(0, 2)
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");
      await expect(
        aliceProxyContract.setVotesCount(0, 3)
      ).to.to.revertedWithCustomError(aliceProxyContract, "VoteCountTooHigh");

      expect(await aliceProxyContract.makeOwner(0, cara.address)).to.not.be
        .reverted;

      expect(await aliceProxyContract.setVotesCount(0, 2)).to.not.be.reverted;

      const { _reqVotes } = await aliceProxyContract.getVault(1);
      expect(_reqVotes).to.equal(2);
    });
  });
});
