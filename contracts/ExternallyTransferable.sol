// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.1;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./Context.sol";

abstract contract ExternallyTransferable is ContextAware {
    using SafeMath for uint256;

    // address => string (network URI) => bytes (external address) => amount
    mapping(address => mapping(string => mapping(bytes => uint256)))
        private _externalAllowances;

    function externalAllowanceOf(
        address owner,
        string memory networkURI,
        bytes memory externalAddress
    ) public view returns (uint256) {
        return _externalAllowances[owner][networkURI][externalAddress];
    }

    // User calls to allocate external transfer
    function approveExternalTransfer(
        string memory networkURI,
        bytes memory externalAddress,
        uint256 amount
    ) public virtual {
        _approveExternalAllowance(_msgSender(), networkURI, externalAddress, amount);
    }

    // Bridge calls after externalTransfer
    function _approveExternalAllowance(
        address from,
        string memory networkURI,
        bytes memory to,
        uint256 amount
    ) internal virtual {
        require(_msgSender() != address(0), "Approve from the zero address");
        require(from != address(0), "Approve for the zero address");
        _externalAllowances[from][networkURI][to] = amount;
    }

    // Bridge calls to burn coins on this network (sending external transfer)
    function externalTransfer(
        address from,
        string memory networkURI,
        bytes memory to, // external address
        uint256 amount
    ) public virtual {}

    // Bridge calls to mint coins on this network (receiving external transfer)
    function externalTransferFrom(
        bytes memory from, // external address
        string memory networkURI,
        address to,
        uint256 amount
    ) public virtual {}
}
