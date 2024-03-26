// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {ERC20} from "oz/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
}
