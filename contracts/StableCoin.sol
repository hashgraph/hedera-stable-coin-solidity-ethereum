// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.1;

import "./Context.sol";
import "./Pausable.sol";
import "./Ownable.sol";
import "./AccessControl.sol";
import "./ERC20.sol";
import "./ExternallyTransferable.sol";

contract StableCoin is
    ContextAware, // provides _msgSender(), _msgData()
    Pausable, // provides _pause(), _unpause()
    Ownable, // Ownable, Claimable
    AccessControl, // RBAC for KYC, Frozen
    ERC20, // ERC20 Functions (transfer, balance, allowance, mint, burn)
    ExternallyTransferable // Supports External Transfers
{
    // Defined Roles
    bytes32 private constant KYC_PASSED = keccak256("KYC_PASSED");
    bytes32 private constant FROZEN = keccak256("FROZEN");

    // Special People
    address private _supplyManager;
    address private _complianceManager;
    address private _enforcementManager;

    // Events Emitted
    event Constructed(
        string tokenName,
        string tokenSymbol,
        uint8 tokenDecimal,
        uint256 totalSupply,
        address supplyManager,
        address complianceManager,
        address enforcementManager
    );

    // Privileged Roles
    event ChangeSupplyManager(address newSupplyManager);
    event ChangeComplianceManager(address newComplianceManager);
    event ChangeEnforcementManager(address newEnforcementManager);

    // ERC20+
    event Wipe(address account, uint256 amount);
    event Mint(address account, uint256 amount);
    event Burn(address account, uint256 amount);
    event Transfer(address sender, address recipient, uint256 amount);
    event Approve(address sender, address spender, uint256 amount);
    event IncreaseAllowance(address sender, address spender, uint256 amount);
    event DecreaseAllowance(address sender, address spender, uint256 amount);

    // KYC
    event Freeze(address account); // Freeze: Freeze this account
    event Unfreeze(address account);
    event SetKycPassed(address account);
    event UnsetKycPassed(address account);

    // Halt
    event Pause(address sender); // Pause: Pause entire contract
    event Unpause(address sender);

    // "External Transfer"
    // Signify to the coin bridge to perform external transfer
    event ApproveExternalTransfer(
        address from,
        string networkURI,
        bytes to,
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
        address complianceManager,
        address enforcementManager
    ) public ERC20(tokenName, tokenSymbol, tokenDecimal) {
        _supplyManager = supplyManager;
        _complianceManager = complianceManager;
        _enforcementManager = enforcementManager;

        // Owner has Admin Privileges on all roles
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender()); // sudo role

        // Give CM ability to grant/revoke roles (but not admin of this role)
        grantRole(DEFAULT_ADMIN_ROLE, complianceManager);

        // KYC accounts
        grantRole(KYC_PASSED, _msgSender());
        grantRole(KYC_PASSED, supplyManager);
        grantRole(KYC_PASSED, complianceManager);
        grantRole(KYC_PASSED, enforcementManager);

        // Give supply manager all tokens
        mint(totalSupply); // Emits Mint

        // Did it
        emit Constructed(
            tokenName,
            tokenSymbol,
            tokenDecimal,
            totalSupply,
            supplyManager,
            complianceManager,
            enforcementManager
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

    function complianceManager() public view returns (address) {
        return _complianceManager;
    }

    modifier onlyComplianceManager() {
        require(
            _msgSender() == complianceManager() || _msgSender() == owner(),
            "Only the Compliance Manager can call this function."
        );
        _;
    }

    function changeComplianceManager(address newComplianceManager)
        public
        onlyOwner
    {
        require(
            newComplianceManager != address(0),
            "Cannot change compliance manager to 0x0."
        );
        revokeRole(KYC_PASSED, _complianceManager);
        _complianceManager = newComplianceManager;
        grantRole(KYC_PASSED, _complianceManager);
        revokeRole(FROZEN, _complianceManager);
        emit ChangeComplianceManager(newComplianceManager);
    }

    function enforcementManager() public view returns (address) {
        return _enforcementManager;
    }

    modifier onlyEnforcementManager() {
        require(
            _msgSender() == enforcementManager() || _msgSender() == owner(),
            "Only the Enforcement Manager can call this function."
        );
        _;
    }

    function changeEnforcementManager(address newEnforcementManager)
        public
        onlyOwner
    {
        require(
            newEnforcementManager != address(0),
            "Cannot change enforcement manager to 0x0"
        );
        revokeRole(KYC_PASSED, _enforcementManager);
        _enforcementManager = newEnforcementManager;
        grantRole(KYC_PASSED, _enforcementManager);
        revokeRole(FROZEN, _enforcementManager);
        emit ChangeEnforcementManager(newEnforcementManager);
    }

    function isPrivilegedRole(address account) public view returns (bool) {
        return
            account == supplyManager() ||
            account == complianceManager() ||
            account == enforcementManager() ||
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

    // KYC: only CM
    function setKycPassed(address account) public onlyComplianceManager {
        grantRole(KYC_PASSED, account);
        emit SetKycPassed(account);
    }

    // Un-KYC: only CM, only non-privileged accounts
    function unsetKycPassed(address account) public onlyComplianceManager {
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

    // Freeze an account: only CM, only non-privileged accounts
    function freeze(address account) public onlyComplianceManager {
        require(
            !isPrivilegedRole(account),
            "Cannot freeze administrator account."
        );
        require(account != address(0), "Cannot freeze address 0x0.");
        grantRole(FROZEN, account);
        emit Freeze(account);
    }

    // Unfreeze an account: only CM
    function unfreeze(address account) public onlyComplianceManager {
        revokeRole(FROZEN, account);
        emit Unfreeze(account);
    }

    // Check Transfer Allowed (user facing)
    function checkTransferAllowed(address account) public view returns (bool) {
        return isKycPassed(account) && !isFrozen(account);
    }

    // Pause: Only CM
    function pause() public onlyComplianceManager {
        _pause();
        emit Pause(_msgSender());
    }

    // Unpause: Only CM
    function unpause() public onlyComplianceManager {
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
    function wipe(address account) public onlyEnforcementManager {
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
        require(isKycPassed(from), "Sender account requires KYC to continue.");
        require(isKycPassed(to), "Receiver account requires KYC to continue.");
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
        string memory networkURI,
        bytes memory externalAddress,
        uint256 amount
    )
        public
        override(ExternallyTransferable)
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
        string memory networkURI,
        bytes memory to,
        uint256 amount
    ) public override(ExternallyTransferable) onlySupplyManager whenNotPaused {
        require(isKycPassed(from), "Spender account requires KYC to continue.");
        require(!isFrozen(from), "Spender account is frozen.");
        uint256 exAllowance = externalAllowanceOf(from, networkURI, to);
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
        bytes memory from,
        string memory networkURI,
        address to,
        uint256 amount
    ) public override(ExternallyTransferable) onlySupplyManager whenNotPaused {
        require(isKycPassed(to), "Recipient account requires KYC to continue.");
        require(!isFrozen(to), "Recipient account is frozen.");
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
        require(isKycPassed(spender), "Spender account requires KYC to continue.");
        require(isKycPassed(sender), "Sender account requires KYC to continue.");
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
