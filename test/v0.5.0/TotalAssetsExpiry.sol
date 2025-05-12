// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

// Tests in this file are related to TotalAssets lifecycle and functions related to it.

contract TestTotalAssetsExpiry is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);

        // for the next 1000 seconds, we will be able to use the sync deposit flow
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);
    }

    function test_onlySafeCanExpireTotalAssets() public {
        // uint256 userBalance = assetBalance(user1.addr);
        // it will be equal since pps is 1:1

        vm.prank(vault.valuationManager());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.updateNewTotalAssets(1);
    }

    function test_whenSyncDepositPossible_cantUpdateNav() public {
        // uint256 userBalance = assetBalance(user1.addr);
        // it will be equal since pps is 1:1

        vm.prank(vault.valuationManager());
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, vault.safe()));
        vault.expireTotalAssets();
    }

    function test_whenTotalAssetsExpireWithTime_canUpdateNav() public {
        vm.prank(vault.valuationManager());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.updateNewTotalAssets(1);

        vm.warp(block.timestamp + 1 days);
        vm.prank(vault.valuationManager());

        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    function test_canUpdateNave_after() public {
        assertNotEq(vault.totalAssetsExpiration(), 0, "ttaExpiration should not be 0");

        vm.prank(vault.valuationManager());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.updateNewTotalAssets(1);

        vm.prank(vault.safe());
        vault.expireTotalAssets();

        assertEq(vault.totalAssetsExpiration(), 0, "ttA is not expired");
    }
}
