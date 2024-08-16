// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IFeeController {
    function fetchManagementFeeBPS() external view returns (uint16);
    function updateManagementFeeBPS(uint16 _feeBPS) external;
}
