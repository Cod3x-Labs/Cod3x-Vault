// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../interfaces/ISwapErrors.sol";
import "../interfaces/ISwapRouter.sol";
import "../interfaces/ISwapper.sol";
import "../interfaces/IUniswapV3Factory.sol";
import "../libraries/TransferHelper.sol";

abstract contract UniV3Mixin is ISwapErrors {
    event UniV3SwapPathUpdated(
        address indexed from,
        address indexed to,
        address indexed router,
        UniV3SwapData swapData
    );

    /// @dev tokenA => (tokenB => (router => path)): returns best path to swap
    ///         tokenA to tokenB for the given router (protocol)
    mapping(address => mapping(address => mapping(address => UniV3SwapData)))
        internal _uniV3SwapPaths;

    function uniV3SwapPaths(
        address _tokenA,
        address _tokenB,
        address _router
    ) external view returns (UniV3SwapData memory) {
        return _uniV3SwapPaths[_tokenA][_tokenB][_router];
    }

    struct Params__swapUniV3 {
        address from;
        address to;
        uint256 amount;
        uint256 minAmountOut;
        address router;
        uint256 deadline;
        bool tryCatchActive;
    }

    function _swapUniV3(
        Params__swapUniV3 memory _params
    ) internal returns (uint256 amountOut) {
        if (_params.from == _params.to || _params.amount == 0) {
            return 0;
        }

        UniV3SwapData storage swapPathAndFees = _uniV3SwapPaths[_params.from][
            _params.to
        ][_params.router];
        address[] storage path = swapPathAndFees.path;
        uint24[] storage fees = swapPathAndFees.fees;
        require(
            path.length >= 2 && fees.length == path.length - 1,
            "Missing data for swap"
        );

        bytes memory pathBytes = _encodePathV3(path, fees);
        TransferHelper.safeApprove(path[0], _params.router, _params.amount);
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: pathBytes,
                recipient: address(this),
                deadline: _params.deadline,
                amountIn: _params.amount,
                amountOutMinimum: _params.minAmountOut
            });

        // Based on configurable param catch fails or just revert
        if (_params.tryCatchActive) {
            try ISwapRouter(_params.router).exactInput(params) returns (
                uint256 tmpAmountOut
            ) {
                amountOut = tmpAmountOut;
            } catch {
                TransferHelper.safeApprove(path[0], _params.router, 0);
                emit SwapFailed(
                    _params.router,
                    _params.amount,
                    _params.minAmountOut,
                    _params.from,
                    _params.to
                );
            }
        } else {
            amountOut = ISwapRouter(_params.router).exactInput(params);
        }
    }

    /// @dev Update {SwapPath} for a specified pair of tokens and router.
    function _updateUniV3SwapPath(
        address _tokenIn,
        address _tokenOut,
        address _router,
        UniV3SwapData memory _swapPathAndFees
    ) internal {
        address[] memory path = _swapPathAndFees.path;
        uint24[] memory fees = _swapPathAndFees.fees;
        require(
            _tokenIn != _tokenOut &&
                path.length >= 2 &&
                path[0] == _tokenIn &&
                path[path.length - 1] == _tokenOut &&
                fees.length == path.length - 1
        );
        IUniswapV3Factory factory = IUniswapV3Factory(
            ISwapRouter(_router).factory()
        );
        for (uint256 i = 0; i < fees.length; i++) {
            address pool = factory.getPool(path[i], path[i + 1], fees[i]);
            require(pool != address(0), "Pool does not exist");
            require(_isValidFee(fees[i]), "Invalid fee used");
        }

        _uniV3SwapPaths[_tokenIn][_tokenOut][_router] = _swapPathAndFees;
        emit UniV3SwapPathUpdated(
            _tokenIn,
            _tokenOut,
            _router,
            _swapPathAndFees
        );
    }

    // Be sure to permission this in implementation
    function updateUniV3SwapPath(
        address _tokenIn,
        address _tokenOut,
        address _router,
        UniV3SwapData memory _swapPathAndFees
    ) external virtual;

    /**
     * Encode path / fees to bytes in the format expected by UniV3 router
     *
     * @param _path          List of token address to swap via (starting with input token)
     * @param _fees          List of fee levels identifying the pools to swap via.
     *                       (_fees[0] refers to pool between _path[0] and _path[1])
     *
     * @return encodedPath   Encoded path to be forwared to uniV3 router
     */
    function _encodePathV3(
        address[] memory _path,
        uint24[] memory _fees
    ) private pure returns (bytes memory encodedPath) {
        encodedPath = abi.encodePacked(_path[0]);
        for (uint256 i = 0; i < _fees.length; i++) {
            encodedPath = abi.encodePacked(encodedPath, _fees[i], _path[i + 1]);
        }
    }

    // Child contract may provide the possible set of Uni-V3 fee values (in basis points)
    // Here we provide a default set of 4 possible fee values
    function _isValidFee(uint24 _fee) internal virtual returns (bool) {
        return _fee == 100 || _fee == 500 || _fee == 3_000 || _fee == 10_000;
    }
}
