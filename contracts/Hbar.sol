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

    bytes32 public constant SUPPLY_MANAGER_ROLE = keccak256(
        "SUPPLY_MANAGER_ROLE"
    );
    bytes32 public constant ASSET_PROTECTION_MANAGER_ROLE = keccak256(
        "ASSET_PROTECTION_MANAGER_ROLE"
    );
    bytes32 public constant KYC_PASSED = keccak256("KYC_PASSED");
    bytes32 public constant FROZEN = keccak256("FROZEN");

    event WipedAccount(address, uint256);

    modifier onlySupplyManager() {
        require(
            hasRole(SUPPLY_MANAGER_ROLE, msg.sender),
            "Only a Supply Manager can call this function."
        );
        _;
    }

    modifier onlyAssetProtectionManager() {
        require(
            hasRole(ASSET_PROTECTION_MANAGER_ROLE, msg.sender),
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

        // Owner has Admin Privileges on all other roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Give owner each other important role
        grantRole(SUPPLY_MANAGER_ROLE, msg.sender);
        grantRole(ASSET_PROTECTION_MANAGER_ROLE, msg.sender);

        // Init roles with given accounts as admins
        _setupRole(SUPPLY_MANAGER_ROLE, supplyManager);
        _setupRole(ASSET_PROTECTION_MANAGER_ROLE, assetProtectionManager);

        // KYC accounts
        _setupRole(KYC_PASSED, msg.sender);
        grantRole(KYC_PASSED, supplyManager);
        grantRole(KYC_PASSED, assetProtectionManager);

        // :^)
        grantRole(KYC_PASSED, address(0));

        // Asset protection manager role controls KYC, Frozen accounts
        _setRoleAdmin(KYC_PASSED, ASSET_PROTECTION_MANAGER_ROLE);
        _setRoleAdmin(FROZEN, ASSET_PROTECTION_MANAGER_ROLE);

        // Initialize token functionality
        __ERC20_init_unchained(tokenName, tokenSymbol);
        __ERC20Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC20Pausable_init_unchained();
        __ERC20Snapshot_init_unchained();
        _setupDecimals(tokenDecimal);

        // Give supply manager all tokens
        _mint(supplyManager, totalSupply);
    }

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

    // Claim ownership: grant roles to new owner
    function claimOwnership()
        public
        override(OwnableUpgradeSafe)
        onlyProposedOwner
    {
        super.claimOwnership();
        grantRole(KYC_PASSED, msg.sender);
        revokeRole(FROZEN, msg.sender);
        grantRole(SUPPLY_MANAGER_ROLE, msg.sender);
        grantRole(ASSET_PROTECTION_MANAGER_ROLE, msg.sender);
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Before Token Transfer, check account status of sender, receiver
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20PausableUpgradeSafe, ERC20UpgradeSafe) {
        require(
            !hasRole(FROZEN, from),
            "Sender account is frozen, cannot continue."
        );
        require(
            !hasRole(FROZEN, to),
            "Receiver account is frozen, cannot continue."
        );
        require(
            hasRole(KYC_PASSED, from),
            "Sender account requires KYC approval, cannot continue."
        );
        require(
            hasRole(KYC_PASSED, to),
            "Receiver account requires KYC approval, cannot continue."
        );
    }

    // Transfer: requires KYC, Unfrozen Sender
    function _transfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20SnapshotUpgradeSafe, ERC20UpgradeSafe)
        requiresKYC
        requiresNotFrozen
    {
        super._transfer(from, to, amount);
    }

    // Mint: Only Supply Manager
    function _mint(address to, uint256 amount)
        internal
        override(ERC20UpgradeSafe, ERC20SnapshotUpgradeSafe)
        onlySupplyManager
    {
        super._mint(to, amount);
    }

    // Burn: Only Supply Manager
    function _burn(address from, uint256 amount)
        internal
        override(ERC20UpgradeSafe, ERC20SnapshotUpgradeSafe)
        onlySupplyManager
    {
        super._burn(from, amount);
    }

    // Pause: Only APM
    function pause() public onlyAssetProtectionManager {
        _pause();
    }

    // Unpause: Only APM
    function unpause() public onlyAssetProtectionManager {
        _unpause();
    }

    // Freeze an account: only APM
    function freeze(address account) public onlyAssetProtectionManager {
        grantRole(FROZEN, account);
    }

    // Unfreeze an account: only APM
    function unfreeze(address account) public onlyAssetProtectionManager {
        revokeRole(FROZEN, account);
    }

    // Wipe an account: only APM, target account must be frozen
    function wipe(address account) public onlyAssetProtectionManager {
        require(
            hasRole(FROZEN, account),
            "Account must be frozen before wipe."
        );
        uint256 bal = balanceOf(account);
        super._burn(account, bal);
        emit WipedAccount(account, bal);
    }

    // KYC: only APM
    function setKycPassed(address account) public onlyAssetProtectionManager {
        grantRole(KYC_PASSED, account);
    }

    // Un-KYC: only APM
    function unsetKycPassed(address account) public onlyAssetProtectionManager {
        revokeRole(KYC_PASSED, account);
    }

    uint256[50] private __gap;
}
