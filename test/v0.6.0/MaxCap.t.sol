// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";

contract TestMaxCap is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);
    }

    /// @notice requestDeposit should revert when the maxCap would be exceeded due to totalAssets only
    function test_requestDeposit_revertWhenOverMaxCap_dueToTotalAssets() public {
        // set maxCap equal to current totalAssets
        uint256 initialTotalAssets = vault.totalAssets();

        vm.prank(vault.safe());
        vault.updateMaxCap(initialTotalAssets);

        // any positive new request should now revert
        uint256 amount = 1;
        vm.prank(user1.addr);
        vm.expectRevert(MaxCapReached.selector);
        vault.requestDeposit(amount, user1.addr, user1.addr);
    }

    /// @notice requestDeposit should revert when the maxCap would be exceeded due to pending requests in pendingSilo
    function test_requestDeposit_revertWhenOverMaxCap_dueToPendingRequests() public {
        // First request fully under a large max cap
        uint256 firstAmount = 100 * 10 ** vault.underlyingDecimals();

        requestDeposit(firstAmount, user1.addr);

        // Now set maxCap just below totalAssets + pending + new request
        uint256 secondAmount = 10 * 10 ** vault.underlyingDecimals();

        // cap = pending (firstAmount) + secondAmount - 1
        vm.prank(vault.safe());
        vault.updateMaxCap(firstAmount + secondAmount - 1);

        vm.prank(user2.addr);
        vm.expectRevert(MaxCapReached.selector);
        vault.requestDeposit(secondAmount, user2.addr, user2.addr);

        // lowering the second request amount should make it succeed
        uint256 fixedSecondAmount = secondAmount - 1;
        vm.prank(user2.addr);
        vault.requestDeposit(fixedSecondAmount, user2.addr, user2.addr);
    }

    /// @notice syncDeposit should respect maxCap based only on totalAssets when there are no pending deposits
    function test_syncDeposit_revertWhenOverMaxCap_dueToTotalAssets() public {
        // enable syncDeposit
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);

        uint256 firstAmount = 100 * 10 ** vault.underlyingDecimals();
        vm.prank(user1.addr);
        vault.syncDeposit(firstAmount, user1.addr, address(0));

        // totalAssets == firstAmount now
        // set maxCap to totalAssets + allowedDelta
        uint256 allowedDelta = 10 * 10 ** vault.underlyingDecimals();
        uint256 newMaxCap = vault.totalAssets() + allowedDelta;

        vm.prank(vault.safe());
        vault.updateMaxCap(newMaxCap);

        // try to deposit more than the allowedDelta -> should revert
        uint256 tooBig = allowedDelta + 1;
        vm.prank(user2.addr);
        vm.expectRevert(MaxCapReached.selector);
        vault.syncDeposit(tooBig, user2.addr, address(0));

        // reducing the deposit amount to allowedDelta should succeed
        vm.prank(user2.addr);
        vault.syncDeposit(allowedDelta, user2.addr, address(0));
    }

    // /// @notice syncDeposit should revert when pendingSilo balance is part of breaching the cap
    function test_syncDeposit_revertWhenOverMaxCap_dueToPendingSilo() public {
        // enable syncDeposit
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);

        updateNewTotalAssets(0);
        uint256 pendingAmount = 50 * 10 ** vault.underlyingDecimals();
        requestDeposit(pendingAmount, user2.addr);

        settle();

        assertNotEq(0, vault.pendingDeposit());

        // now we have a vault that is synchronous with pending request in the silo

        // Now set a cap that will be exceeded when we account for pendingSilo + new syncDeposit
        uint256 syncAmount = 20 * 10 ** vault.underlyingDecimals();

        // set cap to pendingAmount + syncAmount - 1
        vm.prank(vault.safe());
        vault.updateMaxCap(pendingAmount + syncAmount - 1);

        vm.prank(user2.addr);
        vm.expectRevert(MaxCapReached.selector);
        vault.syncDeposit(syncAmount, user2.addr, address(0));

        // increase maxCap by 1 should make it fit under the cap
        vm.prank(vault.safe());
        vault.updateMaxCap(pendingAmount + syncAmount);
        vm.prank(user2.addr);
        vault.syncDeposit(syncAmount, user2.addr, address(0));
    }
}

