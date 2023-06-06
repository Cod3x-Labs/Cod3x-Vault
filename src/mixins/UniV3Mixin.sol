// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../interfaces/ISwapErrors.sol";
import "../interfaces/ISwapRouter.sol";
import "../interfaces/IQuoter.sol";
import "../libraries/TransferHelper.sol";

abstract contract UniV3Mixin is ISwapErrors {
    /// @dev tokenA => (tokenB => path): returns best path to swap
    ///         tokenA to tokenB
    mapping(address => mapping(address => address[])) public uniV3SwapPaths;

    function _swapUniV3(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _minAmountOut,
        address _router,
        address _quoter
    ) internal returns (uint256 amountOut) {
        address[] storage paths = uniV3SwapPaths[_from][_to];
        require(paths.length >= 2, "Missing path for swap");
        require(_amount != 0, "Invalid swap input");

        uint256 amountIn = _amount;
        uint24[] memory fees = new uint24[](paths.length - 1);

        for (uint256 i = 0; i < paths.length - 1; i++) {
            (uint24 optimalFee, uint256 highestAmountOut) = _getOptimalFee(amountIn, paths[i], paths[i + 1], _quoter);
            if (highestAmountOut == 0) {
                emit GetAmountsOutFailed(_router, amountIn, paths[i], paths[i + 1]);
                return 0;
            }
            amountIn = highestAmountOut;
            fees[i] = optimalFee;
        }

        bytes memory path = _encodePathV3(paths, fees);
        TransferHelper.safeApprove(paths[0], _router, _amount);
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amount,
            amountOutMinimum: _minAmountOut
        });

        try ISwapRouter(_router).exactInput(params) returns (uint256 tmpAmountOut) {
            amountOut = tmpAmountOut;
        } catch {
            emit SwapFailed(_router, _amount, _minAmountOut, _from, _to);
        }
    }

    function _getOptimalFee(uint256 amountIn, address from, address to, address _quoter)
        internal
        returns (uint24 optimalFee, uint256 highestAmountOut)
    {
        uint24[] memory feeCandidates = _getFeeCandidates();
        for (uint256 j = 0; j < feeCandidates.length; j++) {
            try IQuoter(_quoter).quoteExactInputSingle(from, to, feeCandidates[j], amountIn, 0) returns (
                uint256 tmpAmountOut
            ) {
                if (tmpAmountOut > highestAmountOut) {
                    highestAmountOut = tmpAmountOut;
                    optimalFee = feeCandidates[j];
                }
            } catch {}
        }
    }

    /// @dev Update {SwapPath} for a specified pair of tokens.
    function _updateUniV3SwapPath(address _tokenIn, address _tokenOut, address[] calldata _path) internal {
        require(
            _tokenIn != _tokenOut && _path.length >= 2 && _path[0] == _tokenIn && _path[_path.length - 1] == _tokenOut
        );
        uniV3SwapPaths[_tokenIn][_tokenOut] = _path;
    }

    // Be sure to permission this in implementation
    function updateUniV3SwapPath(address _tokenIn, address _tokenOut, address[] calldata _path) external virtual;

    // Child contract may provide the possible set of Uni-V3 fee values (in basis points)
    // Here we provide a default set of 4 possible fee values
    function _getFeeCandidates() internal virtual returns (uint24[] memory) {
        uint24[] memory feeCandidates = new uint24[](4);
        feeCandidates[0] = 100;
        feeCandidates[1] = 500;
        feeCandidates[2] = 3_000;
        feeCandidates[3] = 10_000;
        return feeCandidates;
    }

    /**
     * Encode path / fees to bytes in the format expected by UniV3 router
     *
     * @param _path          List of token address to swap via (starting with input token)
     * @param _fees          List of fee levels identifying the pools to swap via.
     *                       (_fees[0] refers to pool between _path[0] and _path[1])
     *
     * @return encodedPath   Encoded path to be forwared to uniV3 router
     */
    function _encodePathV3(address[] memory _path, uint24[] memory _fees)
        private
        pure
        returns (bytes memory encodedPath)
    {
        encodedPath = abi.encodePacked(_path[0]);
        for (uint256 i = 0; i < _fees.length; i++) {
            encodedPath = abi.encodePacked(encodedPath, _fees[i], _path[i + 1]);
        }
    }
}
