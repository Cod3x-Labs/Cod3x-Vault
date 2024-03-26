# CooldownUUPSUpgradeable Contract

## Introduction
The `CooldownUUPSUpgradeable` is an abstract contract designed to extend the functionality of OpenZeppelin's `UUPSUpgradeable` contracts with additional security features. This extension introduces a cooldown period for upgrades, enhancing the security of upgradeable contracts by enforcing a mandatory waiting period before an upgrade can be applied.

## Features
- **Cooldown Period:** Enforces a waiting period defined by `UPGRADE_TIMELOCK` (currently set to 48 hours) before an upgrade can be executed. This cooldown period starts from the moment an upgrade is unlocked.
- **Upgrade Lock:** Automatically locks the upgrade functionality for an extended period (effectively 100 years) to prevent further upgrades until explicitly unlocked.
- **Upgrade Authorization:** Requires a specific authorization mechanism to be defined in the implementing contract to allow for the upgrade, ensuring that only authorized entities can initiate the upgrade process.

## How to Use

### Initialization
To utilize the `CooldownUUPSUpgradeable` contract, your contract must inherit from it and implement the `_authorizeUpgrade` function with your access control logic.

1. **Inheritance:**
   Ensure your contract inherits from `CooldownUUPSUpgradeable`.

2. **Implement Authorization Logic:**
   Override the `_authorizeUpgrade` function to introduce your access control mechanism. This function should specify who is allowed to unlock and execute upgrades.

### Unlocking Upgrades
Before you can upgrade to a new implementation, you must unlock the upgrade process. This is done by calling the `_unlockUpgrade` function with the address of the new implementation. The cooldown period starts immediately.

### Executing Upgrades
Once the cooldown period has elapsed, an upgrade can be performed by calling the upgrade function provided by the UUPS pattern, typically through a proxy. The `_authorizeUpgrade` function will be automatically invoked to check if the upgrade is authorized and the cooldown period has passed.

### Locking Upgrades
To manually relock the upgrade functionality (e.g., after an upgrade is performed or to temporarily disable upgrades), call the `_lockUpgrade` function.

## Security Considerations
- The cooldown period is designed to prevent sudden, unauthorized upgrades by introducing a mandatory waiting time, allowing stakeholders to react.
- Implementers should ensure that the access control logic in `_authorizeUpgrade` is secure and robust to prevent unauthorized use.

## Example with access control

```solidity
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./CooldownUUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UpgradeableContract is CooldownUUPSUpgradeable, OwnableUpgradeable {
    function initialize() public initializer {
        __CooldownUUPSUpgradeable_init();
        __Ownable_init();
    }

    // External function to lock upgrades, with access control
    function lockUpgrade() external onlyOwner {
        _lockUpgrade();
    }

    // External function to unlock upgrades, with access control
    function unlockUpgrade(address newImplementation) external onlyOwner {
        _unlockUpgrade(newImplementation);
    }

    // Override _authorizeUpgrade to provide specific logic for upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        _authorizeUpgrade(newImplementation);
    }
}
```
