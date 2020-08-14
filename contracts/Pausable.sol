// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21;

import "./Context.sol";

contract Pausable is ContextAware {
    bool private _paused;

    constructor() public {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
    }
}
