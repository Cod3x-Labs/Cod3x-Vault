// SPDX-License-Identifier: BUSL1.1

pragma solidity ^0.8.0;

import "./mixins/UniV2Mixin.sol";
import "./mixins/BalMixin.sol";
import "./mixins/VeloSolidMixin.sol";
import "./mixins/UniV3Mixin.sol";
import "./mixins/ReaperAccessControl.sol";
import "./libraries/ReaperMathUtils.sol";
import "oz/token/ERC20/utils/SafeERC20.sol";
import "oz/access/AccessControlEnumerable.sol";

contract ReaperSwapper is
    UniV2Mixin,
    BalMixin,
    VeloSolidMixin,
    UniV3Mixin,
    AccessControlEnumerable,
    ReaperAccessControl
{
    using ReaperMathUtils for uint256;
    using SafeERC20 for IERC20;

    /**
     * Reaper Roles in increasing order of privilege.
     * {STRATEGIST} - Role conferred to authors of strategies, allows for setting swap paths.
     * {GUARDIAN} - Multisig requiring 2 signatures for setting quoters and CL aggregator addresses.
     *
     * Note that roles are cascading. So any higher privileged role should be able to perform all the functions
     * of any lower privileged role.
     */
    bytes32 public constant STRATEGIST = keccak256("STRATEGIST");
    bytes32 public constant GUARDIAN = keccak256("GUARDIAN");

    constructor(address[] memory _strategists, address _guardian) {
        uint256 numStrategists = _strategists.length;
        for (uint256 i = 0; i < numStrategists; i = i.uncheckedInc()) {
            _grantRole(STRATEGIST, _strategists[i]);
        }
        _grantRole(GUARDIAN, _guardian);
    }

    function updateUniV2SwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        external
        override
    {
        _atLeastRole(STRATEGIST);
        _updateVeloSwapPath(_tokenIn, _tokenOut, _router, _path);
    }

    function updateBalSwapPoolID(address _tokenIn, address _tokenOut, address _vault, bytes32 _poolID)
        external
        override
    {
        _atLeastRole(STRATEGIST);
        _updateBalSwapPoolID(_tokenIn, _tokenOut, _vault, _poolID);
    }

    function updateVeloSwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        external
        override
    {
        _atLeastRole(STRATEGIST);
        _updateVeloSwapPath(_tokenIn, _tokenOut, _router, _path);
    }

    function updateUniV3SwapPath(address _tokenIn, address _tokenOut, address _router, address[] calldata _path)
        external
        override
    {
        _atLeastRole(STRATEGIST);
        _updateUniV3SwapPath(_tokenIn, _tokenOut, _router, _path);
    }

    function updateUniV3Quoter(address _router, address _quoter) external override {
        _atLeastRole(GUARDIAN);
        _updateUniV3Quoter(_router, _quoter);
    }

    function swapUniV2(address _from, address _to, uint256 _amount, uint256 _minAmountOut, address _router)
        external
        pullFromBefore(_from, _amount)
        pushFromAndToAfter(_from, _to)
        returns (uint256)
    {
        return _swapUniV2(_from, _to, _amount, _minAmountOut, _router);
    }

    function swapBal(address _from, address _to, uint256 _amount, uint256 _minAmountOut, address _vault)
        external
        pullFromBefore(_from, _amount)
        pushFromAndToAfter(_from, _to)
        returns (uint256)
    {
        return _swapBal(_from, _to, _amount, _minAmountOut, _vault);
    }

    function swapVelo(address _from, address _to, uint256 _amount, uint256 _minAmountOut, address _router)
        external
        pullFromBefore(_from, _amount)
        pushFromAndToAfter(_from, _to)
    {
        _swapVelo(_from, _to, _amount, _minAmountOut, _router);
    }

    function swapUniV3(address _from, address _to, uint256 _amount, uint256 _minAmountOut, address _router)
        external
        pullFromBefore(_from, _amount)
        pushFromAndToAfter(_from, _to)
        returns (uint256)
    {
        return _swapUniV3(_from, _to, _amount, _minAmountOut, _router);
    }

    /**
     * @dev Returns an array of all the relevant roles arranged in descending order of privilege.
     *      Subclasses should override this to specify their unique roles arranged in the correct
     *      order, for example, [SUPER-ADMIN, ADMIN, GUARDIAN, STRATEGIST].
     */
    function _cascadingAccessRoles() internal pure override returns (bytes32[] memory) {
        bytes32[] memory cascadingAccessRoles = new bytes32[](2);
        cascadingAccessRoles[0] = GUARDIAN;
        cascadingAccessRoles[1] = STRATEGIST;
        return cascadingAccessRoles;
    }

    /**
     * @dev Returns {true} if {_account} has been granted {_role}. Subclasses should override
     *      this to specify their unique role-checking criteria.
     */
    function _hasRole(bytes32 _role, address _account) internal view override returns (bool) {
        return hasRole(_role, _account);
    }

    modifier pullFromBefore(address _from, uint256 _amount) {
        IERC20(_from).safeTransferFrom(msg.sender, address(this), _amount);
        _;
    }

    modifier pushFromAndToAfter(address _from, address _to) {
        _;
        uint256 fromBal = IERC20(_from).balanceOf(address(this));
        if (fromBal != 0) {
            IERC20(_from).safeTransfer(msg.sender, fromBal);
        }
        uint256 toBal = IERC20(_to).balanceOf(address(this));
        if (toBal != 0) {
            IERC20(_to).safeTransfer(msg.sender, toBal);
        }
    }
}
