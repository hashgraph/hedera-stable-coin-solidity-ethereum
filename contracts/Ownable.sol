// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

// Owner: Propose Account becomes Owner
// Account: Claims Ownership if previously proposed to be owner
contract OwnableUpgradeSafe is Initializable, ContextUpgradeSafe {
    address private _owner;
    address private _proposedOwner;

    event ProposeOwner(address indexed proposedOwner);
    event ClaimOwnership(address);

    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
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
        require(_owner == _msgSender(), "Only the owner can call this function.");
        _;
    }

    modifier onlyProposedOwner() {
        require(
            msg.sender == _proposedOwner,
            "Only the proposed owner can call this function."
        );
        _;
    }

    function disregardProposedOwner() public onlyOwner {
        _proposedOwner = address(0);
    }

    function proposeOwner(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Cannot propose 0x0 as new owner."
        );
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
