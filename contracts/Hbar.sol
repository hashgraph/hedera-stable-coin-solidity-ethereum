// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";

contract Hbar is Initializable, ContextUpgradeSafe, AccessControlUpgradeSafe, ERC20BurnableUpgradeSafe, ERC20PausableUpgradeSafe {
    using SafeMath for uint256;
    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant SUPPLY_MANAGER = keccak256("SUPPLY_MANAGER");
    bytes32 public constant ASSET_PROTECTION_MANAGER = keccak256("ASSET_PROTECTION_MANAGER");

    modifier onlySupplyManager() {
        require(hasRole(SUPPLY_MANAGER, msg.sender), "Only a Supply Manager can call this function.");
        _;
    }

    modifier onlyAssetProtectionManager() {
        require(hasRole(ASSET_PROTECTION_MANAGER, msg.sender), "Only an Asset Protection Manager can call this function.");
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
        __AccessControl_init_unchained();
        __ERC20_init_unchained(tokenName, tokenSymbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        _setupRole(OWNER, msg.sender);
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

    function freeze() public onlyAssetProtectionManager {
        _pause();
    }

    function unfreeze() public onlyAssetProtectionManager {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20UpgradeSafe, ERC20PausableUpgradeSafe) {
        super._beforeTokenTransfer(from, to, amount);
    }

    uint256[50] private __gap;
}
