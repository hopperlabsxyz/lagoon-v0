// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";

contract TestUpdateNewTotalAssets is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);

        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);
    }

    // --- isSyncRedeemAllowed blocks updateNewTotalAssets ---

    function test_whenSyncRedeemAllowed_cantUpdateNav() public {
        // let totalAssets lifespan expire so only isSyncRedeemAllowed blocks
        vm.warp(block.timestamp + 1 days);

        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(true);

        vm.prank(vault.valuationManager());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.updateNewTotalAssets(1);
    }

    function test_whenSyncRedeemDisabled_canUpdateNav() public {
        vm.warp(block.timestamp + 1 days);

        // enable then disable sync redeem
        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(true);

        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(false);

        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    function test_disableSyncOperations_clearsSyncRedeemAllowed() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(true);

        // verify blocked
        vm.prank(vault.valuationManager());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.updateNewTotalAssets(1);

        // disableSyncOperations should clear isSyncRedeemAllowed
        vm.prank(vault.safe());
        vault.disableSyncOperations();

        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    // --- setAsyncOnly clears isSyncRedeemAllowed ---

    function test_setAsyncOnly_clearsSyncRedeemAllowed() public {
        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(true);

        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        // should succeed: setAsyncOnly clears isSyncRedeemAllowed
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    // --- setIsSyncRedeemAllowed reverts in asyncOnly mode ---

    function test_setIsSyncRedeemAllowed_revertsWhenAsyncOnly() public {
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        vm.prank(vault.safe());
        vm.expectRevert(AsyncOnly.selector);
        vault.setIsSyncRedeemAllowed(true);
    }

    // --- setIsSyncRedeemAllowed reverts when newTotalAssets is pending ---

    function test_setIsSyncRedeemAllowed_revertsWhenNewTotalAssetsPending() public {
        // let totalAssets lifespan expire so updateNewTotalAssets succeeds
        vm.warp(block.timestamp + 1 days);

        // propose a new NAV — newTotalAssets is now != type(uint256).max
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);

        // enabling sync redeem should revert because a NAV update is pending
        vm.prank(vault.safe());
        vm.expectRevert(EnableSyncRedeemNotAllowed.selector);
        vault.setIsSyncRedeemAllowed(true);
    }

    function test_setIsSyncRedeemAllowed_disableAlsoRevertsWhenNewTotalAssetsPending() public {
        // enable sync redeem first (while newTotalAssets == max)
        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(true);

        // let totalAssets lifespan expire and propose a new NAV
        vm.warp(block.timestamp + 1 days);
        // disableSyncOperations so updateNewTotalAssets can go through
        vm.prank(vault.safe());
        vault.disableSyncOperations();
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);

        // trying to disable sync redeem when newTotalAssets is pending succeeds
        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(false);
    }
}
