// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {SyncMode} from "@src/v0.6.0/primitives/Enums.sol";

contract TestUpdateNewTotalAssets is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);

        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);
    }

    // --- isTotalAssetsValid blocks updateNewTotalAssets ---

    function test_whenTotalAssetsValid_cantUpdateNav() public {
        vm.prank(vault.valuationManager());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.updateNewTotalAssets(1);
    }

    function test_whenTotalAssetsExpired_canUpdateNav() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    function test_expireTotalAssets_allowsUpdateNav() public {
        vm.prank(vault.valuationManager());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.updateNewTotalAssets(1);

        vm.prank(vault.safe());
        vault.expireTotalAssets();

        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    // --- syncMode does NOT block updateNewTotalAssets ---

    function test_syncModeDoesNotBlockUpdateNav() public {
        // let totalAssets expire
        vm.warp(block.timestamp + 1 days);

        // even with syncMode = Both (default), updateNewTotalAssets succeeds
        // because only isTotalAssetsValid gates it
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    // --- setAsyncOnly clears syncMode ---

    function test_setAsyncOnly_clearsSyncMode() public {
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        // should succeed: setAsyncOnly expires totalAssets
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(1);
    }

    // --- setSyncMode reverts in asyncOnly mode ---

    function test_setSyncMode_revertsWhenAsyncOnly() public {
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        vm.prank(vault.safe());
        vm.expectRevert(AsyncOnly.selector);
        vault.setSyncMode(SyncMode.SyncRedeem);
    }

    // --- securityCouncil ---

    function test_securityCouncil_whenTotalAssetsValid_cantUpdateNav() public {
        vm.prank(vault.securityCouncil());
        vm.expectRevert(ValuationUpdateNotAllowed.selector);
        vault.securityCouncilUpdateTotalAssets(1);
    }

    function test_securityCouncil_whenTotalAssetsExpired_canUpdateNav() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(vault.securityCouncil());
        vault.securityCouncilUpdateTotalAssets(1);
    }
}
