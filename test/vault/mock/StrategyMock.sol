// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {IStrategy} from "../../../src/interfaces/IStrategy.sol";
import {IERC20} from "oz/token/ERC20/IERC20.sol";

contract StrategyMock is IStrategy {
    address public vaultAddress;
    address public wantAddress;

    function withdraw(uint256 _amount) external returns (uint256 loss) {}

    function harvest() external returns (int256 roi) {}

    function balanceOf() external view returns (uint256) {}

    function setVaultAddress(address vaultAddress_) external {
        vaultAddress = vaultAddress_;
    }

    function vault() external view returns (address) {
        return vaultAddress;
    }

    function setWantAddress(address wantAddress_) external {
        wantAddress = wantAddress_;
    }

    function want() external view returns (address) {
        return wantAddress;
    }

    function approveVaultSpender() external returns (bool) {
        return IERC20(wantAddress).approve(vaultAddress, type(uint256).max);
    }
}
