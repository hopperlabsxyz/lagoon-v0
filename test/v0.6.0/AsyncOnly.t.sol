// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AsyncOnly, OnlyAsyncDepositAllowed} from "@src/v0.6.0/primitives/Errors.sol";
import {AsyncOnlyActivated} from "@src/v0.6.0/primitives/Events.sol";

// Tests for the ActivateAsyncOnly functionality
contract TestAsyncOnly is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);

        // Set up a valid totalAssets with a lifespan so we can test the transition
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);
    }

    function test_ActivateAsyncOnly_setsIsAsyncOnlyToTrue() public {
        assertFalse(vault.isAsyncOnly(), "isAsyncOnly should be false initially");

        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        assertTrue(vault.isAsyncOnly(), "isAsyncOnly should be true after calling ActivateAsyncOnly");
    }

    function test_ActivateAsyncOnly_emitsAsyncOnlyActivatedEvent() public {
        vm.prank(vault.owner());
        vm.expectEmit(true, true, true, true);
        emit AsyncOnlyActivated();
        vault.activateAsyncOnly();
    }

    function test_ActivateAsyncOnly_setsTotalAssetsLifespanToZero() public {
        // Initially, lifespan should be non-zero (set in setUp)
        uint256 initialLifespan = vault.totalAssetsLifespan();
        assertGt(initialLifespan, 0, "Initial lifespan should be greater than 0");

        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        assertEq(vault.totalAssetsLifespan(), 0, "totalAssetsLifespan should be 0 after ActivateAsyncOnly");
    }

    function test_ActivateAsyncOnly_setsTotalAssetsExpirationToZero() public {
        // Initially, expiration should be non-zero (set in setUp)
        uint256 initialExpiration = vault.totalAssetsExpiration();
        assertGt(initialExpiration, 0, "Initial expiration should be greater than 0");

        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        assertEq(vault.totalAssetsExpiration(), 0, "totalAssetsExpiration should be 0 after ActivateAsyncOnly");
    }

    function test_ActivateAsyncOnly_comprehensiveTest() public {
        // Test all changes in one test
        assertFalse(vault.isAsyncOnly(), "isAsyncOnly should be false initially");
        uint256 initialLifespan = vault.totalAssetsLifespan();
        uint256 initialExpiration = vault.totalAssetsExpiration();
        assertGt(initialLifespan, 0, "Initial lifespan should be greater than 0");
        assertGt(initialExpiration, 0, "Initial expiration should be greater than 0");

        vm.prank(vault.owner());
        vm.expectEmit(true, true, true, true);
        emit AsyncOnlyActivated();
        vault.activateAsyncOnly();

        assertTrue(vault.isAsyncOnly(), "isAsyncOnly should be true");
        assertEq(vault.totalAssetsLifespan(), 0, "totalAssetsLifespan should be 0");
        assertEq(vault.totalAssetsExpiration(), 0, "totalAssetsExpiration should be 0");
    }

    function test_updateTotalAssetsLifespan_revertsWhenAsyncOnly() public {
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        vm.prank(vault.safe());
        vm.expectRevert(AsyncOnly.selector);
        vault.updateTotalAssetsLifespan(1000);
    }

    function test_settleDeposit_keepsTotalAssetsExpirationAtZero() public {
        // Set up a deposit request
        vm.prank(user1.addr);
        vault.syncDeposit(100 * 10 ** underlyingDecimals, user1.addr, user1.addr);

        // Disable sync deposit forever
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        assertEq(vault.totalAssetsExpiration(), 0, "Expiration should be 0 after ActivateAsyncOnly");

        // Update new total assets and settle
        updateNewTotalAssets(vault.totalAssets() + 50 * 10 ** underlyingDecimals);
        vm.warp(block.timestamp + 1 days);

        // Settle deposit
        uint256 newTotalAssets = vault.newTotalAssets();
        dealAmountAndApprove(vault.safe(), newTotalAssets);
        vm.prank(vault.safe());
        vault.settleDeposit(newTotalAssets);

        // After settlement, expiration should still be 0
        assertEq(vault.totalAssetsExpiration(), 0, "totalAssetsExpiration should remain 0 after settlement");
    }

    function test_settleRedeem_keepsTotalAssetsExpirationAtZero() public {
        // Set up: deposit, settle, then request redeem
        vm.prank(user1.addr);
        vault.syncDeposit(100 * 10 ** underlyingDecimals, user1.addr, user1.addr);

        vm.warp(block.timestamp + 1 days);
        updateAndSettle(vault.totalAssets());

        uint256 shares = vault.balanceOf(user1.addr);
        requestRedeem(shares / 2, user1.addr);

        // Disable sync deposit forever
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        assertEq(vault.totalAssetsExpiration(), 0, "Expiration should be 0 after ActivateAsyncOnly");

        // Update new total assets and settle redeem
        updateNewTotalAssets(vault.totalAssets() - 25 * 10 ** underlyingDecimals);
        vm.warp(block.timestamp + 1 days);

        // Settle redeem
        uint256 newTotalAssets = vault.newTotalAssets();
        dealAmountAndApprove(vault.safe(), newTotalAssets);
        vm.prank(vault.safe());
        vault.settleRedeem(newTotalAssets);

        // After settlement, expiration should still be 0
        assertEq(vault.totalAssetsExpiration(), 0, "totalAssetsExpiration should remain 0 after settlement");
    }

    function test_onlyOwnerCanCallActivateAsyncOnly() public {
        // Non-owner should not be able to call
        vm.prank(user1.addr);
        vm.expectRevert();
        vault.activateAsyncOnly();

        // Safe should not be able to call
        vm.prank(vault.safe());
        vm.expectRevert();
        vault.activateAsyncOnly();

        // Owner should be able to call
        vm.prank(vault.owner());
        vault.activateAsyncOnly();
        assertTrue(vault.isAsyncOnly(), "Owner should be able to disable sync deposit");
    }

    function test_syncDeposit_revertsWhenAsyncOnly() public {
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        dealAndApproveAndWhitelist(user2.addr);
        vm.prank(user2.addr);
        vm.expectRevert(OnlyAsyncDepositAllowed.selector);
        vault.syncDeposit(100 * 10 ** underlyingDecimals, user2.addr, address(0));
    }

    function test_syncRedeem_revertsWhenAsyncOnly() public {
        // First, deposit and settle to get some shares
        vm.prank(user1.addr);
        vault.syncDeposit(100 * 10 ** underlyingDecimals, user1.addr, user1.addr);

        vm.warp(block.timestamp + 1 days);
        updateAndSettle(vault.totalAssets());

        uint256 shares = vault.balanceOf(user1.addr);

        // Disable sync deposit forever
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        // Allow sync redeem
        vm.prank(vault.safe());
        vault.setIsSyncRedeemAllowed(true);

        // Try to sync redeem - should revert
        vm.prank(user1.addr);
        vm.expectRevert(AsyncOnly.selector);
        vault.syncRedeem(shares / 2, user1.addr);
    }

    function test_requestDeposit_succeedsWhenAsyncOnly() public {
        // Activate async-only mode
        vm.prank(vault.owner());
        vault.activateAsyncOnly();

        // Prepare user and amount
        dealAndApproveAndWhitelist(user3.addr);
        uint256 amount = 100 * 10 ** vault.underlyingDecimals();
        uint256 pendingBefore = vault.pendingDeposit();

        // requestDeposit should succeed in async-only mode
        requestDeposit(amount, user3.addr);

        // pendingDeposit should increase by amount
        assertEq(
            vault.pendingDeposit(),
            pendingBefore + amount,
            "pendingDeposit should increase by the deposited amount in async-only mode"
        );
    }
}
