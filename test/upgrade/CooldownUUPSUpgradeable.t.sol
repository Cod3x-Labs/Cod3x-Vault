// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {CooldownUUPSUpgradeableImpl} from "./CooldownUUPSUpgradeableImpl.sol";
import {CooldownUUPSUpgradeableImplV2} from "./CooldownUUPSUpgradeableImplV2.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

contract CooldownUUPSUpgradeableTest is Test {
    CooldownUUPSUpgradeableImpl private sut;
    uint256 internal constant MOCKED_BLOCK_TIMESTAMP = 1700000000;

    event Initialized(uint8 version);
    event UpgradeUnlocked(address newImplementation, uint256 upgradeUnlocksAt);
    event UpgradeLocked(uint256 upgradeUnlocksAt);

    function setUp() public {
        _deployWithProxy();
        vm.warp(MOCKED_BLOCK_TIMESTAMP);
    }

    function testGivenChildContractWhenInstantiateThenDisablesInitialization() public {
        vm.expectEmit();
        emit CooldownUUPSUpgradeableTest.Initialized(type(uint8).max);

        _deployWithProxy();
    }

    function testGivenMockedTimestampWhenInitializeThenLocksUpgrade() public {
        sut.initialize();

        assertEq(sut.upgradeUnlocksAt(), MOCKED_BLOCK_TIMESTAMP + 100 * 365 days);
    }

    function testGivenMockedTimestampWhenUnlockUpgradeThenUpgradeLockUpdated() public {
        sut.initialize();

        address newImplementationAddr = makeAddr("newImplementation");

        sut.unlockUpgrade(newImplementationAddr);

        assertEq(sut.upgradeUnlocksAt(), MOCKED_BLOCK_TIMESTAMP + 48 hours);
        assertEq(sut.newImplementation(), newImplementationAddr);
    }

    function testGivenMockedTimestampWhenUnlockUpgradeThenEventEmitted() public {
        sut.initialize();

        address newImplementationAddr = makeAddr("newImplementation");

        vm.expectEmit();
        emit CooldownUUPSUpgradeableTest.UpgradeUnlocked(newImplementationAddr, MOCKED_BLOCK_TIMESTAMP + 48 hours);

        sut.unlockUpgrade(newImplementationAddr);
    }

    function testGivenMockedTimestampWhenLockUpgradeThenUpgradeLockUpdated() public {
        sut.initialize();
        uint256 mockedTimeStamp = 1500000000;

        vm.warp(mockedTimeStamp);
        sut.lockUpgrade();

        assertEq(sut.upgradeUnlocksAt(), mockedTimeStamp + 100 * 365 days);
    }

    function testGivenMockedTimestampWhenLockUpgradeThenEventEmitted() public {
        sut.initialize();

        vm.expectEmit();
        emit CooldownUUPSUpgradeableTest.UpgradeLocked(MOCKED_BLOCK_TIMESTAMP + 100 * 365 days);

        sut.lockUpgrade();
    }

    function testGivenMockedTimestampWhenLockUpgradeThenAddressIsSetToZero() public {
        sut.initialize();

        sut.unlockUpgrade(makeAddr("newImplementation"));
        sut.lockUpgrade();

        assertEq(sut.newImplementation(), address(0));
    }

    function testGivenCooldownLockWhenUpgradeThenRevertsWithError() public {
        sut.initialize();
        CooldownUUPSUpgradeableImplV2 v2 = new CooldownUUPSUpgradeableImplV2();

        bytes4 errorSelector = bytes4(keccak256("UpgradeIsLocked(uint256)"));

        vm.expectRevert(abi.encodeWithSelector(errorSelector, sut.upgradeUnlocksAt()));

        sut.upgradeTo(address(v2));
    }

    function testGivenWrongImplementationAddressWhenUpgradeThenRevertsWithError() public {
        sut.initialize();
        CooldownUUPSUpgradeableImplV2 v2 = new CooldownUUPSUpgradeableImplV2();
        sut.unlockUpgrade(address(v2));
        skip(sut.upgradeUnlocksAt() + 10);

        address invlaidImplementationAddr = makeAddr("RANDOM_ADDR");

        bytes4 errorSelector = bytes4(keccak256("InvalidNewImplementationAddress(address,address)"));
        vm.expectRevert(abi.encodeWithSelector(errorSelector, address(v2), invlaidImplementationAddr));

        sut.upgradeTo(invlaidImplementationAddr);
    }

    function testGivenCorrectInputWhenUpgradeThenUpgrades() public {
        sut.initialize();
        CooldownUUPSUpgradeableImplV2 v2 = new CooldownUUPSUpgradeableImplV2();
        sut.unlockUpgrade(address(v2));
        skip(sut.upgradeUnlocksAt() + 10);

        sut.upgradeTo(address(v2));

        string memory version = v2.version();

        assertEq("v2", version);
    }

    function _deployWithProxy() private {
        sut = new CooldownUUPSUpgradeableImpl();
        ERC1967Proxy proxy = new ERC1967Proxy(address(sut), "");
        sut = CooldownUUPSUpgradeableImpl(address(proxy));
    }
}
