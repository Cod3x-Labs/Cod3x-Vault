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

    function testGivenReportWithZeroROIAndRepaymentWhenStarategyAllocationZeroThenNoFeesMinted() public {
        _addStrategy(2_000, 5_000); //2000 = 20%, 5000 = 50%

        _depositToVault(500_000 * 10 ** sut.decimals());

        vm.startPrank(address(strategyMock));
        sut.report(0, 0);

        assertEq(sut.balanceOf(TREASURY.addr), 0);
    }

    function testGivenReportWithZeroROIAndRepaymentWhenStarategyAllocationZeroThenSuccesfullyAllocates() public {
        uint256 stratAllocationBPS = 5_000; //50%
        _addStrategy(0, stratAllocationBPS);

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
        uint256 stratAllocationBPS = 5_000; //50%
        _addStrategy(0, stratAllocationBPS);

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

    /*//////////////////////////////////////////////////////////////////////////
                                   STRATEGY LOSS
    //////////////////////////////////////////////////////////////////////////*/
    function testGivenStrategyLossHigherThanAllocationWhenReportThenReverts() public {
        _addStrategy(0, 0);

        vm.expectRevert("Strategy loss cannot be greater than allocation");

        vm.startPrank(address(strategyMock));
        sut.report(-2_000, 0);
    }

    function testGivenStrategyLossWhenVaultTotalAllocationBPSNotZeroThenAllocValuesUpdated() public {
        uint256 stratAllocationBPS = 5_000; //50%
        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        _simulateStratInitialAllocation(vaultDepositBalance, 0, stratAllocationBPS);

        vm.startPrank(address(strategyMock));
        int256 roi = int256(20_000 * 10 ** sut.decimals());
        uint256 strategyDebt = sut.report(-roi, 0);

        (,, uint256 allocBPS, uint256 allocated,,,) = sut.strategies(address(strategyMock));
        uint256 expectedBPSChange = Math.min((uint256(roi) * sut.totalAllocBPS()) / sut.totalAllocated(), allocBPS);
        uint256 expectedStartAllocationBPS = stratAllocationBPS - expectedBPSChange;
        uint256 expectedTotalAllocationBPS = stratAllocationBPS - expectedBPSChange;

        assertEq(expectedStartAllocationBPS, allocBPS);
        assertEq(expectedTotalAllocationBPS, sut.totalAllocBPS());
        assertEq(vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR() - uint256(roi), sut.totalAllocated());

        uint256 stratMaxAllocation = allocBPS * sut.balance() / sut.PERCENT_DIVISOR();
        uint256 expectedDebt = allocated - stratMaxAllocation;
        assertEq(strategyDebt, expectedDebt);
    }

    function testGivenStrategyLossWithRepaymentWhenVaultTotalAllocationBPSNotZeroThenAllocValuesUpdated() public {
        uint256 stratAllocationBPS = 5_000; //50%
        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        _simulateStratInitialAllocation(vaultDepositBalance, 0, stratAllocationBPS);

        vm.startPrank(address(strategyMock));
        int256 roi = int256(20_000 * 10 ** sut.decimals());
        uint256 repayment = 5_000 * 10 ** sut.decimals();
        strategyMock.approveVaultSpender();
        sut.report(-roi, repayment);

        (,,, uint256 allocated,,,) = sut.strategies(address(strategyMock));

        assertEq(
            vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR() - uint256(roi) - repayment,
            sut.totalAllocated()
        );

        uint256 expectedStartAllocation =
            vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR() - uint256(roi) - repayment;
        assertEq(expectedStartAllocation, allocated);
        assertEq(
            assetMock.balanceOf(address(strategyMock)),
            vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR() - repayment
        );
        assertEq(
            assetMock.balanceOf(address(sut)),
            vaultDepositBalance - (vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR()) + repayment
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   FEE TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function testGivenStrategyGainWhenReportThenPerformanceFeeApplied() public {
        uint256 stratAllocationBPS = 5_000; //50%
        uint256 stratFeeBPS = 1_000; //10%
        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        _simulateStratInitialAllocation(vaultDepositBalance, stratFeeBPS, stratAllocationBPS);

        vm.startPrank(address(strategyMock));
        int256 roi = int256(20_000 * 10 ** sut.decimals());

        strategyMock.approveVaultSpender();
        sut.report(roi, 0);

        uint256 expectedTreasuryBalance = uint256(roi) * stratFeeBPS / sut.PERCENT_DIVISOR();
        assertEq(sut.balanceOf(TREASURY.addr), expectedTreasuryBalance);
    }

    function testGivenManagementFeeWhenReportThenManagementFeeApplied(uint256 daysSinceLastReport) public {
        daysSinceLastReport = bound(daysSinceLastReport, 1, 5_000);
        uint256 stratAllocationBPS = 5_000; //50%
        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        uint256 startLastReportTime = block.timestamp;
        _simulateStratInitialAllocation(vaultDepositBalance, 0, stratAllocationBPS);

        strategyMock.approveVaultSpender();
        _timeTravel(startLastReportTime, daysSinceLastReport);
        sut.report(0, 0);

        uint256 strategyAllocation = vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR();
        uint256 duration = daysSinceLastReport * 1 days;
        uint256 expectedTreasuryBalance = strategyAllocation * duration * feeControllerMock.fetchManagementFeeBPS()
            / sut.PERCENT_DIVISOR() / sut.SECONDS_PER_YEAR();
        assertEq(sut.balanceOf(TREASURY.addr), expectedTreasuryBalance);
    }

    function testGivenManagementFeeAboveCapWhenReportThenDefaultsToManagementFeeCap() public {
        uint256 daysSinceLastReport = 100;
        uint256 stratAllocationBPS = 5_000; //50%
        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        uint256 startLastReportTime = block.timestamp;
        _simulateStratInitialAllocation(vaultDepositBalance, 0, stratAllocationBPS);

        strategyMock.approveVaultSpender();
        _timeTravel(startLastReportTime, daysSinceLastReport);
        feeControllerMock.updateManagementFeeBPS(MANAGEMENT_FEE_CAP_BPS + 2_000);
        sut.report(0, 0);

        uint256 strategyAllocation = vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR();
        uint256 duration = daysSinceLastReport * 1 days;
        uint16 expectedManagementFee = MANAGEMENT_FEE_CAP_BPS;
        uint256 expectedTreasuryBalance =
            strategyAllocation * duration * expectedManagementFee / sut.PERCENT_DIVISOR() / sut.SECONDS_PER_YEAR();
        assertEq(sut.balanceOf(TREASURY.addr), expectedTreasuryBalance);
    }

    function testGivenManagementAndPerformanceFeesWhenReportWithProfitThenBothFeesApplied(uint256 daysSinceLastReport)
        public
    {
        daysSinceLastReport = bound(daysSinceLastReport, 1, 5_000);
        uint256 stratAllocationBPS = 5_000; //50%
        uint256 stratFeeBPS = 1_000; //10%
        uint256 vaultDepositBalance = 500_000 * 10 ** sut.decimals();
        uint256 startLastReportTime = block.timestamp;
        _simulateStratInitialAllocation(vaultDepositBalance, stratFeeBPS, stratAllocationBPS);

        strategyMock.approveVaultSpender();
        _timeTravel(startLastReportTime, daysSinceLastReport);
        int256 roi = int256(20_000 * 10 ** sut.decimals());
        sut.report(roi, 0);

        uint256 strategyAllocation = vaultDepositBalance * stratAllocationBPS / sut.PERCENT_DIVISOR();
        uint256 duration = daysSinceLastReport * 1 days;
        uint256 expectedManagementFee = strategyAllocation * duration * feeControllerMock.fetchManagementFeeBPS()
            / sut.PERCENT_DIVISOR() / sut.SECONDS_PER_YEAR();
        uint256 expectedPerformanceFee = uint256(roi) * stratFeeBPS / sut.PERCENT_DIVISOR();
        assertEq(sut.balanceOf(TREASURY.addr), expectedManagementFee + expectedPerformanceFee);
    }

    function _simulateStratInitialAllocation(uint256 vaultBalance, uint256 startFeeBPS, uint256 startAllocationBPS)
        private
    {
        _addStrategy(startFeeBPS, startAllocationBPS);
        _depositToVault(vaultBalance);

        vm.startPrank(address(strategyMock));
        sut.report(0, 0);
    }
}
