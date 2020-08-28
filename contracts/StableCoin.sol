// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.1;

import "./Context.sol";
import "./Pausable.sol";
import "./Ownable.sol";
import "./AccessControl.sol";
import "./ERC20.sol";
import "./ExternalTransfer.sol";

contract StableCoin is
    ContextAware, // provides _msgSender(), _msgData()
    Pausable, // provides _pause(), _unpause()
    Ownable, // Ownable, Claimable
    AccessControl, // RBAC for KYC, Frozen
    ERC20 // ERC20 Functions (transfer, balance, allowance, mint, burn)
{
    // Defined Roles
    bytes32 private constant KYC_PASSED = keccak256("KYC_PASSED");
    bytes32 private constant FROZEN = keccak256("FROZEN");

    // Special People
    address private _supplyManager;
    address private _assetProtectionManager;

    // Events Emitted
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
    event ApproveExternalTransfer(
        address sender,
        string networkURI,
        bytes externalRecipient,
        uint256 amount
    );
    event ExternalTransfer(
        address from,
        string networkURI,
        bytes to,
        uint256 amount
    );
    event ExternalTransferFrom(
        bytes from,
        string networkURI,
        address to,
        uint256 amount
    );

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address assetProtectionManager
    ) public ERC20(tokenName, tokenSymbol, tokenDecimal) {
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

    /*
     * RBAC
     */

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
    function claimOwnership() public override(Ownable) onlyProposedOwner {
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
        super._transfer(account, _supplyManager, balance);
        _burn(_supplyManager, balance);
        emit Wipe(account, balance);
    }

    /*
     * Transfers
     */

    // Mint
    function mint(uint256 amount) public onlySupplyManager {
        _mint(supplyManager(), amount);
        emit Mint(_msgSender(), amount);
    }

    // Burn
    function burn(uint256 amount) public onlySupplyManager {
        _burn(_supplyManager, amount);
        emit Burn(_msgSender(), amount);
    }

    // Check Transfer Allowed (internal)
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) requiresKYC requiresNotFrozen whenNotPaused {
        if (from == supplyManager() && to == address(0)) {
            // allowed (burn)
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        if (to == supplyManager() && from == address(0)) {
            // allowed (mint)
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        if (
            to == supplyManager() &&
            hasRole(FROZEN, from) &&
            amount == balanceOf(from)
        ) {
            // allowed (wipe account)
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        // All other transfers
        require(isKycPassed(from), "Sender requires KYC to continue.");
        require(isKycPassed(to), "Receiver requires KYC to continue.");
        require(!isFrozen(from), "Sender account is frozen.");
        require(!isFrozen(to), "Receiver account is frozen.");
        super._beforeTokenTransfer(from, to, amount); // callbacks from above (if any)
    }

    function transfer(address to, uint256 amount) public override(ERC20) {
        super._transfer(_msgSender(), to, amount);
        emit Transfer(_msgSender(), to, amount);
    }

    /*
     * External Transfers
     */

    // approve an allowance for transfer to an external network
    function approveExternalTransfer(
        string networkURI,
        bytes externalAddress,
        uint256 amount
    )
        public
        override(ExternalTransfer)
        requiresKYC
        requiresNotFrozen
        whenNotPaused
    {
        require(
            amount <= balanceOf(_msgSender()),
            "Cannot approve more than balance."
        );
        super.approveExternalTransfer(networkURI, externalAddress, amount);
        emit ApproveExternalTransfer(
            _msgSender(),
            networkURI,
            externalAddress,
            amount
        );
    }

    function externalTransfer(
        address from,
        string networkURI,
        bytes to,
        uint256 amount
    ) public override(ExternalTransfer) onlySupplyManager whenNotPaused {
        require(isKycPassed(from), "spdender account must pass KYC");
        require(!isFrozen(from), "spender account frozen");
        uint256 exAllowance = externalAllowanceOf(from, networkURI, to, amount);
        require(amount <= exAllowance, "Amount greater than allowance.");
        super._transfer(from, _supplyManager, amount);
        _burn(_supplyManager, amount);
        _approveExternalAllowance(
            from,
            networkURI,
            to,
            exAllowance.sub(amount)
        );
        emit ExternalTransfer(from, networkURI, to, amount);
    }

    function externalTransferFrom(
        bytes from,
        string networkURI,
        address to,
        uint256 amount
    ) public override(ExternalTransfer) onlySupplyManager whenNotPaused {
        require(isKycPassed(to), "recipient must pass KYC");
        require(!isFrozen(to), "recipient account is frozen");
        _mint(_supplyManager, amount);
        super._transfer(_supplyManager, to, amount);
        emit ExternalTransferFrom(from, networkURI, to, amount);
    }

    /*
     * Allowances
     */

    // Check Allowance Allowed (internal)
    function _beforeTokenAllowance(
        address sender,
        address spender,
        uint256 amount
    ) internal override(ERC20) requiresKYC requiresNotFrozen whenNotPaused {
        require(isKycPassed(spender), "Spender requires KYC to continue.");
        require(isKycPassed(sender), "Sender requires KYC to continue.");
        require(!isFrozen(spender), "Spender account is frozen.");
        require(!isFrozen(sender), "Sender account is frozen.");
        require(amount >= 0, "Allowance must be greater than 0.");
    }

    // Transfer From (allowance --> user)
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20) requiresKYC requiresNotFrozen {
        super.transferFrom(from, to, amount);
        emit Transfer(from, to, amount);
        emit Approve(from, _msgSender(), allowance(from, _msgSender()));
    }

    // Approve Allowance
    function approveAllowance(address spender, uint256 amount)
        public
        override(ERC20)
        requiresKYC
        requiresNotFrozen
    {
        super._approve(_msgSender(), spender, amount);
        emit Approve(_msgSender(), spender, amount);
    }

    // Increase Allowance
    function increaseAllowance(address spender, uint256 amount)
        public
        override(ERC20)
        requiresKYC
        requiresNotFrozen
    {
        uint256 newAllowance = allowance(_msgSender(), spender).add(amount);
        _approve(_msgSender(), spender, newAllowance);
        emit IncreaseAllowance(_msgSender(), spender, newAllowance);
    }

    // Decrease Allowance
    function decreaseAllowance(address spender, uint256 amount)
        public
        override(ERC20)
        requiresKYC
        requiresNotFrozen
    {
        uint256 newAllowance = allowance(_msgSender(), spender).sub(
            amount,
            "Amount greater than allowance."
        );
        _approve(_msgSender(), spender, newAllowance);
        emit DecreaseAllowance(_msgSender(), spender, newAllowance);
    }
}
