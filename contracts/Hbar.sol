// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract Hbar is Initializable {
    using SafeMath for uint256;
    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant SUPPLY_MANAGER = keccak256("SUPPLY_MANAGER");
    bytes32 public constant ASSET_PROTECTION_MANAGER = keccak256(
        "ASSET_PROTECTION_MANAGER"
    );

    function init(
        string memory tokenName,
        string memory tokenSymbol,
        uint32 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address assetProtectionManager
    ) public initializer {
        // _setupRole(OWNER, owner);
        // _setupRole(SUPPLY_MANAGER, supplyManager);
        // _setupRole(ASSET_PROTECTION_MANAGER, assetProtectionManager);
    }
}
