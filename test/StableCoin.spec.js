const { accounts, contract } = import("@openzeppelin/test-environment");
const { expect } = import("chai");

const StableCoin = contract.fromArtifact("StableCoin");

describe("StableCoin", () => {
    const [ owner ] = accounts;

    beforeEach(async() => {
        this.contract = await StableCoin.new({
            from: owner
        });
    });

    it("initializes", () => {
        console.log(this.contract);
        console.log(owner);
    });
});