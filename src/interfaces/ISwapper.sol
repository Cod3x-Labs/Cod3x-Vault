// SPDX-License-Identifier: BUSL1.1

pragma solidity ^0.8.0;

import "./IThenaRamRouter.sol";
import "./ISwapperSwaps.sol";

interface ISwapper is ISwapperSwaps {
    function uniV2SwapPaths(address _from, address _to, address _router, uint256 _index) external returns (address);

    function balSwapPoolIDs(address _from, address _to, address _vault) external returns (bytes32);

    function thenaRamSwapPaths(address _from, address _to, address _router, uint256 _index)
        external
        returns (IThenaRamRouter.route memory route);

    function uniV3SwapPaths(address _from, address _to, address _router) external view returns (UniV3SwapData memory);

    function aggregatorData(address _token) external returns (address, uint256);

    function updateUniV2SwapPath(address _tokenIn, address _tokenOut, address _router, address[] memory _path)
        external;

    function updateBalSwapPoolID(address _tokenIn, address _tokenOut, address _vault, bytes32 _poolID) external;

    function updateThenaRamSwapPath(
        address _tokenIn,
        address _tokenOut,
        address _router,
        IThenaRamRouter.route[] memory _path
    ) external;

    function updateUniV3SwapPath(
        address _tokenIn,
        address _tokenOut,
        address _router,
        UniV3SwapData memory _swapPathAndFees
    ) external;

    function updateTokenAggregator(address _token, address _aggregator, uint256 _timeout) external;

    /**
     * Returns asset price from the Chainlink aggregator with 18 decimal precision.
     * Reverts if:
     * - asset doesn't have an aggregator registered
     * - asset's aggregator is considered broken (doesn't have valid historical response)
     * - asset's aggregator is considered frozen (last response exceeds asset's allowed timeout)
     */
    function getChainlinkPriceTargetDigits(address _token) external view returns (uint256 price);
}
