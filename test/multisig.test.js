const { ethers } = require("hardhat");
const { expect } = require("chai");
const { BigNumber } = require("ethers");

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

  it("Should match the factory address and main contract", async function () {
    expect(await multisigfactory.masterContract()).to.equal(multisig.address);
  });

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
    const { _status, _votesReq } = await aliceProxyContract.getVault(1);
    expect(_status).to.equal(0);
    expect(_votesReq).to.equal(1);
  });

  describe("Main Contract functionality checks", function () {
    // Deploying all and creating a vault before every function
    beforeEach(async () => {
      await aliceProxyContract
        .connect(owner)
        .createVault([cara.address, bob.address]);
    });

    it("Should create a vault", async () => {
      // Create Vaults
      expect(await aliceProxyContract.createVault([john.address])).to.not
        .reverted;

      // Confirmations
      expect(await aliceProxyContract.getNoOfVaults()).to.equal(2);
      expect(await aliceProxyContract.getAllVaultCount()).to.deep.equal([1, 2]);
    });

    it("Should create a transaction", async () => {
      // Transaction with wrong Vault index
      await expect(
        aliceProxyContract.transactionCreate(1, cara.address, 2, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");

      // Create Transaction
      await expect(aliceProxyContract.transactionCreate(0, cara.address, 2, []))
        .to.not.be.reverted;

      // Calling Transaction data with wrong Vault index
      await expect(
        aliceProxyContract.getTransaction(3, 33)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");

      // Calling Transaction data with wrong transaction index
      await expect(
        aliceProxyContract.getTransaction(0, 33)
      ).to.be.revertedWithCustomError(
        aliceProxyContract,
        "InvalidTransactionID"
      );

      // Getting Transaction Data
      const { _to, _amount, _done, votes } =
        await aliceProxyContract.getTransaction(0, 0);

      // Confirming
      expect(_to).to.equal(cara.address);
      expect(_amount).to.equal(2);
      expect(_done).to.be.false;
      expect(votes).to.equal(0);
    });

    it("Should add a user", async () => {
      // Checking user not in a vault
      await expect(
        aliceProxyContract.connect(john).getAllVaultCount()
      ).to.be.revertedWithCustomError(aliceProxyContract, "AddressNotInAVault");

      // Adding user to a vault that doesn't exist
      await expect(
        aliceProxyContract.connect(bob).addUsers(1, [john.address])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");

      // Null address passing
      await expect(
        aliceProxyContract.connect(owner).addUsers(0, [])
      ).to.be.revertedWith("No address added");

      // Adding user
      await expect(
        aliceProxyContract.connect(owner).addUsers(0, [john.address])
      ).to.not.be.reverted;

      // Confirmation
      expect(
        await aliceProxyContract.connect(john).getAllVaultCount()
      ).to.deep.equal([1]);

      // Adding the same person again
      await expect(
        aliceProxyContract.connect(owner).addUsers(0, [john.address])
      ).to.be.revertedWithCustomError(aliceProxyContract, "UserAlreadyExists");
    });

    it("Should make a member as owner", async () => {
      // Adding user
      await expect(
        aliceProxyContract.connect(owner).addUsers(0, [john.address])
      ).to.not.be.reverted;

      // Passing invalid vault index
      await expect(
        aliceProxyContract.connect(owner).makeOwner(2, john.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");

      // Checking function with a non-admin user
      await expect(
        aliceProxyContract.connect(john).makeOwner(0, john.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "Unauthorized");

      // Making Cara an owner
      await aliceProxyContract.makeOwner(0, john.address);
    });

    xit("Should set votes count", async () => {
      // Initial Confirmation
      {
        const { _reqVotes } = await aliceProxyContract.getVault(1);
        // Since I know the 0 index is Cara
        expect(_reqVotes).to.equal(1);
      }

      // Passing invalid vault
      await expect(
        aliceProxyContract.connect(bob).setVotesCount(2, 2)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      // Checking with user account
      await expect(
        aliceProxyContract.connect(bob).setVotesCount(0, 2)
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");
      // Passing in a vote more than the owner count of the vault
      await expect(
        aliceProxyContract.setVotesCount(0, 3)
      ).to.to.revertedWithCustomError(aliceProxyContract, "VoteCountTooHigh");

      // Making a user owner
      expect(await aliceProxyContract.makeOwner(0, cara.address)).to.not.be
        .reverted;

      // Setting the votes count to 2
      expect(await aliceProxyContract.connect(cara).setVotesCount(0, 2)).to.not
        .be.reverted;

      // Confirmation
      const { _reqVotes } = await aliceProxyContract.getVault(1);
      expect(_reqVotes).to.equal(2);
    });

    xit("Should create a transaction and edit it", async () => {
      // Creating transaction
      await expect(aliceProxyContract.createTransaction(0, cara.address, 2, []))
        .to.not.be.reverted;

      // Initial Confirmation
      {
        const { _to, _amount } = await aliceProxyContract.getTransaction(0, 0);

        expect(_to).to.equal(cara.address);
        expect(_amount).to.equal(2);
      }

      // Passing in a fake vault index
      await expect(
        aliceProxyContract.editTransaction(2, 4, john.address, 5, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      // Passing in a fake transaction index
      await expect(
        aliceProxyContract.editTransaction(0, 4, john.address, 5, [])
      ).to.be.revertedWithCustomError(
        aliceProxyContract,
        "InvalidTransactionID"
      );

      // Editing Transaction
      expect(
        await aliceProxyContract.editTransaction(0, 0, john.address, 5, [])
      ).to.not.be.reverted;

      // Confirmation
      const { _to, _amount } = await aliceProxyContract.getTransaction(0, 0);
      expect(_to).to.equal(john.address);
      expect(_amount).to.equal(5);
    });

    xit("Should be able to perform a transaction", async () => {
      // Saving Caras current balance
      const _caraBalance = await cara.getBalance();

      // Creating a transaction
      await expect(
        aliceProxyContract.createTransaction(
          0,
          cara.address,
          ethers.utils.parseEther("2"),
          []
        )
      ).to.not.be.reverted;

      // Transferring money from owner to vault
      await aliceProxyContract.transferMoney(1, {
        value: ethers.utils.parseEther("5"),
      });

      // Confirming the vault contract has 5 Ether
      expect(
        await aliceProxyContract.provider.getBalance(aliceProxyContract.address)
      ).to.equal(ethers.utils.parseEther("5"));

      // Confirmation using the Vault Object is done in another test

      // Passing a fake vault index
      await expect(
        aliceProxyContract.performTransaction(5, 12)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      // Passing a fake transaction index
      await expect(
        aliceProxyContract.performTransaction(0, 12)
      ).to.be.revertedWithCustomError(
        aliceProxyContract,
        "InvalidTransactionID"
      );

      // Attempting to do the transaction without votes
      await expect(
        aliceProxyContract.performTransaction(0, 0)
      ).to.be.revertedWith("Not enough Votes");

      // Owner votes yes
      expect(await aliceProxyContract.castVote(0, 0, true)).to.not.be.reverted;

      // Confirming data about the transaction object
      const { _posVoteCount, _amount } =
        await aliceProxyContract.getTransaction(0, 0);
      expect(_posVoteCount).to.equal(1);
      expect(_amount).to.equal(ethers.utils.parseEther("2"));

      // Performing the transaction from the vault to Cara
      await expect(aliceProxyContract.performTransaction(0, 0)).to.not.be
        .reverted;

      // Confirmations
      expect(
        await aliceProxyContract.provider.getBalance(aliceProxyContract.address)
      ).to.equal(ethers.utils.parseEther("3"));
      expect(await cara.provider.getBalance(cara.address)).to.equal(
        ethers.utils.parseEther("2").add(_caraBalance)
      );
    });

    xit("Should be able to cast a vote", async () => {
      // Transactions
      await expect(
        aliceProxyContract.createTransaction(
          0,
          cara.address,
          ethers.utils.parseEther("2"),
          []
        )
      ).to.not.be.reverted;
      await expect(
        aliceProxyContract.createTransaction(
          0,
          john.address,
          ethers.utils.parseEther("5"),
          []
        )
      ).to.not.be.reverted;

      // Checking wrong vault index
      await expect(
        aliceProxyContract.castVote(2, 5, true)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      // Checking wrong transactionId
      await expect(
        aliceProxyContract.castVote(0, 5, true)
      ).to.be.revertedWithCustomError(
        aliceProxyContract,
        "InvalidTransactionID"
      );

      // Casting positive vote
      await expect(aliceProxyContract.castVote(0, 0, true)).to.not.be.reverted;

      // Casting positive vote again
      await expect(
        aliceProxyContract.castVote(0, 0, true)
      ).to.be.revertedWithCustomError(aliceProxyContract, "SameVote");

      {
        const { _posVoteCount } = await aliceProxyContract.getTransaction(0, 0);
        expect(_posVoteCount).to.equal(1);
      }

      // Change vote to No
      await expect(aliceProxyContract.castVote(0, 0, false)).to.not.be.reverted;

      {
        const { _posVoteCount } = await aliceProxyContract.getTransaction(0, 0);
        expect(_posVoteCount).to.equal(0);
      }

      // Casting Vote with non admin
      await expect(
        aliceProxyContract.connect(cara).castVote(0, 1, true)
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");
    });

    xit("Should be able to enabled a vault", async () => {
      // Wrong Vault index
      await expect(
        aliceProxyContract.enableVault(22)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");

      // Cant Enable an Already enbled Vault
      await expect(
        aliceProxyContract.enableVault(0)
      ).to.be.revertedWithCustomError(aliceProxyContract, "AlreadyActiveVault");

      // Disable Vault with wrong vault index
      await expect(
        aliceProxyContract.disableVault(22)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");

      // Disable Vault
      expect(await aliceProxyContract.disableVault(0)).to.not.be.reverted;

      // Confirm that the Vault is disabled
      {
        const { _status } = await aliceProxyContract.getVault(1);
        expect(_status).to.equal(1);
      }

      // Now enable vault back
      await expect(aliceProxyContract.enableVault(0)).to.not.be.reverted;

      // Confirm the Vault Status
      {
        const { _status } = await aliceProxyContract.getVault(1);
        expect(_status).to.equal(0);
      }
    });

    xit("Should be able to enable a user", async () => {
      // Wrong Vault index
      await expect(
        aliceProxyContract.enableUser(22, cara.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");

      // Cant Enable an Already enbled User
      await expect(
        aliceProxyContract.enableUser(0, cara.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "AlreadyEnabledUser");

      // Disable User with wrong address
      await expect(
        aliceProxyContract.disableUser(0, john.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "UserNotFound");

      // Disable User Cara
      expect(await aliceProxyContract.disableUser(0, cara.address)).to.not.be
        .reverted;

      // Confirm that the User is disabled
      {
        const { _allusers } = await aliceProxyContract.getVault(1);
        // Since I know cara is in position 0
        expect(_allusers[0].position).to.equal(0);
      }

      // Now enable the user back
      await expect(aliceProxyContract.enableUser(0, cara.address)).to.not.be
        .reverted;

      // Confirm the User Status
      {
        const { _allusers } = await aliceProxyContract.getVault(1);
        // Since I know cara is in position 0
        expect(_allusers[0].position).to.equal(1);
      }
    });

    xit("Should not be able to interaction with the vault once user is disabled", async () => {
      // Confirm Cara isnt an owner
      {
        const { _allusers } = await aliceProxyContract.getVault(1);
        expect(_allusers[0].position).to.not.equal(2);
      }

      // Make User Cara an admin
      expect(await aliceProxyContract.makeOwner(0, cara.address)).to.not.be
        .reverted;

      // Confirm Cara is an owner
      {
        const { _allusers } = await aliceProxyContract.getVault(1);
        expect(_allusers[0].position).to.equal(2);
      }

      // Disable User Cara
      expect(await aliceProxyContract.disableUser(0, cara.address)).to.not.be
        .reverted;

      // Should not be able to create Transaction
      await expect(
        aliceProxyContract
          .connect(cara)
          .createTransaction(0, john.address, 2, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "Unauthorized");

      // Should not be able to make another person owner
      await expect(
        aliceProxyContract.connect(cara).makeOwner(0, bob.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");

      // Should not be able to add users
      await expect(
        aliceProxyContract.connect(cara).addUsers(0, [john.address])
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");

      // Should not be bale to setVotesCount
      await expect(
        aliceProxyContract.connect(cara).setVotesCount(0, 5)
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");

      // Should not be able to edit transactions
      await aliceProxyContract.createTransaction(0, john.address, 5, []);
      await expect(
        aliceProxyContract
          .connect(cara)
          .editTransaction(0, 0, cara.address, 20, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "Unauthorized");

      // Should not be able to cast votes
      await expect(
        aliceProxyContract.connect(cara).addUsers(0, [john.address])
      ).to.be.revertedWithCustomError(aliceProxyContract, "NotAnOwner");
    });

    xit("Should be able to disable and re-enable Vault", async () => {
      // Confirm Vault is not disabled
      {
        const { _status } = await aliceProxyContract.getVault(1);
        expect(_status).to.not.equal(1);
      }

      // Disable the Vault
      expect(await aliceProxyContract.disableVault(0)).to.not.be.reverted;

      // Confirm Vault is Disabled
      {
        const { _status } = await aliceProxyContract.getVault(1);
        expect(_status).to.equal(1);
      }

      // Should not be able to create Transaction
      await expect(
        aliceProxyContract.createTransaction(0, john.address, 2, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Should not be able to add users
      await expect(
        aliceProxyContract.addUsers(0, [john.address])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Should not be able to make a member an owner
      await expect(
        aliceProxyContract.makeOwner(0, cara.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Should not be able to set Votes Count
      await expect(
        aliceProxyContract.setVotesCount(0, cara.address)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Should not be able to perform transaction
      await aliceProxyContract.enableVault(0);
      // Confirm Vault is Enabled
      {
        const { _status } = await aliceProxyContract.getVault(1);
        expect(_status).to.equal(0);
      }
      // Make a Transaction
      await aliceProxyContract
        .connect(bob)
        .createTransaction(0, john.address, 55, []);
      // Disable Vault again
      await aliceProxyContract.disableVault(0);
      // Confirm Vault is Disabled
      {
        const { _status } = await aliceProxyContract.getVault(1);
        expect(_status).to.equal(1);
      }
      await expect(
        aliceProxyContract
          .connect(bob)
          .editTransaction(0, 0, cara.address, 55, [])
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Should not be able to transfer money
      await expect(
        aliceProxyContract.transferMoney(1, {
          value: ethers.utils.parseEther("22"),
        })
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Should not be able to perform Transactions
      await expect(
        aliceProxyContract.performTransaction(0, 0)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Should not be able to cast votes
      await expect(
        aliceProxyContract.castVote(0, 0, true)
      ).to.be.revertedWithCustomError(aliceProxyContract, "InActiveVault");

      // Enabling User, Disabling User and Enabling Vault works
    });
  });

  xdescribe("Checking Getter Functions", function () {
    // Deploying all and creating a vault before every function
    beforeEach(async () => {
      await aliceProxyContract
        .connect(owner)
        .createVault([cara.address, bob.address]);
    });

    it("Getting all vault count should work", async () => {
      // Initial Confirm
      expect(await aliceProxyContract.getAllVaultCount()).to.deep.equal([1]);

      // Creating Vaults
      await aliceProxyContract.createVault([john.address]);
      await aliceProxyContract.createVault([bob.address]);

      // Cannot add yourself
      await expect(
        aliceProxyContract.createVault([owner.address])
      ).to.be.revertedWithCustomError(aliceProxyContract, "CannotAddSelf");

      // Confirmation
      expect(await aliceProxyContract.getAllVaultCount()).to.deep.equal([
        1, 2, 3,
      ]);

      // Create using another person
      expect(
        await aliceProxyContract.connect(cara).getAllVaultCount()
      ).to.deep.equal([1]);

      // Create two more vaults with cara
      await aliceProxyContract.connect(cara).createVault([john.address]);
      await aliceProxyContract.connect(cara).createVault([bob.address]);

      // Confirmation for Cara
      expect(
        await aliceProxyContract.connect(cara).getAllVaultCount()
      ).to.deep.equal([1, 4, 5]);
    });

    // Get Transaction and Get Vault works as it's used for the above tests

    it("Getting No of Total Vaults should work", async () => {
      // Initial Confirm
      expect(await aliceProxyContract.getNoOfVaults()).to.equal(1);

      // Creating Vaults
      await aliceProxyContract.createVault([john.address]);
      await aliceProxyContract.createVault([bob.address]);

      // Confirm
      expect(await aliceProxyContract.getNoOfVaults()).to.equal(3);
    });
  });

  xdescribe("Transferring Money into Vaults", function () {
    // Deploying all and creating a vault before every function
    beforeEach(async () => {
      await aliceProxyContract
        .connect(owner)
        .createVault([cara.address, bob.address]);
    });

    it("Should be able to transfer money into vaults without confirmation address", async () => {
      // Initial Confirm
      {
        const { _money } = await aliceProxyContract.getVault(1);
        expect(_money).to.equal(0);
      }

      // Transfer some money to the Vault 1
      await aliceProxyContract.transferMoney(1, {
        value: ethers.utils.parseEther("22"),
      });

      // Confirmation
      const { _money } = await aliceProxyContract.getVault(1);
      expect(_money).to.equal(ethers.utils.parseEther("22"));

      // Transfer to vault that does not exist
      await expect(
        aliceProxyContract.transferMoney(22, {
          value: ethers.utils.parseEther("50"),
        })
      ).to.be.revertedWithCustomError(aliceProxyContract, "InvalidVault");
      {
        const { _money } = await aliceProxyContract.getVault(1);
        expect(_money).to.not.equal(ethers.utils.parseEther("72"));
      }
    });

    it("Should be able to transfer money into vaults with confirmation address", async () => {
      // Initial Confirm
      {
        const { _money } = await aliceProxyContract.getVault(1);
        expect(_money).to.equal(0);
      }

      // Transfer some money to the Vault 1
      await aliceProxyContract.transferMoneyWithProof(1, owner.address, {
        value: ethers.utils.parseEther("50"),
      });

      // Confirmation
      const { _money } = await aliceProxyContract.getVault(1);
      expect(_money).to.equal(ethers.utils.parseEther("50"));

      // Transfer to vault that does not have the owner address passed
      await expect(
        aliceProxyContract.transferMoneyWithProof(1, john.address, {
          value: ethers.utils.parseEther("50"),
        })
      ).to.be.revertedWithCustomError(aliceProxyContract, "AddressNotInAVault");
      {
        const { _money } = await aliceProxyContract.getVault(1);
        expect(_money).to.not.equal(ethers.utils.parseEther("100"));
      }
    });
  });
});
