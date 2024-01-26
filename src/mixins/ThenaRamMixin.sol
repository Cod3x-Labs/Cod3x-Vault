// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "oz/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IThenaRamRouter.sol";
import "../interfaces/IThenaRamPair.sol";
import "../interfaces/ISwapErrors.sol";
import "../interfaces/IThenaRamFactory.sol";
import "../libraries/Babylonian.sol";

abstract contract ThenaRamMixin is ISwapErrors {
    using SafeERC20 for IERC20;

    event ThenaRamSwapPathUpdated(
        address indexed from,
        address indexed to,
        address indexed router,
        IThenaRamRouter.route[] path
    );

    /// @dev tokenA => (tokenB => (router => path): returns best path to swap
    ///         tokenA to tokenB for the given router (protocol)
    mapping(address => mapping(address => mapping(address => IThenaRamRouter.route[])))
        public thenaRamSwapPaths;

    /// @dev Helper function to swap {_from} to {_to} given an {_amount}.
    function _swapThenaRam(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _minAmountOut,
        address _router,
        uint256 _deadline
    ) internal returns (uint256 amountOut) {
        if (_from == _to || _amount == 0) {
            return 0;
        }
        IThenaRamRouter.route[] storage path = thenaRamSwapPaths[_from][_to][
            _router
        ];
        require(path.length != 0, "Missing path for swap");

        uint256 predictedOutput;
        IThenaRamRouter router = IThenaRamRouter(_router);
        try router.getAmountsOut(_amount, path) returns (
            uint256[] memory amounts
        ) {
            predictedOutput = amounts[amounts.length - 1];
        } catch {}
        if (predictedOutput == 0) {
            emit GetAmountsOutFailed(_router, _amount, _from, _to);
            return 0;
        }

        uint256 toBalBefore = IERC20(_to).balanceOf(address(this));
        IERC20(_from).safeIncreaseAllowance(_router, _amount);
        try
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amount,
                _minAmountOut,
                path,
                address(this),
                _deadline
            )
        {
            amountOut = IERC20(_to).balanceOf(address(this)) - toBalBefore;
        } catch {
            IERC20(_from).safeApprove(_router, 0);
            emit SwapFailed(_router, _amount, _minAmountOut, _from, _to);
        }
    }

    function _getSwapAmountThenaRam(
        IVeloPair pair,
        uint256 investmentA,
        uint256 reserveA,
        uint256 reserveB,
        address tokenA
    ) internal view returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;
        uint256 numerator = pair.getAmountOut(halfInvestment, tokenA);
        uint256 denominator = _quoteLiquidity(
            halfInvestment,
            reserveA + halfInvestment,
            reserveB - numerator
        );
        swapAmount =
            investmentA -
            Babylonian.sqrt(
                (halfInvestment * halfInvestment * numerator) / denominator
            );
    }

    // Copied from Thena/Ramses's Router since it's an internal function in there
    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function _quoteLiquidity(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "Router: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "Router: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    /// @dev Update {SwapPath} for a specified pair of tokens.
    function _updateThenaRamSwapPath(
        address _tokenIn,
        address _tokenOut,
        address _router,
        IThenaRamRouter.route[] memory _path
    ) internal {
        require(
            _tokenIn != _tokenOut &&
                _path.length != 0 &&
                _path[0].from == _tokenIn &&
                _path[_path.length - 1].to == _tokenOut
        );
        delete thenaRamSwapPaths[_tokenIn][_tokenOut][_router];
        for (uint256 i = 0; i < _path.length; i++) {
            if (i < _path.length - 1) {
                require(_path[i].to == _path[i + 1].from);
                IThenaRamFactory factory = IThenaRamFactory(
                    IThenaRamRouter(_router).factory()
                );
                address pair = factory.getPair(
                    _path[i].from,
                    _path[i].to,
                    _path[i].stable
                );
                bool isPair = factory.isPair(pair);
                require(isPair);
            }
            thenaRamSwapPaths[_tokenIn][_tokenOut][_router].push(_path[i]);
        }
        emit ThenaRamSwapPathUpdated(_tokenIn, _tokenOut, _router, _path);
    }

    // Be sure to permission this in implementation
    function updateThenaRamSwapPath(
        address _tokenIn,
        address _tokenOut,
        address _router,
        IThenaRamRouter.route[] memory _path
    ) external virtual;
}
