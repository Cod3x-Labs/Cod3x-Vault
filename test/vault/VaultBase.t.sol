// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ReaperVaultV2} from "../../src/ReaperVaultV2.sol";
import {ERC20Mock} from "./mock/ERC20Mock.sol";
import {StrategyMock} from "./mock/StrategyMock.sol";
import {FeeControllerMock} from "./mock/FeeControllerMock.sol";

abstract contract VaultBaseTest is Test {
    ReaperVaultV2 internal sut;
    StrategyMock internal strategyMock;
    ERC20Mock internal assetMock;
    FeeControllerMock internal feeControllerMock;

    uint256 internal constant TVL_CAP = 1_000_000 * 1e18;
    uint16 internal constant MANAGEMENT_FEE_CAP_BPS = 5_000;
    uint256 internal ALLOCATION_CAP;

    Account internal TREASURY = makeAccount("TREASURY");
    Account internal DEFAULT_ADMIN = makeAccount("DEFAULT_ADMIN");
    Account internal ADMIN = makeAccount("ADMIN");
    Account internal GUARDIAN = makeAccount("GUARDIAN");
    Account internal STRATEGIST = makeAccount("STRATEGIST");
    Account internal KEEPER = makeAccount("KEEPER");

    event StrategyAdded(address indexed strategy, uint256 feeBPS, uint256 allocBPS);
    event StrategyFeeBPSUpdated(address indexed strategy, uint256 feeBPS);
    event StrategyRevoked(address indexed strategy);
    event StrategyReported(
        address indexed strategy,
        uint256 gain,
        uint256 loss,
        uint256 debtPaid,
        uint256 gains,
        uint256 losses,
        uint256 allocated,
        uint256 allocationAdded,
        uint256 allocBPS
    );

    function setUp() public {
        assetMock = new ERC20Mock("mockAssetToken", "MAT");
        feeControllerMock = new FeeControllerMock();
        feeControllerMock.updateManagementFeeBPS(500);

        address[] memory strategists = new address[](1);
        strategists[0] = STRATEGIST.addr;

        address[] memory multisigRoles = new address[](3);

        multisigRoles[0] = DEFAULT_ADMIN.addr;
        multisigRoles[1] = ADMIN.addr;
        multisigRoles[2] = GUARDIAN.addr;

        vm.startPrank(DEFAULT_ADMIN.addr);

        sut = new ReaperVaultV2(
            address(assetMock),
            "Vault",
            "V",
            TVL_CAP,
            MANAGEMENT_FEE_CAP_BPS,
            TREASURY.addr,
            strategists,
            multisigRoles,
            address(feeControllerMock)
        );

        strategyMock = new StrategyMock();
        strategyMock.setVaultAddress(address(sut));
        strategyMock.setWantAddress(address(sut.token()));

        ALLOCATION_CAP = sut.PERCENT_DIVISOR();

        vm.stopPrank();
    }

    function _depositToVault(uint256 amount) internal {
        address depositor = makeAddr("depositor");
        deal(address(assetMock), depositor, amount);

        vm.startPrank(depositor);
        assetMock.approve(address(sut), amount);
        sut.deposit(amount);
    }

    function _addStrategy(uint256 feeBPS, uint256 allocationBPS) internal {
        vm.startPrank(DEFAULT_ADMIN.addr);
        sut.addStrategy(address(strategyMock), feeBPS, allocationBPS);
    }

    function _timeTravel(uint256 startTime, uint256 daysToWarp) internal {
        uint256 warpToTime = startTime + (daysToWarp * 1 days);
        vm.warp(warpToTime);
    }
}
