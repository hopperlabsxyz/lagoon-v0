// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";

import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TestRoles is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
    }

    function test_whitelistManager() public view {
        assertEq(vault.whitelistManager(), whitelistManager.addr);
    }

    function test_feeReceiver() public view {
        assertEq(vault.feeReceiver(), feeReceiver.addr);
    }

    function test_protocolFeeReceiver() public view {
        assertEq(vault.protocolFeeReceiver(), dao.addr);
    }

    function test_safe() public view {
        assertEq(vault.safe(), safe.addr);
    }

    function test_valuationManager() public view {
        assertEq(vault.valuationManager(), valuationManager.addr);
    }

    function test_feeRegistry() public view {
        assertEq(vault.feeRegistry(), address(feeRegistry));
    }

    function test_updateWhitelistManager() public {
        vm.prank(vault.owner());
        vault.updateWhitelistManager(address(0x42));

        assertEq(vault.whitelistManager(), address(0x42));
    }

    function test_updateFeeReceiver() public {
        vm.prank(vault.owner());
        vault.updateFeeReceiver(address(0x42));

        assertEq(vault.feeReceiver(), address(0x42));
    }

    function test_updateNewTotalAssetsManager() public {
        vm.prank(vault.owner());
        vault.updateValuationManager(address(0x42));

        assertEq(vault.valuationManager(), address(0x42));
    }

    function test_updateNewTotalAssetsManager_notOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.updateValuationManager(address(0x42));
    }

    function test_updateSafe() public {
        address oldSafe = vault.safe();
        address newSafe = address(0x42);

        vm.prank(vault.owner());
        vault.updateSafe(newSafe);

        assertEq(vault.safe(), newSafe);
        assertNotEq(vault.safe(), oldSafe);
    }

    function test_updateSafe_notOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.updateSafe(address(0x42));
    }

    function test_updateSafe_emitsEvent() public {
        address oldSafe = vault.safe();
        address newSafe = address(0x42);

        vm.expectEmit(true, true, true, true);
        emit SafeUpdated(oldSafe, newSafe);

        vm.prank(vault.owner());
        vault.updateSafe(newSafe);
    }
}
