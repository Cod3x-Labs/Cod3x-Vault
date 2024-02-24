// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "oz/token/ERC20/ERC20.sol";
import {ReaperVaultV2} from "../../src/ReaperVaultV2.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import {StrategyMock} from "../mock/StrategyMock.sol";

abstract contract VaultBaseTest is Test {
    ReaperVaultV2 internal sut;
    StrategyMock internal strategyMock;
    ERC20 internal assetMock;

    uint256 internal constant TVL_CAP = 1_000_000 * 1e12;
    uint16 internal constant MANAGEMENT_FEE_BPS = 200;

    Account internal DEFAULT_ADMIN = makeAccount("DEFAULT_ADMIN");
    Account internal ADMIN = makeAccount("ADMIN");
    Account internal GUARDIAN = makeAccount("GUARDIAN");
    Account internal STRATEGIST = makeAccount("STRATEGIST");

    event StrategyAdded(address indexed strategy, uint256 feeBPS, uint256 allocBPS);
    event StrategyFeeBPSUpdated(address indexed strategy, uint256 feeBPS);

    function setUp() public {
        assetMock = new ERC20Mock("mockAssetToken", "MAT");
        strategyMock = new StrategyMock();

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
            MANAGEMENT_FEE_BPS,
            makeAccount("TREASURY").addr,
            strategists,
            multisigRoles
        );

        strategyMock.setVaultAddress(address(sut));
        strategyMock.setWantAddress(address(sut.token()));

        vm.stopPrank();
    }
}
