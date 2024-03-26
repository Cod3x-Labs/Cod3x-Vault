// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {CooldownUUPSUpgradeable} from "../../src/mixins/upgrade/CooldownUUPSUpgradeable.sol";

contract CooldownUUPSUpgradeableImpl is CooldownUUPSUpgradeable {
    /* solhint-disable no-empty-blocks */
    function initialize() public initializer {
        __CooldownUUPSUpgradeable_init();
    }

    function _authorizeUpgrade() internal override {}

    function unlockUpgrade(address _newImplementation) external {
        _unlockUpgrade(_newImplementation);
    }

    function lockUpgrade() external {
        _lockUpgrade();
    }
}
