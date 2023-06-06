// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "oz/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../libraries/Babylonian.sol";

abstract contract UniV2Mixin {
    using SafeERC20 for IERC20;

    /// @dev tokenA => (tokenB => path): returns best path to swap
    ///         tokenA to tokenB
    mapping(address => mapping(address => address[])) public uniV2SwapPaths;

    /// @dev Helper function to swap {_from} to {_to} given an {_amount}.
    function _swapUniV2(address _from, address _to, uint256 _amount, uint256 _minAmountOut, address _router) internal {
        if (_from == _to || _amount == 0) {
            return;
        }
        address[] storage path = uniV2SwapPaths[_from][_to];
        require(path.length >= 2, "Missing path for swap");

        IUniswapV2Router02 router = IUniswapV2Router02(_router);
        try router.getAmountsOut(_amount, path) returns (uint256[] memory amounts) {
            // return if final output is 0 (don't fail harvest)
            if (amounts[path.length - 1] == 0) return;
        } catch {
            // return if intermediate output is 0 (don't fail harvest)
            return;
        }

        IERC20(_from).safeIncreaseAllowance(_router, _amount);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount, _minAmountOut, path, address(this), block.timestamp
        );
    }

    /**
     * @dev Core harvest function. Adds more liquidity using {lpToken0} and {lpToken1}.
     */
    function _addLiquidityUniV2(address _lpToken0, address _lpToken1, address _router) internal {
        uint256 lp0Bal = IERC20(_lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(_lpToken1).balanceOf(address(this));

        if (lp0Bal != 0 && lp1Bal != 0) {
            IERC20(_lpToken0).safeIncreaseAllowance(_router, lp0Bal);
            IERC20(_lpToken1).safeIncreaseAllowance(_router, lp1Bal);
            IUniswapV2Router02(_router).addLiquidity(
                _lpToken0, _lpToken1, lp0Bal, lp1Bal, 0, 0, address(this), block.timestamp
            );
        }
    }

    function _getSwapAmountUniV2(uint256 _investmentA, uint256 _reserveA, uint256 _reserveB, address _router)
        internal
        pure
        returns (uint256 swapAmount)
    {
        uint256 halfInvestment = _investmentA / 2;
        uint256 nominator = IUniswapV2Router02(_router).getAmountOut(halfInvestment, _reserveA, _reserveB);
        uint256 denominator =
            IUniswapV2Router02(_router).quote(halfInvestment, _reserveA + halfInvestment, _reserveB - nominator);
        swapAmount = _investmentA - (Babylonian.sqrt(halfInvestment * halfInvestment * nominator / denominator));
    }

    /// @dev Update {SwapPath} for a specified pair of tokens.
    function _updateUniV2SwapPath(address _tokenIn, address _tokenOut, address[] calldata _path) internal {
        require(
            _tokenIn != _tokenOut && _path.length >= 2 && _path[0] == _tokenIn && _path[_path.length - 1] == _tokenOut
        );
        uniV2SwapPaths[_tokenIn][_tokenOut] = _path;
    }

    // Be sure to permission this in implementation
    function updateUniV2SwapPath(address _tokenIn, address _tokenOut, address[] calldata _path) external virtual;
}
