// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {VaultBaseTest} from "./VaultBase.t.sol";
import {Math} from "oz/utils/math/Math.sol";

contract VaultReportTest is VaultBaseTest {
    function testGivenNonAuthorizedStrategyWhenReportThenReverts() public {
        vm.expectRevert("Unauthorized strategy");

        vm.startPrank(makeAddr("NON_AUTH_STRATEGY_ADDR"));
        sut.report(0, 0);
    }

    function testGivenStrategyLossHigherThanAllocationWhenReportThenReverts() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), 0, 0);

        vm.expectRevert("Strategy loss cannot be greater than allocation");

        vm.startPrank(address(strategyMock));
        sut.report(-2_000, 0);
    }

    function testGivenReportWithZeroROIAndRepaymentWhenStarategyAllocationZeroThenNoFeesMinted() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), 2_000, 5_000); //2000 = 20%, 5000 = 50%

        _depositToVault(500_000 * 10 ** sut.decimals());

        vm.startPrank(address(strategyMock));
        sut.report(0, 0);

        assertEq(sut.balanceOf(TREASURY.addr), 0);
    }

    function testGivenReportWithZeroROIAndRepaymentWhenStarategyAllocationZeroThenSuccesfullyAllocates() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        uint256 stratAllocationBPS = 5_000; //50%
        sut.addStrategy(address(strategyMock), 0, stratAllocationBPS);

        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        _depositToVault(vaultDepositBalance);

        vm.startPrank(address(strategyMock));
        uint256 strategyDebt = sut.report(0, 0);

        (,,, uint256 allocated,,, uint256 lastReport) = sut.strategies(address(strategyMock));

        uint256 expectedStartAllocation = vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR();
        assertEq(allocated, expectedStartAllocation);
        assertEq(sut.totalAllocated(), expectedStartAllocation);
        assertEq(sut.totalIdle(), vaultDepositBalance - expectedStartAllocation);
        assertEq(sut.lockedProfit(), 0);
        assertEq(assetMock.balanceOf(address(strategyMock)), expectedStartAllocation);
        assertEq(sut.lastReport(), block.timestamp);
        assertEq(lastReport, block.timestamp);
        assertEq(strategyDebt, 0);
    }

    function testGivenReportWithZeroROIAndRepaymentWhenStarategyAllocationZeroThenEventEmitted() public {
        vm.startPrank(DEFAULT_ADMIN.addr);
        uint256 stratAllocationBPS = 5_000; //50%
        sut.addStrategy(address(strategyMock), 0, stratAllocationBPS);

        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        _depositToVault(vaultDepositBalance);

        uint256 expectedStartAllocation = vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR();
        vm.expectEmit();
        emit VaultBaseTest.StrategyReported(
            address(strategyMock), 0, 0, 0, 0, 0, expectedStartAllocation, expectedStartAllocation, stratAllocationBPS
        );

        vm.startPrank(address(strategyMock));
        sut.report(0, 0);
    }

    function testGivenStrategyLossWhenVaultTotalAllocationBPSNotZeroThenAllocValuesUpdated() public {
        uint256 stratAllocationBPS = 5_000; //50%
        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        _simulateStratInitialAllocation(vaultDepositBalance, stratAllocationBPS);

        vm.startPrank(address(strategyMock));
        int256 roi = int256(20_000 * 10 ** sut.decimals());
        sut.report(-roi, 0);

        (,, uint256 allocBPSBefore,,,,) = sut.strategies(address(strategyMock));
        uint256 expectedBPSChange =
            Math.min((uint256(roi) * sut.totalAllocBPS()) / sut.totalAllocated(), allocBPSBefore);
        uint256 expectedStartAllocationBPS = stratAllocationBPS - expectedBPSChange;
        uint256 expectedTotalAllocationBPS = stratAllocationBPS - expectedBPSChange;
        (,, uint256 allocBPSAfter,,,,) = sut.strategies(address(strategyMock));
        assertEq(expectedStartAllocationBPS, allocBPSAfter);
        assertEq(expectedTotalAllocationBPS, sut.totalAllocBPS());
    }

    function _simulateStratInitialAllocation(uint256 vaultBalance, uint256 startAllocationBPS) private {
        _addStrategy(startAllocationBPS);
        _depositToVault(vaultBalance);

        vm.startPrank(address(strategyMock));
        sut.report(0, 0);
    }

    function _addStrategy(uint256 allocationBPS) private {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), 0, allocationBPS);
    }

    function _depositToVault(uint256 amount) private {
        address depositor = makeAddr("depositor");
        deal(address(assetMock), depositor, amount);

        vm.startPrank(depositor);
        assetMock.approve(address(sut), amount);
        sut.deposit(amount);
    }
}
