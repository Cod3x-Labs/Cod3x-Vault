// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {IFeeController} from "../../../src/interfaces/IFeeController.sol";

contract FeeControllerMock is IFeeController {
    uint16 public managementFeeBPS;

    function fetchManagementFeeBPS() external view returns (uint16) {
        return managementFeeBPS;
    }

    function updateManagementFeeBPS(uint16 _feeBPS) external {
        managementFeeBPS = _feeBPS;
    }
}
