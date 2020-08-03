// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";

contract Hbar is Initializable, ContextUpgradeSafe, OwnableUpgradeSafe, AccessControlUpgradeSafe, ERC20BurnableUpgradeSafe, ERC20PausableUpgradeSafe {
    using SafeMath for uint256;
    bytes32 public constant SUPPLY_MANAGER = keccak256("SUPPLY_MANAGER");
    bytes32 public constant ASSET_PROTECTION_MANAGER = keccak256("ASSET_PROTECTION_MANAGER");
    address private _newOwner;

    modifier onlySupplyManager() {
        require(hasRole(SUPPLY_MANAGER, msg.sender), "Only a Supply Manager can call this function.");
        _;
    }

    modifier onlyAssetProtectionManager() {
        require(hasRole(ASSET_PROTECTION_MANAGER, msg.sender), "Only an Asset Protection Manager can call this function.");
        _;
    }

    modifier onlyNewOwner() {
        require(msg.sender == _newOwner, "Only the pre-designated new owner can call this function.");
        _;
    }

    function init(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address assetProtectionManager
    ) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(tokenName, tokenSymbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        _setupRole(SUPPLY_MANAGER, supplyManager);
        _setupRole(ASSET_PROTECTION_MANAGER, assetProtectionManager);
        _setupDecimals(tokenDecimal);
        _mint(supplyManager, totalSupply);
    }

    function mint(address to, uint256 amount) public onlySupplyManager {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlySupplyManager {
        _burn(from, amount);
    }

    function pause() public onlyAssetProtectionManager {
        _pause();
    }

    function unpause() public onlyAssetProtectionManager {
        _unpause();
    }

    function transferOwnership(address newOwner) public onlyOwner override(OwnableUpgradeSafe) {
        require(newOwner != address(0), "Cannot set new owner to 0x00.");
        _newOwner = newOwner;
    }

    function claimOwnership() public onlyNewOwner {
        emit OwnershipTransferred(_owner, _newOwner);
        _owner = _newOwner;
        _newOwner = address(0);
    }

    uint256[50] private __gap;
}
