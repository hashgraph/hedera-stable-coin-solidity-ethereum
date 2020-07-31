// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/application/App.sol";

contract Hbar is Initializable {
    App private app;
    address private owner;

    function initialize(App _app) public initializer {
        app = _app;
        owner = msg.sender;
    }
}
