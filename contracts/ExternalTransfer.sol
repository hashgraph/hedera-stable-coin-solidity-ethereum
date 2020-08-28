// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.1;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./Context.sol";

abstract contract ExternalTransfer is ContextAware {
    using SafeMath for uint256;

    // address => string (network URI) => bytes (external address) => amount
    mapping(address => mapping(string => mapping(bytes => uint2565)))
        private _externalAllowances;

    function externalAllowanceOf(
        address owner,
        string networkURI,
        bytes externalAddress
    ) public view returns (uint256) {
        return _externalAllowances[owner][networkURI][externalAddress];
    }

    // User calls to allocate external transfer
    function approveExternalAllowance(
        string networkURI,
        bytes externalAddress,
        uint256 amount
    ) internal virtual {
        _approveExternalAllowance(_msgSender(), networkURI, externalAddress, amount);
    }

    // Bridge calls after externalTransfer
    function _approveExternalAllowance(
        address from,
        string networkURI,
        bytes to,
        uint256 amount
    ) internal virtual {
        require(_msgSender() != address(0), "Approve from the zero address");
        require(from != address(0), "Approve for the zero address");
        require(to != bytes(0), "Approve for external 0 address");
        _externalAllowances[from][networkURI][externalAddress] = amount;
    }

    // Bridge calls to burn coins on this network (sending external transfer)
    function externalTransfer(
        address from,
        string networkURI,
        bytes to, // external address
        uint256 amount
    ) internal virtual {}

    // Bridge calls to mint coins on this network (receiving external transfer)
    function externalTransferFrom(
        bytes from, // external address
        string networkURI,
        address to,
        uint256 amount
    ) internal virtual {}
}
