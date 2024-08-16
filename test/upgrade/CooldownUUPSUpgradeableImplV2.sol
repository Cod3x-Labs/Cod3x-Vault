// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {CooldownUUPSUpgradeableImpl} from "./CooldownUUPSUpgradeableImpl.sol";

contract CooldownUUPSUpgradeableImplV2 is CooldownUUPSUpgradeableImpl {
    function version() external pure returns (string memory) {
        return "v2";
    }
}
