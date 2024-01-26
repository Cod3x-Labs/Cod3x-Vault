// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IThenaRamFactory {
    function isPair(address pair) external view returns (bool);

    function getPair(
        address tokenA,
        address token,
        bool stable
    ) external view returns (address);
}
