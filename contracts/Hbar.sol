// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Snapshot.sol";

import "./Ownable.sol";

contract Hbar is
    Initializable,
    ContextUpgradeSafe,
    OwnableUpgradeSafe,
    AccessControlUpgradeSafe,
    ERC20BurnableUpgradeSafe,
    ERC20PausableUpgradeSafe,
    ERC20SnapshotUpgradeSafe
{
    using SafeMath for uint256;

    bytes32 public constant SUPPLY_MANAGER = keccak256("SUPPLY_MANAGER");
    bytes32 public constant ASSET_PROTECTION_MANAGER = keccak256(
        "ASSET_PROTECTION_MANAGER"
    );
    bytes32 public constant KYC_PASSED = keccak256("KYC_PASSED");
    bytes32 public constant FROZEN = keccak256("FROZEN");

    event ProposeOwner(address proposed);

    modifier onlySupplyManager() {
        require(
            hasRole(SUPPLY_MANAGER, msg.sender),
            "Only a Supply Manager can call this function."
        );
        _;
    }

    modifier onlyAssetProtectionManager() {
        require(
            hasRole(ASSET_PROTECTION_MANAGER, msg.sender),
            "Only an Asset Protection Manager can call this function."
        );
        _;
    }

    modifier requiresKYC() {
        require(
            hasRole(KYC_PASSED, msg.sender),
            "Calling this function requires KYC approval."
        );
        _;
    }

    modifier requiresNotFrozen() {
        require(
            !hasRole(FROZEN, msg.sender),
            "Your account has been frozen, cannot call function."
        );
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

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SUPPLY_MANAGER, supplyManager);
        _setupRole(ASSET_PROTECTION_MANAGER, assetProtectionManager);
        _setupRole(KYC_PASSED, msg.sender);
        _setRoleAdmin(KYC_PASSED, assetProtectionManager);
        _setRoleAdmin(FROZEN, assetProtectionManager);

        grantRole(SUPPLY_MANAGER, msg.sender);
        grantRole(ASSET_PROTECTION_MANAGER, msg.sender);
        grantRole(KYC_PASSED, msg.sender);
        grantRole(KYC_PASSED, supplyManager);
        grantRole(KYC_PASSED, assetProtectionManager);

        __ERC20_init_unchained(tokenName, tokenSymbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ERC20Snapshot_init_unchained();
        _setupDecimals(tokenDecimal);

        _mint(supplyManager, totalSupply);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20PausableUpgradeSafe, ERC20UpgradeSafe)
        requiresKYC
        requiresNotFrozen
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function claimOwnership()
        public
        override(OwnableUpgradeSafe)
        onlyProposedOwner
    {
        super.claimOwnership();
        grantRole(KYC_PASSED, msg.sender);
        revokeRole(FROZEN, msg.sender);
        grantRole(SUPPLY_MANAGER, msg.sender);
        grantRole(ASSET_PROTECTION_MANAGER, msg.sender);
    }

    function mint(address to, uint256 amount)
        public
        override(ERC20UpgradeSafe)
        onlySupplyManager
    {
        super._mint(to, amount);
    }

    function burn(address from, uint256 amount)
        public
        override(ERC20UpgradeSafe)
        onlySupplyManager
    {
        super._burn(from, amount);
    }

    function pause() public onlyAssetProtectionManager {
        _pause();
    }

    function unpause() public onlyAssetProtectionManager {
        _unpause();
    }

    function freeze(address account) public onlyAssetProtectionManager {
        grantRole(FROZEN, account);
    }

    function unfreeze(address account) public onlyAssetProtectionManager {
        revokeRole(FROZEN, account);
    }

    function wipe(address account) public onlyAssetProtectionManager {
        // TODO: What exactly?
    }

    function setKycPassed(address account) public onlyAssetProtectionManager {
        grantRole(KYC_PASSED, account);
    }

    function unsetKycPassed(address account) public onlyAssetProtectionManager {
        revokeRole(KYC_PASSED, account);
    }

    uint256[50] private __gap;
}
