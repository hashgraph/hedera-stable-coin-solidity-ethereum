const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const web3 = require("web3");

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

const StableCoin = contract.fromArtifact("StableCoin");

describe("StableCoin", () => {
  this.contract = null;

  const [squidward, skynet, rand_paul, nimdok] = accounts; // get accounts from test utils

  // Contract Information
  const name = "Bikini Bottom Bux";
  const symbol = "~*~";
  const decimals = 18;
  const totalSupply = (300 * 10) ^ decimals; // 300 BBB in circulation
  const owner = skynet;
  const supplyManager = squidward;
  const assetProtectionManager = rand_paul;
  const frozenRole = web3.utils.asciiToHex("FROZEN");
  const kycPassedRole = web3.utils.asciiToHex("KYC_PASSED");

  beforeEach(async () => {
    this.contract = await StableCoin.new(
      name,
      symbol,
      decimals,
      totalSupply,
      supplyManager,
      assetProtectionManager,
      { from: owner }
    );
  });

  it("initializes with expected state", async () => {
    expect((await this.contract.owner()) == owner);
    expect((await this.contract.supplyManager()) == supplyManager);
    expect(
      (await this.contract.assetProtectionManager()) == assetProtectionManager
    );
    expect(
      (await this.contract.balanceOf(supplyManager)) ==
        (await this.contract.totalSupply())
    );
    expect((await this.contract.name()) == name);
    expect((await this.contract.symbol()) == symbol);
    expect((await this.contract.decimals()) == decimals);
    expect((await this.contract.totalSupply()) == totalSupply);
    expect(await this.contract.isKycPassed(owner));
    expect(await this.contract.isKycPassed(supplyManager));
    expect(await this.contract.isKycPassed(assetProtectionManager));
    expect((await this.contract.proposedOwner()) == constants.ZERO_ADDRESS);
    expect(
      (await this.contract.getRoleMemberCount(frozenRole, { from: owner })) == 0
    );
    expect(
      (await this.contract.getRoleMemberCount(kycPassedRole, {
        from: owner,
      })) == 3
    );
  });

  it("can change owner", async () => {
    const proposedOwner = nimdok; // oh no

    // Only owner can propose owner
    expectRevert(
      this.contract.proposeOwner(nimdok, { from: nimdok }),
      "Only the owner can call this function."
    );

    // Can't claim ownership if not proposed
    expectRevert(
      this.contract.claimOwnership({ from: nimdok }),
      "Only the proposed owner can call this function."
    );

    // Owner can propose ownership
    const proposeReceipt = await this.contract.proposeOwner(proposedOwner, {
      from: owner,
    });

    // emits ProposeOwner
    expectEvent(proposeReceipt, "ProposeOwner", { proposedOwner: nimdok });

    // Proposed owner can claim contract
    const claimReceipt = await this.contract.claimOwnership({ from: nimdok });

    // emits ClaimOwnership
    expectEvent(claimReceipt, "ClaimOwnership", { newOwner: nimdok });

    // new owner is proposed owner, has KYC passed, not frozen
    expect(this.contract.owner() == nimdok);
    expect(this.contract.isKycPassed(nimdok));
    expect(this.contract.isFrozen(nimdok) == false);
  });

  it("can change supply manager", async () => {
      expectRevert(
          this.contract.changeSupplyManager(nimdok, { from: nimdok }),
          "Only the owner can call this function"
      );

      const changeReceipt = await this.contract.changeSupplyManager(nimdok, { from: owner });
      
      expectEvent(changeReceipt, "ChangeSupplyManager", { newSupplyManager: nimdok });
      expect(this.contract.supplyManager() == nimdok);
  });

  it("can change asset protection manager", async () => {
      expectRevert(
          this.contract.changeAssetProtectionManager(nimdok, { from: nimdok }),
          "Only the owner can call this function."
      );

      const changeReceipt = await this.contract.changeAssetProtectionManager(nimdok, { from: owner });
      
      expectEvent(changeReceipt, "ChangeAssetProtectionManager", { newAssetProtectionManager: nimdok });
      expect(this.contract.assetProtectionManager() == nimdok);
  });

  it.todo("can freeze accounts");

  it.todo("can set KYC for accounts");

  it.todo("is transferrable");
  
  it.todo("is mintable");

  it.todo("is burnable");

  it.todo("can wipe accounts");

  it.todo("is delegable");

  it.todo("takes snapshots");

  afterEach(() => {
    this.contract = null;
  });
});
