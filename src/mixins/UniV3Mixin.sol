// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../interfaces/ISwapErrors.sol";
import "../interfaces/ISwapRouter.sol";
import "../interfaces/IQuoter.sol";
import "../libraries/TransferHelper.sol";

abstract contract UniV3Mixin is ISwapErrors {
    event UniV3SwapPathUpdated(address indexed from, address indexed to, address indexed router, address[] path);
    event UniV3SwapFeesUpdated(address indexed from, address indexed to, address indexed router, uint24[] fees);

    /// @dev tokenA => (tokenB => (router => path)): returns best path to swap
    ///         tokenA to tokenB for the given router (protocol)
    mapping(address => mapping(address => mapping(address => address[]))) public uniV3SwapPaths;
    /// @dev tokenA => (tokenB => (router => fees)): returns best fee tiers to swap
    ///         tokenA to tokenB for the given router (protocol)
    mapping(address => mapping(address => mapping(address => uint24[]))) public uniV3SwapFees;

    function _swapUniV3(address _from, address _to, uint256 _amount, uint256 _minAmountOut, address _router)
        internal
        returns (uint256 amountOut)
    {
        if (_from == _to || _amount == 0) {
            return 0;
        }

        address[] storage path = uniV3SwapPaths[_from][_to][_router];
        uint24[] storage fees = uniV3SwapFees[_from][_to][_router];
        require(path.length >= 2 && fees.length == path.length - 1, "Missing data for swap");

        bytes memory pathBytes = _encodePathV3(path, fees);
        TransferHelper.safeApprove(path[0], _router, _amount);
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: pathBytes,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amount,
            amountOutMinimum: _minAmountOut
        });

        try ISwapRouter(_router).exactInput(params) returns (uint256 tmpAmountOut) {
            amountOut = tmpAmountOut;
        } catch {
            TransferHelper.safeApprove(path[0], _router, 0);
            emit SwapFailed(_router, _amount, _minAmountOut, _from, _to);
        }
    }

    /// @dev Update {SwapPath} for a specified pair of tokens and router.
    function _updateUniV3SwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        internal
    {
        require(
            _tokenIn != _tokenOut && _path.length >= 2 && _path[0] == _tokenIn && _path[_path.length - 1] == _tokenOut
        );
        uniV3SwapPaths[_tokenIn][_tokenOut][_router] = _path;
        emit UniV3SwapPathUpdated(_tokenIn, _tokenOut, _router, _path);
    }

    // Be sure to permission this in implementation
    function updateUniV3SwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        external
        virtual;

    /// @dev Update the fee tiers used for a specified pair of tokens and router.
    function _updateUniV3SwapFees(address _tokenIn, address _tokenOut, address _router, uint24[] calldata _fees)
        internal
    {
        require(
            _tokenIn != _tokenOut && _fees.length >= 1
        );
        uniV3SwapFees[_tokenIn][_tokenOut][_router] = _fees;
        emit UniV3SwapFeesUpdated(_tokenIn, _tokenOut, _router, _fees);
    }

    // Be sure to permission this in implementation
    function updateUniV3SwapFees(address _tokenIn, address _tokenOut, address _router, uint24[] calldata _fees)
        external
        virtual;

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
