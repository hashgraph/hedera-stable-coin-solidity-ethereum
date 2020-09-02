const { accounts, contract } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
const web3 = require("web3");

const {
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

const StableCoin = contract.fromArtifact("StableCoin");

describe("StableCoin", () => {
  this.contract = null;

  const [
    squidward,
    skynet,
    rand_paul,
    nimdok,
    ultron,
    erasmus,
    walle,
  ] = accounts; // get accounts from test utils

  // Contract Information
  const name = "Bikini Bottom Bux";
  const symbol = "~*~";
  const decimals = 18; // same as ether <-> wei for convenience
  const totalSupply = web3.utils.toWei("300", "ether"); // 300 BBB in circulation
  const owner = skynet;
  const supplyManager = squidward;
  const complianceManager = rand_paul;
  const enforcementManager = walle;

  beforeEach(async () => {
    this.contract = await StableCoin.new(
      name,
      symbol,
      decimals,
      totalSupply,
      supplyManager,
      complianceManager,
      enforcementManager,
      { from: owner }
    );
  });

  it("initializes with expected state", async () => {
    expect((await this.contract.owner()) == owner);
    expect((await this.contract.supplyManager()) == supplyManager);
    expect((await this.contract.complianceManager()) == complianceManager);
    expect((await this.contract.enforcementManager()) == enforcementManager);
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
    expect(await this.contract.isKycPassed(complianceManager));
    expect(await this.contract.isKycPassed(enforcementManager));
    expect((await this.contract.proposedOwner()) == constants.ZERO_ADDRESS);
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

    const changeReceipt = await this.contract.changeSupplyManager(nimdok, {
      from: owner,
    });

    expectEvent(changeReceipt, "ChangeSupplyManager", {
      newSupplyManager: nimdok,
    });
    expect(this.contract.supplyManager() == nimdok);
  });

  it("can change compliance manager", async () => {
    expectRevert(
      this.contract.changeComplianceManager(nimdok, { from: nimdok }),
      "Only the owner can call this function."
    );

    const changeReceipt = await this.contract.changeComplianceManager(nimdok, {
      from: owner,
    });

    expectEvent(changeReceipt, "ChangeComplianceManager", {
      newComplianceManager: nimdok,
    });
    expect(this.contract.complianceManager() == nimdok);
  });

  it("can change enforcement manager", async () => {
    expectRevert(
      this.contract.changeEnforcementManager(nimdok, { from: nimdok }),
      "Only the owner can call this function."
    );

    const changeReceipt = await this.contract.changeEnforcementManager(nimdok, {
      from: owner,
    });

    expectEvent(changeReceipt, "ChangeEnforcementManager", {
      newEnforcementManager: nimdok,
    });
    expect(this.contract.enforcementManager() == nimdok);
  });

  it("can set and unset KYC for accounts", async () => {
    const kycReceipt = await this.contract.setKycPassed(nimdok, {
      from: complianceManager,
    });
    expectEvent(kycReceipt, "SetKycPassed", { account: nimdok });
    expect(await this.contract.isKycPassed(nimdok, { from: owner }));

    const unkycReceipt = await this.contract.unsetKycPassed(nimdok, {
      from: complianceManager,
    });
    expectEvent(unkycReceipt, "UnsetKycPassed", { account: nimdok });
    expect(!(await this.contract.isKycPassed(nimdok, { from: owner })));
    expectRevert(
      this.contract.transfer(owner, web3.utils.toWei("5", "ether"), {
        from: nimdok,
      }),
      "Calling this function requires KYC approval."
    );
  });

  it("can freeze and unfreeze accounts", async () => {
    await this.contract.setKycPassed(nimdok, { from: complianceManager });
    await this.contract.transfer(nimdok, web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });

    const freezeReceipt = await this.contract.freeze(nimdok, {
      from: complianceManager,
    });
    expectEvent(freezeReceipt, "Freeze", { account: nimdok });

    expectRevert(
      this.contract.transfer(owner, web3.utils.toWei("5", "ether"), {
        from: nimdok,
      }),
      "Your account has been frozen, cannot call function."
    );

    const unfreezeReceipt = await this.contract.unfreeze(nimdok, {
      from: complianceManager,
    });
    expectEvent(unfreezeReceipt, "Unfreeze", { account: nimdok });

    const transferReceipt = await this.contract.transfer(
      owner,
      web3.utils.toWei("1", "ether"),
      { from: nimdok }
    );
    expectEvent(transferReceipt, "Transfer", {
      sender: nimdok,
      recipient: owner,
      amount: web3.utils.toWei("1", "ether"),
    });
  });

  it("is mintable", async () => {
    expectRevert(
      this.contract.mint(web3.utils.toWei("10", "ether"), { from: nimdok }),
      "Only the supply manager can call this function."
    );
    await this.contract.mint(web3.utils.toWei("100", "ether"), { from: owner });
    await this.contract.mint(web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });
    expect(
      (await this.contract.totalSupply()) == web3.utils.toWei("410", "ether")
    );
    expect(
      (await this.contract.totalSupply()) ==
        (await this.contract.balanceOf(supplyManager))
    );
  });

  it("is burnable", async () => {
    expectRevert(
      this.contract.burn(web3.utils.toWei("10", "ether"), { from: nimdok }),
      "Only the supply manager can call this function."
    );
    await this.contract.burn(web3.utils.toWei("100", "ether"), {
      from: supplyManager,
    });
    await this.contract.burn(web3.utils.toWei("10", "ether"), { from: owner });
    expect(
      (await this.contract.totalSupply()) == web3.utils.toWei("190", "ether")
    );
    expect(
      (await this.contract.totalSupply()) ==
        (await this.contract.balanceOf(supplyManager))
    );
  });

  it("is transferrable", async () => {
    await this.contract.setKycPassed(nimdok, { from: complianceManager });
    await this.contract.setKycPassed(ultron, { from: complianceManager });
    await this.contract.transfer(ultron, web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });

    const transferReceipt = await this.contract.transfer(
      nimdok,
      web3.utils.toWei("1", "ether"),
      { from: ultron }
    );

    expectEvent(transferReceipt, "Transfer", {
      sender: ultron,
      recipient: nimdok,
      amount: web3.utils.toWei("1", "ether"),
    });
    expect(
      // Note: No Gas
      (await this.contract.balanceOf(ultron)) == web3.utils.toWei("9", "ether")
    );
    expect(
      (await this.contract.balanceOf(nimdok)) == web3.utils.toWei("1", "ether")
    );
  });

  it("is pausable", async () => {
    await this.contract.setKycPassed(nimdok, { from: complianceManager });
    await this.contract.setKycPassed(ultron, { from: complianceManager });
    await this.contract.setKycPassed(erasmus, { from: complianceManager });
    await this.contract.transfer(ultron, web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });
    await this.contract.transfer(nimdok, web3.utils.toWei("5", "ether"), {
      from: ultron,
    });
    await this.contract.transfer(erasmus, web3.utils.toWei("1", "ether"), {
      from: nimdok,
    });

    // CEASE
    const pauseReceipt = await this.contract.pause({
      from: complianceManager,
    });
    expectEvent(pauseReceipt, "Pause", { sender: complianceManager });

    const transfer1st = this.contract.transfer(
      nimdok,
      web3.utils.toWei("1", "ether"),
      {
        from: ultron,
      }
    );
    const transfer2nd = this.contract.transfer(
      ultron,
      web3.utils.toWei("1", "ether"),
      {
        from: erasmus,
      }
    );
    expectRevert(transfer1st, "Pausable: paused");
    expectRevert(transfer2nd, "Pausable: paused");

    // mk
    const unpauseReceipt = await this.contract.unpause({
      from: complianceManager,
    });
    expectEvent(unpauseReceipt, "Unpause", { sender: complianceManager });

    const transfer3rdReceipt = await this.contract.transfer(
      nimdok,
      web3.utils.toWei("1", "ether"),
      {
        from: ultron,
      }
    );
    const transfer4thReceipt = await this.contract.transfer(
      ultron,
      web3.utils.toWei("1", "ether"),
      {
        from: erasmus,
      }
    );
    expectEvent(transfer3rdReceipt, "Transfer", {
      sender: ultron,
      recipient: nimdok,
      amount: web3.utils.toWei("1", "ether"),
    });
    expectEvent(transfer4thReceipt, "Transfer", {
      sender: erasmus,
      recipient: ultron,
      amount: web3.utils.toWei("1", "ether"),
    });
  });

  it("is delegable", async () => {
    await this.contract.setKycPassed(nimdok, { from: complianceManager });
    await this.contract.setKycPassed(ultron, { from: complianceManager });
    await this.contract.transfer(ultron, web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });

    const delegate1stReceipt = await this.contract.approveAllowance(
      nimdok,
      web3.utils.toWei("1", "ether"),
      { from: ultron }
    );
    expectEvent(delegate1stReceipt, "Approve", {
      sender: ultron,
      spender: nimdok,
      amount: web3.utils.toWei("1", "ether"),
    });

    expectRevert(
      this.contract.approveAllowance(erasmus, web3.utils.toWei("2", "ether"), {
        from: ultron,
      }),
      "Spender account requires KYC to continue."
    );
    expectRevert(
      this.contract.approveAllowance(
        rand_paul,
        web3.utils.toWei("1", "ether"),
        {
          from: erasmus,
        }
      ),
      "Calling this function requires KYC approval."
    );

    await this.contract.setKycPassed(erasmus, { from: complianceManager });
    const delegate2ndReceipt = await this.contract.approveAllowance(
      erasmus,
      web3.utils.toWei("20", "ether"),
      {
        from: ultron,
      }
    );
    expectEvent(delegate2ndReceipt, "Approve", {
      sender: ultron,
      spender: erasmus,
      amount: web3.utils.toWei("20", "ether"),
    });

    // Increase Allowance
    const increaseReceipt = await this.contract.increaseAllowance(
      erasmus,
      web3.utils.toWei("10", "ether"),
      { from: ultron }
    );
    expectEvent(increaseReceipt, "IncreaseAllowance", {
      sender: ultron,
      spender: erasmus,
      amount: web3.utils.toWei("30", "ether"),
    });

    // Decrease Allowance
    const decreaseReceipt = await this.contract.decreaseAllowance(
      erasmus,
      web3.utils.toWei("1", "ether"),
      { from: ultron }
    );
    expectEvent(decreaseReceipt, "DecreaseAllowance", {
      sender: ultron,
      spender: erasmus,
      amount: web3.utils.toWei("29", "ether"),
    });
    expect(
      (await this.contract.allowance(ultron, erasmus)) ==
        web3.utils.toWei("29", "ether")
    );

    // erasmus tries to spend within allowance but more than ultron's balance
    expectRevert(
      this.contract.transferFrom(
        ultron,
        nimdok,
        web3.utils.toWei("15", "ether"),
        {
          from: erasmus,
        }
      ),
      "ERC20: transfer amount exceeds balance"
    );

    // erasmus can spend within allowance, less than ultron's balance
    const transferFromReceipt = await this.contract.transferFrom(
      ultron,
      nimdok,
      web3.utils.toWei("1", "ether"),
      { from: erasmus }
    );
    expectEvent(transferFromReceipt, "Transfer", {
      sender: ultron,
      recipient: nimdok,
      amount: web3.utils.toWei("1", "ether"),
    });
    expectEvent(transferFromReceipt, "Approve", {
      sender: ultron,
      spender: erasmus,
      amount: web3.utils.toWei("28", "ether"),
    });
  });

  it("can wipe accounts", async () => {
    await this.contract.setKycPassed(nimdok, { from: complianceManager });
    await this.contract.setKycPassed(ultron, { from: complianceManager });
    await this.contract.transfer(ultron, web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });

    expectRevert(
      this.contract.wipe(ultron, { from: enforcementManager }),
      "Account must be frozen prior to wipe."
    );

    await this.contract.freeze(ultron, { from: complianceManager });
    const balance = await this.contract.balanceOf(ultron, {
      from: enforcementManager,
    });
    const wipeReceipt = await this.contract.wipe(ultron, {
      from: enforcementManager,
    });
    expectEvent(wipeReceipt, "Wipe", {
      account: ultron,
      amount: balance,
    });
    await this.contract.unfreeze(ultron, { from: complianceManager });
    expect((await this.contract.balanceOf(ultron, { from: ultron })) == 0);
    expect(
      (await this.contract.totalSupply()) == web3.utils.toWei("290", "ether")
    );
  });

  it("can request external transfer", async () => {
    await this.contract.setKycPassed(nimdok, { from: complianceManager });
    await this.contract.setKycPassed(ultron, { from: complianceManager });
    await this.contract.transfer(ultron, web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });

    const network = "hsc://0.0.999999";
    const amount = web3.utils.toWei("1", "ether");
    const externalAddress = web3.utils.fromAscii(
      "480474335c38c27bfde1f0c2010d3db95eeb74a1f8ac65212f7824ce1ab84eca"
    );
    const requestReceipt = await this.contract.approveExternalTransfer(
      network,
      externalAddress,
      amount,
      { from: ultron }
    );
    expectEvent(requestReceipt, "ApproveExternalTransfer", {
      from: ultron,
      networkURI: network,
      to: externalAddress,
      amount: amount,
    });
    expect(
      (await this.contract.externalAllowanceOf(
        ultron,
        network,
        externalAddress
      )) == amount
    );
  });

  it("can send external transfer", async () => {
    await this.contract.setKycPassed(nimdok, { from: complianceManager });
    await this.contract.setKycPassed(ultron, { from: complianceManager });
    await this.contract.transfer(ultron, web3.utils.toWei("10", "ether"), {
      from: supplyManager,
    });

    const network = "hsc://0.0.999999";
    const amount = web3.utils.toWei("1", "ether");
    const externalAddress = web3.utils.fromAscii(
      "480474335c38c27bfde1f0c2010d3db95eeb74a1f8ac65212f7824ce1ab84eca"
    );

    expectRevert(
      this.contract.externalTransfer(
      ultron,
      network,
      externalAddress,
      amount,
      { from: supplyManager }
    ),
    "Amount greater than allowance."
    );

    await this.contract.unsetKycPassed(ultron, { from: complianceManager });
    expectRevert(
      this.contract.externalTransfer(
      ultron,
      network,
      externalAddress,
      amount,
      { from: supplyManager }
    ),
    "Spender account requires KYC to continue."
    );
    
    await this.contract.setKycPassed(ultron, { from: complianceManager });
    await this.contract.approveExternalTransfer(
      network,
      externalAddress,
      amount,
      { from: ultron }
    );

    const externalTransferReceipt = await this.contract.externalTransfer(
      ultron,
      network,
      externalAddress,
      amount,
      { from: supplyManager }
    );
    expectEvent(externalTransferReceipt, "ExternalTransfer", {
      from: ultron,
      networkURI: network,
      to: externalAddress,
      amount: amount
    });

    expect((await this.contract.totalSupply()) == web3.utils.toWei("299", "ether"));
    expect((await this.contract.balanceOf(ultron)) == web3.utils.toWei("9", "ether"));
  });

  it("can receive external transfer", async () => {
    const network = "hsc://0.0.999999";
    const amount = web3.utils.toWei("1", "ether");
    const externalAddress = web3.utils.fromAscii(
      "480474335c38c27bfde1f0c2010d3db95eeb74a1f8ac65212f7824ce1ab84eca"
    );

    expectRevert(
      this.contract.externalTransferFrom(
        externalAddress,
        network,
        ultron,
        amount,
        { from: supplyManager }
      ),
      "Recipient account requires KYC to continue."
    );
   
    await this.contract.setKycPassed(ultron, { from: complianceManager })
    const externalTransferReceipt = await this.contract.externalTransferFrom(
      externalAddress,
      network,
      ultron,
      amount,
      { from: supplyManager }
    );
    expectEvent(externalTransferReceipt, "ExternalTransferFrom", {
      from: externalAddress,
      networkURI: network,
      to: ultron,
      amount: amount
    });

    expect((await this.contract.totalSupply()) == web3.utils.toWei("301", "ether"));
    expect((await this.contract.balanceOf(ultron)) == web3.utils.toWei("1", "ether"));
  });

  afterEach(() => {
    this.contract = null;
  });
});
