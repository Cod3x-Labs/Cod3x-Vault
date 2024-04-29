// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "oz-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ICooldownUUPSUpgradeable} from "./ICooldownUUPSUpgradeable.sol";

abstract contract CooldownUUPSUpgradeable is UUPSUpgradeable, ICooldownUUPSUpgradeable {
    uint256 public upgradeUnlocksAt;
    address public newImplementation;
    uint256 public constant UPGRADE_TIMELOCK = 48 hours;
    uint256 public constant ONE_YEAR = 365 days;

    constructor() {
        _disableInitializers();
    }

    /* solhint-disable func-name-mixedcase */
    function __CooldownUUPSUpgradeable_init() internal onlyInitializing {
        __UUPSUpgradeable_init();
        _lockUpgrade();
    }

    /**
     * @dev This function must be called prior to upgrading the implementation.
     *      It's required to wait {upgradeUnlocksAt} seconds before executing the upgrade.
     */
    function _unlockUpgrade(address _newImplementation) internal {
        newImplementation = _newImplementation;
        upgradeUnlocksAt = _now() + UPGRADE_TIMELOCK;

        emit UpgradeUnlocked(_newImplementation, upgradeUnlocksAt);
    }

    /**
     * @dev This function is called:
     *      - during initialization
     *      - as part of a successful upgrade
     *      - manually to lock the upgrade.
     */
    function _lockUpgrade() internal {
        upgradeUnlocksAt = _now() + (ONE_YEAR * 100);
        newImplementation = address(0);

        emit UpgradeLocked(upgradeUnlocksAt);
    }

    /**
     * @dev This function must be overriden simply for access control purposes.
     *      Only authorized role can upgrade the implementation once the timelock
     *      has passed.
     */
    function _authorizeUpgrade(address _newImplementation) internal override {
        _authorizeUpgrade();
        if (!_timePassed(upgradeUnlocksAt)) {
            revert UpgradeIsLocked(upgradeUnlocksAt);
        }

        if (_newImplementation != newImplementation) {
            revert InvalidNewImplementationAddress(newImplementation, _newImplementation);
        }
        _lockUpgrade();
    }

    function _timePassed(uint256 time) private view returns (bool) {
        return time < _now();
    }

    function _now() private view returns (uint256) {
        return block.timestamp;
    }

    function _authorizeUpgrade() internal virtual;
}
