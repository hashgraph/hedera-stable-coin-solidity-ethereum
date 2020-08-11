// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

import "./Ownable.sol";

contract StableCoin is
    Initializable, // has an initializer instead of constructor
    ContextUpgradeSafe, // provides _msgSender(), _msgData()
    PausableUpgradeSafe, // provides _pause(), _unpause()
    OwnableUpgradeSafe, // Ownable, Claimable
    AccessControlUpgradeSafe, // RBAC for KYC, Frozen
    ERC20UpgradeSafe // ERC20 Functions
{
    using SafeMath for uint256; // reverts on failed math operations

    bytes32 private constant KYC_PASSED = keccak256("KYC_PASSED");
    bytes32 private constant FROZEN = keccak256("FROZEN");

    address private _supplyManager;
    address private _assetProtectionManager;

    event Constructed(
        string tokenName,
        string tokenSymbol,
        uint8 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address assetProtectionManager
    );

    event ChangeSupplyManager(address newSupplyManager);
    event ChangeAssetProtectionManager(address newAssetProtectionManager);
    event Wipe(address account, uint256 amount);
    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);
    event Transfer(address sender, address recipient, uint256 amount);
    event Approve(address sender, address spender, uint256 amount);
    event IncreaseAllowance(address sender, address spender, uint256 amount);
    event DecreaseAllowance(address sender, address spender, uint256 amount);
    event Freeze(address account); // Freeze: Freeze this account
    event Unfreeze(address account);
    event SetKycPassed(address account);
    event UnsetKycPassed(address account);
    event Pause(address sender); // Pause: Pause entire contract
    event Unpause(address sender);

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

        // Owner has Admin Privileges on all roles
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender()); // sudo role

        // Give APM ability to grant/revoke roles (but not admin of this role)
        grantRole(DEFAULT_ADMIN_ROLE, assetProtectionManager);

        // KYC accounts
        grantRole(KYC_PASSED, _msgSender());
        grantRole(KYC_PASSED, supplyManager);
        grantRole(KYC_PASSED, assetProtectionManager);

        // Initialize token functionality
        __ERC20_init_unchained(tokenName, tokenSymbol);
        __Pausable_init_unchained();
        _setupDecimals(tokenDecimal);

        // Give supply manager all tokens
        mint(totalSupply); // Emits Transfer, Mint

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

    function supplyManager() public view returns (address) {
        return _supplyManager;
    }

    modifier onlySupplyManager() {
        require(
            _msgSender() == supplyManager() || _msgSender() == owner(),
            "Only the supply manager can call this function."
        );
        _;
    }

    function changeSupplyManager(address newSupplyManager) public onlyOwner {
        require(
            newSupplyManager != address(0),
            "Cannot change supply manager to 0x0."
        );
        revokeRole(KYC_PASSED, _supplyManager);
        _supplyManager = newSupplyManager;
        grantRole(KYC_PASSED, _supplyManager);
        revokeRole(FROZEN, _supplyManager);
        emit ChangeSupplyManager(newSupplyManager);
    }

    function assetProtectionManager() public view returns (address) {
        return _assetProtectionManager;
    }

    modifier onlyAssetProtectionManager() {
        require(
            _msgSender() == assetProtectionManager() || _msgSender() == owner(),
            "Only an Asset Protection Manager can call this function."
        );
        _;
    }

    function changeAssetProtectionManager(address newAssetProtectionManager)
        public
        onlyOwner
    {
        require(
            newAssetProtectionManager != address(0),
            "Cannot change asset protection manager to 0x0."
        );
        revokeRole(KYC_PASSED, _assetProtectionManager);
        _assetProtectionManager = newAssetProtectionManager;
        grantRole(KYC_PASSED, _assetProtectionManager);
        revokeRole(FROZEN, _assetProtectionManager);
        emit ChangeAssetProtectionManager(newAssetProtectionManager);
    }

    function isPrivilegedRole(address account) public view returns (bool) {
        return
            account == supplyManager() ||
            account == assetProtectionManager() ||
            account == owner();
    }

    function renounceRole(bytes32 role, address account)
        public
        override(AccessControlUpgradeSafe)
        requiresKYC
        requiresNotFrozen
    {
        require(
            !isPrivilegedRole(_msgSender()) || _msgSender() == owner(),
            "Priviledged roles cannot be self-revoked"
        );
        super.renounceRole(role, account);
    }

    modifier requiresKYC() {
        require(
            hasRole(KYC_PASSED, _msgSender()),
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
        emit SetKycPassed(account);
    }

    // Un-KYC: only APM, only non-privileged accounts
    function unsetKycPassed(address account) public onlyAssetProtectionManager {
        require(
            !isPrivilegedRole(account),
            "Cannot unset KYC for administrator account."
        );
        require(account != address(0), "Cannot unset KYC for address 0x0.");
        revokeRole(KYC_PASSED, account);
        emit UnsetKycPassed(account);
    }

    modifier requiresNotFrozen() {
        require(
            !hasRole(FROZEN, _msgSender()),
            "Your account has been frozen, cannot call function."
        );
        _;
    }

    function isFrozen(address account) public view returns (bool) {
        return hasRole(FROZEN, account);
    }

    // Freeze an account: only APM, only non-privileged accounts
    function freeze(address account) public onlyAssetProtectionManager {
        require(
            !isPrivilegedRole(account),
            "Cannot freeze administrator account."
        );
        require(account != address(0), "Cannot freeze address 0x0.");
        grantRole(FROZEN, account);
        emit Freeze(account);
    }

    // Unfreeze an account: only APM
    function unfreeze(address account) public onlyAssetProtectionManager {
        revokeRole(FROZEN, account);
        emit Unfreeze(account);
    }

    // Check Transfer Allowed (user facing)
    function checkTransferAllowed(address account) public view returns (bool) {
        return isKycPassed(account) && !isFrozen(account);
    }

    // Pause: Only APM
    function pause() public onlyAssetProtectionManager {
        _pause();
        emit Pause(_msgSender());
    }

    // Unpause: Only APM
    function unpause() public onlyAssetProtectionManager {
        _unpause();
        emit Unpause(_msgSender());
    }

    // Claim Ownership
    function claimOwnership()
        public
        override(OwnableUpgradeSafe)
        onlyProposedOwner
    {
        address prevOwner = owner();
        super.claimOwnership(); // emits ClaimOwnership
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(KYC_PASSED, _msgSender());
        revokeRole(FROZEN, _msgSender());
        revokeRole(KYC_PASSED, prevOwner);
    }

    // Wipe
    function wipe(address account) public onlyAssetProtectionManager {
        require(
            hasRole(FROZEN, account),
            "Account must be frozen prior to wipe."
        );
        uint256 balance = balanceOf(account);
        _burn(account, balance); // emits Transfer
        emit Wipe(account, balance);
    }

    // Mint
    function mint(uint256 amount) public onlySupplyManager {
        _mint(supplyManager(), amount); // emits Transfer
        emit Mint(_msgSender(), amount);
    }

    // Burn
    function burn(uint256 amount) public onlySupplyManager {
        _burn(_supplyManager, amount); // emits Transfer
        emit Burn(_msgSender(), amount);
    }

    // Check Transfer Allowed (internal)
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20UpgradeSafe)
        requiresKYC
        requiresNotFrozen
        whenNotPaused
    {
        // Note: ERC20 checks if to == address(0) during _transfer
        if (isPrivilegedRole(_msgSender()) && to == address(0)) {
            // allowed burn
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        // Note: ERC20 checks to == address(0) during _transfer
        if ((to == supplyManager() || to == owner()) && from == address(0)) {
            // allowed mint
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        // All other transfers
        require(isKycPassed(from), "Sender requires KYC to continue.");
        require(isKycPassed(to), "Receiver requires KYC to continue.");
        require(!isFrozen(from), "Sender account is frozen.");
        require(!isFrozen(to), "Receiver account is frozen.");
        require(
            _msgSender() == owner() ||
                _msgSender() == supplyManager() ||
                to != address(0),
            "Only the supply manager can burn coins, cannot transfer to 0x0."
        ); // Only owner and supplyManager can burn coins
        super._beforeTokenTransfer(from, to, amount); // callbacks from above (if any)
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20UpgradeSafe) requiresKYC requiresNotFrozen {
        super._transfer(sender, recipient, amount);
        emit Transfer(sender, recipient, amount); // Override for named params
    }

    // Transfer
    function transfer(address to, uint256 amount)
        public
        override(ERC20UpgradeSafe)
        returns (bool)
    {
        _transfer(_msgSender(), to, amount); // emits Transfer([])
        return true;
    }

    // Allowances
    function _beforeTokenAllowance(address sender, address spender)
        internal
        view
        whenNotPaused
    {
        require(isKycPassed(spender), "Spender requires KYC to continue.");
        require(isKycPassed(sender), "Sender requires KYC to continue.");
        require(!isFrozen(spender), "Spender account is frozen.");
        require(!isFrozen(sender), "Sender account is frozen.");
    }

    // Transfer From (transfer between allowances)
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(ERC20UpgradeSafe)
        requiresKYC
        requiresNotFrozen
        returns (bool)
    {
        _beforeTokenAllowance(from, to);
        bool result = super.transferFrom(from, to, amount); // emits Transfer, Approval
        if (result) emit Approve(from, to, allowance(from, _msgSender()));
        return result;
    }

    // Approve Allowance
    function approveAllowance(address spender, uint256 amount)
        public
        requiresKYC
        requiresNotFrozen
    {
        _beforeTokenAllowance(_msgSender(), spender);
        super._approve(_msgSender(), spender, amount); // emits Approval([])
        emit Approve(_msgSender(), spender, amount);
    }

    // convenience
    function approve(address spender, uint256 amount)
        public
        override(ERC20UpgradeSafe)
        returns (bool)
    {
        approveAllowance(spender, amount);
        return true;
    }

    // Increase Allowance
    function increaseAllowance(address spender, uint256 amount)
        public
        override(ERC20UpgradeSafe)
        requiresKYC
        requiresNotFrozen
        returns (bool)
    {
        _beforeTokenAllowance(_msgSender(), spender);
        uint256 newAllowance = allowance(_msgSender(), spender).add(amount);
        _approve(
            _msgSender(),
            spender,
            newAllowance
        ); // emits Approval
        emit IncreaseAllowance(_msgSender(), spender, newAllowance);
        return true;
    }

    // Decrease Allowance
    function decreaseAllowance(address spender, uint256 amount)
        public
        override(ERC20UpgradeSafe)
        requiresKYC
        requiresNotFrozen
        returns (bool)
    {
        _beforeTokenAllowance(_msgSender(), spender);
        uint256 newAllowance = allowance(_msgSender(), spender).sub(
            amount,
            "Amount greater than allowance."
        );
        _approve(_msgSender(), spender, newAllowance); // emits Approval
        emit DecreaseAllowance(_msgSender(), spender, newAllowance);
        return true;
    }

    // For OZ upgrades: Add variable before this and decrement size
    uint256[50] private __gap;
}
