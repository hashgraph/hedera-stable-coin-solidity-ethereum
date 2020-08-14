// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21;

import "./Context.sol";

contract Ownable is ContextAware {
    address private _owner;
    address private _proposedOwner;

    event ProposeOwner(address indexed proposedOwner);
    event ClaimOwnership(address newOwner);

    constructor() public {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit ClaimOwnership(msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function proposedOwner() public view returns (address) {
        return _proposedOwner;
    }

    modifier onlyOwner() {
        require(
            _owner == _msgSender(),
            "Only the owner can call this function."
        );
        _;
    }

    modifier onlyProposedOwner() {
        require(
            _msgSender() == _proposedOwner,
            "Only the proposed owner can call this function."
        );
        _;
    }

    function disregardProposedOwner() private onlyOwner {
        _proposedOwner = address(0);
    }

    function proposeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Cannot propose 0x0 as new owner.");
        _proposedOwner = newOwner;
        emit ProposeOwner(_proposedOwner);
    }

    function claimOwnership() public virtual onlyProposedOwner {
        _owner = _proposedOwner;
        _proposedOwner = address(0);
        emit ClaimOwnership(_owner);
    }

    uint256[49] private __gap;
}
