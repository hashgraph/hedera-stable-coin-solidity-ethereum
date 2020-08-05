// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Snapshot.sol";

import "./Ownable.sol";

contract StableCoin is
    Initializable,
    ContextUpgradeSafe,
    OwnableUpgradeSafe,
    AccessControlUpgradeSafe,
    ERC20BurnableUpgradeSafe,
    ERC20PausableUpgradeSafe,
    ERC20SnapshotUpgradeSafe
{
    using SafeMath for uint256;

    bytes32 private constant KYC_PASSED = keccak256("KYC_PASSED");
    bytes32 private constant FROZEN = keccak256("FROZEN");

    address private _supplyManager;
    address private _assetProtectionManager;

    event Constructed(string, string, uint8, uint256, address, address);
    event ChangeSupplyManager(address);
    event ChangeAssetProtectionManager(address);
    event Wipe(address, uint256);
    event Mint(address, uint256);
    event Burn(address, uint256);
    event Transfer(address, address, uint256);
    event Approve(address, address, uint256);
    event IncreaseAllowance(address, address, uint256);
    event DecreaseAllowance(address, address, uint256);
    event Freeze(address);
    event Unfreeze(address);
    event SetKycPassed(address);
    event UnsetKycPassed(address);

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

        _supplyManager = supplyManager;
        _assetProtectionManager = assetProtectionManager;

        // Owner has Admin Privileges on all other roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // KYC accounts
        _setupRole(KYC_PASSED, msg.sender);
        grantRole(KYC_PASSED, supplyManager);
        grantRole(KYC_PASSED, assetProtectionManager);

        // :^)
        grantRole(KYC_PASSED, address(0));

        // Initialize token functionality
        __ERC20_init_unchained(tokenName, tokenSymbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ERC20Snapshot_init_unchained();
        _setupDecimals(tokenDecimal);

        // Give supply manager all tokens
        _mint(supplyManager, totalSupply);

        // Did it
        emit Constructed(
            tokenName,
            tokenSymbol,
            tokenDecimal,
            totalSupply,
            supplyManager,
            assetProtectionManager
        );
    }

    // Non-"Upgradeable"
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address assetProtectionManager
    ) public {
        init(
            tokenName,
            tokenSymbol,
            tokenDecimal,
            totalSupply,
            supplyManager,
            assetProtectionManager
        );
    }

    function supplyManager() public view returns (address) {
        return _supplyManager;
    }

    modifier onlySupplyManager() {
        require(
            msg.sender == supplyManager() || msg.sender == owner(),
            "Only the supply manager can call this function."
        );
        _;
    }

    function changeSupplyManager(address newSupplyManager) private onlyOwner {
        require(
            newSupplyManager != address(0),
            "Cannot change supply manager to 0x0."
        );
        _supplyManager = newSupplyManager;
        emit ChangeSupplyManager(newSupplyManager);
    }

    function assetProtectionManager() public view returns (address) {
        return _assetProtectionManager;
    }

    modifier onlyAssetProtectionManager() {
        require(
            msg.sender == assetProtectionManager() || msg.sender == owner(),
            "Only an Asset Protection Manager can call this function."
        );
        _;
    }

    function changeAssetProtectionManager(address newAssetProtectionManager)
        private
        onlyOwner
    {
        require(
            newAssetProtectionManager != address(0),
            "Cannot change asset protection manager to 0x0."
        );
        _assetProtectionManager = newAssetProtectionManager;
        emit ChangeAssetProtectionManager(newAssetProtectionManager);
    }

    function isPrivilegedRole(address account) public view returns (bool) {
        return
            account == supplyManager() ||
            account == assetProtectionManager() ||
            account == owner();
    }

    modifier requiresKYC() {
        require(
            hasRole(KYC_PASSED, msg.sender),
            "Calling this function requires KYC approval."
        );
        _;
    }

    function isKycPassed(address account) public view returns (bool) {
        return hasRole(KYC_PASSED, account);
    }

    // KYC: only APM
    function setKycPassed(address account) public onlyAssetProtectionManager {
        grantRole(KYC_PASSED, account);
    }

    // Un-KYC: only APM, only non-privileged accounts
    function unsetKycPassed(address account) public onlyAssetProtectionManager {
        require(
            !isPrivilegedRole(account),
            "Cannot unset KYC for administrator account."
        );
        revokeRole(KYC_PASSED, account);
    }

    modifier requiresNotFrozen() {
        require(
            !hasRole(FROZEN, msg.sender),
            "Your account has been frozen, cannot call function."
        );
        _;
    }

    // Freeze an account: only APM, only non-privileged accounts
    function freeze(address account) public onlyAssetProtectionManager {
        require(
            !isPrivilegedRole(account),
            "Cannot freeze administrator account."
        );
        grantRole(FROZEN, account);
    }

    // Unfreeze an account: only APM
    function unfreeze(address account) public onlyAssetProtectionManager {
        revokeRole(FROZEN, account);
    }

    function isFrozen(address account) public view returns (bool) {
        return hasRole(FROZEN, account);
    }

    // Pause: Only APM
    function pause() public onlyAssetProtectionManager {
        _pause();
    }

    // Unpause: Only APM
    function unpause() public onlyAssetProtectionManager {
        _unpause();
    }

    uint256[50] private __gap;
}
