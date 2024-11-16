// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MobiToken is ERC20, ERC20Permit {
    constructor() ERC20("MobiToken", "MOBI") ERC20Permit("MobiToken") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}