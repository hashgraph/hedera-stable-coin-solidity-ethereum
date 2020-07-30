//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.7.0;

import "./Ownable.sol";

contract Hbar is Ownable {
    address private supplyManager;
    address private assetProtectionManager;

    string public tokenName;
    string public tokenSymbol;

    int256 public tokenDecimal;
    int256 public totalSupply;

    modifier onlySupplyManager {
        require(
            msg.sender == supplyManager,
            "Only the supply manager can call this function."
        );
        _;
    }

    modifier onlyAssetProtectionManager {
        require(
            msg.sender == assetProtectionManager,
            "Only the asset protection manager can call this function."
        );
        _;
    }

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        int256 _tokenDecimal,
        int256 _totalSupply,
        address _supplyManager,
        address _assetProtectionManager
    ) public {
        owner = msg.sender;
        supplyManager = _supplyManager;
        assetProtectionManager = _assetProtectionManager;

        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;

        tokenDecimal = _tokenDecimal;
        totalSupply = _totalSupply;
    }

    function changeSupplyManager() public view onlyOwner {}

    function changeAssetProtectionManager() public view onlyOwner {}

    function mint() public view onlySupplyManager {}

    function burn() public view onlySupplyManager {}

    function freeze() public view onlyAssetProtectionManager {}

    function unfreeze() public view onlyAssetProtectionManager {}

    function wipe() public view onlyAssetProtectionManager {}

    function setKycPassed() public view onlyAssetProtectionManager {}

    function unsetKycPassed() public view onlyAssetProtectionManager {}

    function isPrivilegedRole() public view {}

    function increaseAllowance() public view {}

    function decreaseAllowance() public view {}
}
