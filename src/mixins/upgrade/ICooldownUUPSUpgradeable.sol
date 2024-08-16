// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface ICooldownUUPSUpgradeable {
    event UpgradeUnlocked(address newImplementation, uint256 upgradeUnlocksAt);
    event UpgradeLocked(uint256 upgradeUnlocksAt);

    error UpgradeIsLocked(uint256 until);
    error InvalidNewImplementationAddress(address expectedImplementation, address actualImplementation);

    function lockUpgrade() external;
    function unlockUpgrade(address _newImplementation) external;
}
