// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {ReaperMathUtils} from "./libraries/ReaperMathUtils.sol";
import {IFeeController} from "./interfaces/IFeeController.sol";
import {ReaperAccessControl} from "./mixins/ReaperAccessControl.sol";
import {CooldownUUPSUpgradeable} from "./mixins/upgrade/CooldownUUPSUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "oz-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {KEEPER, STRATEGIST, GUARDIAN, ADMIN} from "./Roles.sol";

contract ReaperFeeController is
    IFeeController,
    CooldownUUPSUpgradeable,
    ReaperAccessControl,
    AccessControlEnumerableUpgradeable
{
    using ReaperMathUtils for uint256;

    uint16 public constant PERCENT_DIVISOR = 10_000;
    uint16 public managementFeeBPS;

    event ManagementFeeBPSUpdated(uint16 feeBPS);

    function initialize(address[] memory _strategists, address[] memory _multisigRoles, address[] memory _keepers)
        public
        initializer
    {
        __AccessControlEnumerable_init();
        __CooldownUUPSUpgradeable_init();

        require(_multisigRoles.length == 3, "Invalid number of multisig roles");
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DEFAULT_ADMIN_ROLE, _multisigRoles[0]);
        _grantRole(ADMIN, _multisigRoles[1]);
        _grantRole(GUARDIAN, _multisigRoles[2]);

        for (uint256 i = 0; i < _strategists.length; i = i.uncheckedInc()) {
            _grantRole(STRATEGIST, _strategists[i]);
        }

        for (uint256 i = 0; i < _keepers.length; i = i.uncheckedInc()) {
            _grantRole(KEEPER, _keepers[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MANAGEMENT FEE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function fetchManagementFeeBPS() external view returns (uint16) {
        return managementFeeBPS;
    }

    function updateManagementFeeBPS(uint16 _feeBPS) external {
        _atLeastRole(KEEPER);
        _validateManagementFeeValue(_feeBPS);
        managementFeeBPS = _feeBPS;
        emit ManagementFeeBPSUpdated(_feeBPS);
    }

    function _validateManagementFeeValue(uint16 _feeBPS) internal pure {
        require(_feeBPS <= PERCENT_DIVISOR, "Management fee cannot be higher than 10_000 BPS(100%)");
    }

    /*//////////////////////////////////////////////////////////////////////////
                               ACCESS CONTROL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    /**
     * @dev Returns an array of all the relevant roles arranged in descending order of privilege.
     *      Subclasses should override this to specify their unique roles arranged in the correct
     *      order, for example, [SUPER-ADMIN, ADMIN, GUARDIAN, STRATEGIST].
     */
    function _cascadingAccessRoles() internal pure override returns (bytes32[] memory) {
        bytes32[] memory cascadingAccessRoles = new bytes32[](5);
        cascadingAccessRoles[0] = DEFAULT_ADMIN_ROLE;
        cascadingAccessRoles[1] = ADMIN;
        cascadingAccessRoles[2] = GUARDIAN;
        cascadingAccessRoles[3] = STRATEGIST;
        cascadingAccessRoles[4] = KEEPER;
        return cascadingAccessRoles;
    }

    /**
     * @dev Returns {true} if {_account} has been granted {_role}. Subclasses should override
     *      this to specify their unique role-checking criteria.
     */
    function _hasRole(bytes32 _role, address _account) internal view override returns (bool) {
        return hasRole(_role, _account);
    }

    /*//////////////////////////////////////////////////////////////////////////
                               UPGRADEABLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    /**
     * @dev Function sets the access control for contract upgrade functionality
     */
    function _authorizeUpgrade() internal view override {
        _atLeastRole(DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Function unlocks the contract upgrade
     */
    function unlockUpgrade(address _newImplementation) external {
        _atLeastRole(STRATEGIST);
        _unlockUpgrade(_newImplementation);
    }

    /**
     * @dev Function locks the contract upgrade
     */
    function lockUpgrade() external {
        _atLeastRole(GUARDIAN);
        _lockUpgrade();
    }
}
