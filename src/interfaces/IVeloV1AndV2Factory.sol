// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVeloV1AndV2Factory {
    function isPool(address pool) external view returns (bool);
    function getPool(address tokenA, address token, bool stable) external view returns (address);
}
