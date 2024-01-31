// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "oz/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAsset.sol";
import "../interfaces/IBasePool.sol";
import "../interfaces/IBaseWeightedPool.sol";
import "../interfaces/IBeetVault.sol";
import "../interfaces/ISwapErrors.sol";

abstract contract BalMixin is ISwapErrors {
    using SafeERC20 for IERC20;

    event BalSwapPoolIDUpdated(address indexed from, address indexed to, address indexed vault, bytes32 poolID);

    /// @dev tokenA => (tokenB => (vault => poolID)): returns best poolID to swap
    ///      tokenA to tokenB for the given vault (protocol)
    mapping(address => mapping(address => mapping(address => bytes32))) public balSwapPoolIDs;

    /**
     * @dev Swaps {_amount} of {_from} to {_to} using {_vault}.
     * Prior to requesting the swap, allowance is increased if necessary.
     */
    function _swapBal(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _minAmountOut,
        address _vault,
        uint256 _deadline,
        bool _tryCatchActive
    ) internal returns (uint256 amountOut) {
        if (_from == _to || _amount == 0) {
            return 0;
        }

        bytes32 poolId = balSwapPoolIDs[_from][_to][_vault];
        require(poolId != bytes32(0), "Missing pool for swap");

        IBeetVault.SingleSwap memory singleSwap;
        singleSwap.poolId = poolId;
        singleSwap.kind = IBeetVault.SwapKind.GIVEN_IN;
        singleSwap.assetIn = IAsset(_from);
        singleSwap.assetOut = IAsset(_to);
        singleSwap.amount = _amount;
        singleSwap.userData = abi.encode(0);

        IBeetVault.FundManagement memory funds;
        funds.sender = address(this);
        funds.fromInternalBalance = false;
        funds.recipient = payable(address(this));
        funds.toInternalBalance = false;

        uint256 currentAllowance = IERC20(_from).allowance(address(this), _vault);

        // Linear pool tokens have infinite allowance for the vault by default.
        if (_amount > currentAllowance) {
            IERC20(_from).safeIncreaseAllowance(_vault, _amount - currentAllowance);
        }

        // Based on configurable param catch fails or just revert
        if (_tryCatchActive != false) {
            try IBeetVault(_vault).swap(singleSwap, funds, _minAmountOut, _deadline) returns (uint256 tmpAmountOut) {
                amountOut = tmpAmountOut;
            } catch {
                // Reset allowance iff we had to increase it.
                if (_amount > currentAllowance) {
                    IERC20(_from).safeApprove(_vault, 0);
                }
                emit SwapFailed(_vault, _amount, _minAmountOut, _from, _to);
            }
        } else {
            amountOut = IBeetVault(_vault).swap(singleSwap, funds, _minAmountOut, _deadline);
        }
    }

    /// @dev Update {SwapPoolId} for a specified pair of tokens and specified vault.
    function _updateBalSwapPoolID(address _tokenIn, address _tokenOut, address _vault, bytes32 _poolID) internal {
        require(_tokenIn != address(0) && _tokenIn != _tokenOut, "Tokens must be different and not zero");
        IERC20[] memory poolTokens;
        (poolTokens,,) = IBeetVault(_vault).getPoolTokens(_poolID);
        bool tokenInFound;
        bool tokenOutFound;

        for (uint256 i = 0; i < poolTokens.length; i++) {
            if (address(poolTokens[i]) == _tokenIn) tokenInFound = true;
            else if (address(poolTokens[i]) == _tokenOut) tokenOutFound = true;
        }
        require(tokenInFound && tokenOutFound, "Tokens not found in pool");

        balSwapPoolIDs[_tokenIn][_tokenOut][_vault] = _poolID;
        emit BalSwapPoolIDUpdated(_tokenIn, _tokenOut, _vault, _poolID);
    }

    // Be sure to permission this in implementation
    function updateBalSwapPoolID(address _tokenIn, address _tokenOut, address _vault, bytes32 _poolID)
        external
        virtual;
}
