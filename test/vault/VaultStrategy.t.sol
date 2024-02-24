// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {VaultBaseTest} from "./VaultBase.t.sol";
import {StrategyMock} from "../mock/StrategyMock.sol";

contract VaultStrategyTest is VaultBaseTest {
    function testGivenNonDefaultAdminRoleWhenAddStrategyThenReverts() public {
        address[] memory nonDefaultAdminRoles = new address[](4);
        nonDefaultAdminRoles[0] = ADMIN.addr;
        nonDefaultAdminRoles[1] = GUARDIAN.addr;
        nonDefaultAdminRoles[2] = STRATEGIST.addr;
        nonDefaultAdminRoles[3] = makeAddr("RANDOM_ADDR");

        for (uint8 i = 0; i < nonDefaultAdminRoles.length; i++) {
            vm.startPrank(nonDefaultAdminRoles[i]);
            vm.expectRevert("Unauthorized access");

            sut.addStrategy(address(strategyMock), 0, 0);

            vm.stopPrank();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   ADD_STRATEGY() TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function testGivenEmergencyShutdwnWhenAddStrategyThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.setEmergencyShutdown(true);

        vm.expectRevert("Cannot add strategy during emergency shutdown");

        sut.addStrategy(address(strategyMock), 0, 0);
    }

    function testGivenZeroStrategyAddressWhenAddStrategyThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);

        vm.expectRevert("Invalid strategy address");

        sut.addStrategy(address(0), 0, 0);
    }

    function testGivenStrategyAlreadActivatedWhenAddStrategyThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), 0, 0);

        vm.expectRevert("Strategy already added");

        sut.addStrategy(address(strategyMock), 0, 0);
    }

    function testGivenDifferentVaultAddressInStrategyWhenAddStrategyThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        strategyMock.setVaultAddress(makeAddr(""));

        vm.expectRevert("Strategy's vault does not match");

        sut.addStrategy(address(strategyMock), 0, 0);
    }

    function testGivenDifferentWantAddressInStrategyWhenAddStrategyThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        strategyMock.setWantAddress(makeAddr(""));

        vm.expectRevert("Strategy's want does not match");

        sut.addStrategy(address(strategyMock), 0, 0);
    }

    function testGivenHigherFeeBPSWhenAddStrategyThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);

        vm.expectRevert("Fee cannot be higher than 20 BPS");

        sut.addStrategy(address(strategyMock), 2_000 + 1, 0);
    }

    function testGivenInvalidAllocationBPSWhenAddStrategyThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);

        vm.expectRevert("Invalid allocBPS value");

        sut.addStrategy(address(strategyMock), 0, 10_000 + 1);
    }

    function testGivenNewStrategyWhenAddStrategyThenStrategyIsAdded() public {
        vm.startPrank(DEFAULT_ADMIN.addr);

        sut.addStrategy(address(strategyMock), 2_000, 10_000);

        uint256 startTime = block.timestamp;

        (
            uint256 activation,
            uint256 feeBPS,
            uint256 allocBPS,
            uint256 allocated,
            uint256 gains,
            uint256 losses,
            uint256 lastReport
        ) = sut.strategies(address(strategyMock));

        uint256 endTime = block.timestamp;

        assertTrue(
            activation >= startTime && activation <= endTime, "Strategy activation should be within the expected range"
        );
        assertEq(feeBPS, 2_000, "Stratey feeBPS should be set correctly");
        assertEq(allocBPS, 10_000, "Stratey allocBPS should be set correctly");
        assertEq(allocated, 0, "Stratey allocated should be zero");
        assertEq(gains, 0, "Stratey gains should be zero");
        assertEq(losses, 0, "Stratey losses should be zero");
        assertTrue(
            lastReport >= startTime && lastReport <= endTime, "Strategy lastReport should be within the expected range"
        );
    }

    function testGivenNewStrategyWhenAddStrategyThenTotalAllocBPSIsSet() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        StrategyMock initialStrategyMock = new StrategyMock();
        initialStrategyMock.setVaultAddress(address(sut));
        initialStrategyMock.setWantAddress(address(sut.token()));
        sut.addStrategy(address(initialStrategyMock), 2_000, 3_000);

        sut.addStrategy(address(strategyMock), 2_000, 3_000);

        assertEq(sut.totalAllocBPS(), 6_000, "Strategy allocBPS should be added to a totalAllocBPS");
    }

    function testGivenNewStrategyWhenAddStrategyThenStrategyIsPushedToWithdrawalQueue() public {
        vm.startPrank(DEFAULT_ADMIN.addr);

        sut.addStrategy(address(strategyMock), 2_000, 3_000);

        assertEq(sut.withdrawalQueue(0), address(strategyMock), "WithdrawalQueue should contain Strategy address");
    }

    function testGivenNewStrategyWhenAddStrategyThenEventIsEmitted() public {
        vm.startPrank(DEFAULT_ADMIN.addr);

        vm.expectEmit();
        emit VaultBaseTest.StrategyAdded(address(strategyMock), 2_000, 3_000);

        sut.addStrategy(address(strategyMock), 2_000, 3_000);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   UPDATE_STRATEGY_FEE_BPS() TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function testGivenNonAdminRoleWhenUpdateStrategyFeeThenReverts() public {
        address[] memory nonDefaultAdminRoles = new address[](3);
        nonDefaultAdminRoles[0] = GUARDIAN.addr;
        nonDefaultAdminRoles[1] = STRATEGIST.addr;
        nonDefaultAdminRoles[2] = makeAddr("RANDOM_ADDR");

        for (uint8 i = 0; i < nonDefaultAdminRoles.length; i++) {
            vm.startPrank(nonDefaultAdminRoles[i]);
            vm.expectRevert("Unauthorized access");

            sut.updateStrategyFeeBPS(address(strategyMock), 0);

            vm.stopPrank();
        }
    }

    function testGivenNonActivatedStrategyWhenUpdateStrategyFeeThenReverts() public {
        vm.startPrank(ADMIN.addr);
        address nonActivatedStrategy = makeAddr("STR");

        vm.expectRevert("Invalid strategy address");

        sut.updateStrategyFeeBPS(nonActivatedStrategy, 0);
    }

    function testGivenTooHighFeeWhenUpdateStrategyFeeThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), 0, 0);

        vm.expectRevert("Fee cannot be higher than 20 BPS");

        sut.updateStrategyFeeBPS(address(strategyMock), 2000 + 1);
    }

    function testGivenFeeWhenUpdateStrategyFeeThenUpdatesFee() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), 1000, 0);

        uint256 updatedFeeBPS = 2000;
        sut.updateStrategyFeeBPS(address(strategyMock), 2000);

        (, uint256 feeBPS,,,,,) = sut.strategies(address(strategyMock));

        assertEq(feeBPS, updatedFeeBPS);
    }

    function testGivenFeeWhenUpdateStrategyFeeThenEventEmitted() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), 1000, 0);
        uint256 updatedFee = 2_000;

        vm.expectEmit();
        emit VaultBaseTest.StrategyFeeBPSUpdated(address(strategyMock), updatedFee);

        sut.updateStrategyFeeBPS(address(strategyMock), updatedFee);
    }
}
