// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {ReaperFeeController} from "../../src/ReaperFeeController.sol";
import {ReaperFeeControllerV2} from "./ReaperFeeControllerV2.sol";
import {KEEPER, STRATEGIST, GUARDIAN, ADMIN} from "../../src/Roles.sol";
import {ERC1967Proxy} from "oz/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

contract ReaperFeeControllerTest is Test {
    ReaperFeeController private sut;
    address private deployer = makeAddr("deployer");
    address[] private strategists;
    address[] private multiSig;
    address[] private keepers;

    event ManagementFeeBPSUpdated(uint16 feeBPS);

    function setUp() public {
        vm.startPrank(deployer);
        _deployWithProxy();

        strategists.push(makeAddr("strategist1"));
        strategists.push(makeAddr("strategist2"));

        multiSig.push(makeAddr("multiSig1"));
        multiSig.push(makeAddr("multiSig2"));
        multiSig.push(makeAddr("multiSig3"));

        keepers.push(makeAddr("keeper1"));
        keepers.push(makeAddr("keeper2"));
        keepers.push(makeAddr("keeper3"));

        sut.initialize(strategists, multiSig, keepers);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function testGivenInvalidNumberOfMultisigWhenInitializeThenReverts() public {
        _deployWithProxy();
        multiSig = new address[](0);

        vm.expectRevert("Invalid number of multisig roles");
        sut.initialize(strategists, multiSig, keepers);
    }

    function testGivenRolesWhenInitializeThenAccessRolesAreSetCorrectly() public view {
        bytes32 defaultAdminRole = sut.DEFAULT_ADMIN_ROLE();
        assertEq(sut.getRoleMemberCount(defaultAdminRole), 2);
        assertEq(sut.getRoleMemberCount(STRATEGIST), strategists.length);
        assertEq(sut.getRoleMemberCount(KEEPER), keepers.length);

        for (uint8 i = 0; i < strategists.length; i++) {
            assertTrue(sut.hasRole(STRATEGIST, strategists[i]));
        }

        for (uint8 i = 0; i < keepers.length; i++) {
            assertTrue(sut.hasRole(KEEPER, keepers[i]));
        }

        assertTrue(sut.hasRole(defaultAdminRole, deployer));
        assertTrue(sut.hasRole(defaultAdminRole, multiSig[0]));
        assertTrue(sut.hasRole(ADMIN, multiSig[1]));
        assertTrue(sut.hasRole(GUARDIAN, multiSig[2]));

        assertEq(sut.getRoleAdmin(GUARDIAN), defaultAdminRole);
        assertEq(sut.getRoleAdmin(ADMIN), defaultAdminRole);
        assertEq(sut.getRoleAdmin(STRATEGIST), defaultAdminRole);
        assertEq(sut.getRoleAdmin(KEEPER), defaultAdminRole);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   UPGRADEABILITY TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function testGivenNonAuthorizedRoleWhenUpgradeThenRevertsWithError() public {
        ReaperFeeControllerV2 sutV2 = new ReaperFeeControllerV2();
        address[] memory unauthorizedUsers = new address[](5);
        unauthorizedUsers[0] = makeAddr("UNAUTHORIZED_USER");
        unauthorizedUsers[1] = strategists[0];
        unauthorizedUsers[2] = keepers[0];
        unauthorizedUsers[3] = multiSig[1];
        unauthorizedUsers[4] = multiSig[2];

        for (uint8 i = 0; i < unauthorizedUsers.length; i++) {
            vm.expectRevert("Unauthorized access");

            vm.startPrank(unauthorizedUsers[i]);
            sut.upgradeTo(address(sutV2));
        }
    }

    function testGivenRightPreconditionsWhenUpgradeThenUpgrades() public {
        ReaperFeeControllerV2 sutV2 = new ReaperFeeControllerV2();
        address[] memory authorizedUsers = new address[](2);
        authorizedUsers[0] = deployer;
        authorizedUsers[1] = multiSig[0];

        for (uint8 i = 0; i < authorizedUsers.length; i++) {
            vm.startPrank(authorizedUsers[i]);
            sut.unlockUpgrade(address(sutV2));

            skip(sut.upgradeUnlocksAt() + 10);

            sut.upgradeTo(address(sutV2));

            string memory version = sutV2.version();
            assertEq("v2", version);
        }
    }

    function testGivenNonAuthorizedRoleWhenUnlockUpgradeThenRevertsWithError() public {
        address[] memory unauthorizedUsers = new address[](2);
        unauthorizedUsers[0] = makeAddr("UNAUTHORIZED_USER");
        unauthorizedUsers[1] = keepers[0];

        for (uint8 i = 0; i < unauthorizedUsers.length; i++) {
            vm.expectRevert("Unauthorized access");

            vm.startPrank(unauthorizedUsers[i]);
            sut.unlockUpgrade(makeAddr("NEW_IMPLEMENTATION"));
        }
    }

    function testGivenAuthorizedRoleWhenUnlockUpgradeThenDoesNotRevert() public {
        address[] memory authorizedUsers = new address[](5);
        authorizedUsers[0] = deployer;
        authorizedUsers[1] = multiSig[0];
        authorizedUsers[2] = multiSig[1];
        authorizedUsers[3] = multiSig[2];
        authorizedUsers[4] = strategists[0];

        for (uint8 i = 0; i < authorizedUsers.length; i++) {
            vm.startPrank(authorizedUsers[i]);
            sut.unlockUpgrade(makeAddr("NEW_IMPLEMENTATION"));
        }
    }

    function testGivenNonAuthorizedRoleWhenLockUpgradeThenRevertsWithError() public {
        address[] memory unauthorizedUsers = new address[](3);
        unauthorizedUsers[0] = makeAddr("UNAUTHORIZED_USER");
        unauthorizedUsers[1] = keepers[0];
        unauthorizedUsers[2] = strategists[0];

        for (uint8 i = 0; i < unauthorizedUsers.length; i++) {
            vm.expectRevert("Unauthorized access");

            vm.startPrank(unauthorizedUsers[i]);
            sut.lockUpgrade();
        }
    }

    function testGivenAuthorizedRoleWhenLockUpgradeThenDoesNotRevert() public {
        address[] memory authorizedUsers = new address[](4);
        authorizedUsers[0] = deployer;
        authorizedUsers[1] = multiSig[0];
        authorizedUsers[2] = multiSig[1];
        authorizedUsers[3] = multiSig[2];

        for (uint256 i = 0; i < authorizedUsers.length; i++) {
            vm.startPrank(authorizedUsers[i]);
            sut.lockUpgrade();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   MANAGEMENT FEE TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function testGivenInitializationWhenFetchManagmentFeeThenDefaultsToZero() public view {
        uint16 managementFeeBPS = sut.fetchManagementFeeBPS();

        assertEq(managementFeeBPS, 0);
        assertEq(sut.managementFeeBPS(), 0);
    }

    function testGivenUpdatedManagementFeeWhenFetchManagmentFeeThenFetchesTheValue() public {
        address[] memory authorizedUsers = new address[](6);
        authorizedUsers[0] = deployer;
        authorizedUsers[1] = multiSig[0];
        authorizedUsers[2] = multiSig[1];
        authorizedUsers[3] = multiSig[2];
        authorizedUsers[4] = strategists[0];
        authorizedUsers[5] = keepers[0];

        for (uint8 i = 0; i < authorizedUsers.length; i++) {
            uint16 updatedManagemenetFeeBPS = 500 + uint16(i);
            vm.startPrank(authorizedUsers[i]);
            sut.updateManagementFeeBPS(updatedManagemenetFeeBPS);

            assertEq(sut.fetchManagementFeeBPS(), updatedManagemenetFeeBPS);
        }
    }

    function testGivenUnauthorizedRoleWhenUpdateManagementFeeThenReverts() public {
        address unauthorizedRole = makeAddr("UNAUTHORIZED_USER");

        vm.expectRevert("Unauthorized access");

        vm.startPrank(unauthorizedRole);
        sut.updateManagementFeeBPS(500);
    }

    function testGivenInvalidManagementFeeWhenUpdateManagementFeeThenReverts(uint256 invalidManagementFee) public {
        invalidManagementFee = bound(invalidManagementFee, sut.PERCENT_DIVISOR(), type(uint16).max);

        vm.startPrank(keepers[0]);
        sut.updateManagementFeeBPS(500);
    }

    function testGivenCorrectValueWhenUpdateManagementFeeThenEventEmitted() public {
        uint16 updatedManagementFee = 500;

        vm.expectEmit();
        emit ReaperFeeControllerTest.ManagementFeeBPSUpdated(updatedManagementFee);

        vm.startPrank(keepers[0]);
        sut.updateManagementFeeBPS(updatedManagementFee);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _deployWithProxy() private {
        sut = new ReaperFeeController();
        ERC1967Proxy proxy = new ERC1967Proxy(address(sut), "");
        sut = ReaperFeeController(address(proxy));
    }
}
