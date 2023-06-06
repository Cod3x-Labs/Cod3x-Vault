// SPDX-License-Identifier: BUSL1.1

pragma solidity ^0.8.0;

interface ISwapper {
    enum MinAmountOutKind {
        Absolute,
        CLBased
    }

    struct MinAmountOutData {
        MinAmountOutKind kind;
        uint256 value; // for type "CLBased", value must be in BPS
    }

    function updateUniV2SwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        external;

    function updateBalSwapPoolID(address _tokenIn, address _tokenOut, address _vault, bytes32 _poolID) external;

    function updateVeloSwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        external;

    function updateUniV3SwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        external;

    function updateUniV3Quoter(address _router, address _quoter) external;

    function swapUniV2(
        address _from,
        address _to,
        uint256 _amount,
        MinAmountOutData memory _minAmountOutData,
        address _router
    ) external;

    function swapBal(
        address _from,
        address _to,
        uint256 _amount,
        MinAmountOutData memory _minAmountOutData,
        address _vault
    ) external;

    function swapVelo(
        address _from,
        address _to,
        uint256 _amount,
        MinAmountOutData memory _minAmountOutData,
        address _router
    ) external;

    function swapUniV3(
        address _from,
        address _to,
        uint256 _amount,
        MinAmountOutData memory _minAmountOutData,
        address _router
    ) external;
}
