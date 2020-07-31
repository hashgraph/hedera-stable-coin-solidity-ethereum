//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.7.0;

abstract contract Claimable {
    address internal newOwnerCandidate;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyNewOwner() {
        require(
            msg.sender == newOwnerCandidate,
            "You must be chosen by the current owner to call this function."
        );
        _;
    }

    function claimOwnership() public virtual;
}

contract Ownable is Claimable {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be 0.");
        newOwnerCandidate = newOwner;
    }

    function claimOwnership() public override onlyNewOwner {
        address _previousOwner = owner;
        owner = msg.sender;
        emit OwnershipTransferred(_previousOwner, owner);
    }
}
