// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract TestSyncDeposit is BaseTest {
    using Math for uint256;

    uint16 entryFeeRate = 1000; // 10 %

    function setUp() public {
        setUpVault(0, 0, 0, entryFeeRate, 0);
        dealAndApproveAndWhitelist(user1.addr);

        // for the next 1000 seconds, we will be able to use the sync deposit flow
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);
    }

    function test_syncDeposit_simple() public {
        uint256 userBalance = assetBalance(user1.addr);
        uint256 expectedShares = vault.convertToShares(
            userBalance - userBalance.mulDiv(entryFeeRate, FeeLib.BPS_DIVIDER, Math.Rounding.Ceil)
        );
        // it will be equal since pps is 1:1
        vm.expectEmit(true, true, true, true);
        emit DepositSync(user1.addr, user1.addr, userBalance, expectedShares);
        emit Referral(address(0), user1.addr, 0, userBalance);
        vm.prank(user1.addr);
        uint256 shares = vault.syncDeposit(userBalance, user1.addr, address(0));

        assertEq(shares, vault.balanceOf(user1.addr), "shares received != user balance");
        assertEq(shares, expectedShares, "shares received != expected shares");
    }

    function test_syncDeposit_lifespanOutdate() public {
        // we go one second after the expiration
        vm.warp(block.timestamp + 1001);

        vm.expectRevert(OnlyAsyncDepositAllowed.selector);
        vm.prank(user1.addr);
        vault.syncDeposit(1, user1.addr, address(0));
    }

    function test_syncDeposit_differentReceiver() public {
        test_syncDeposit_simple();
        dealAndApproveAndWhitelist(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        uint256 expectedShares = vault.convertToShares(
            userBalance - userBalance.mulDiv(entryFeeRate, FeeLib.BPS_DIVIDER, Math.Rounding.Ceil)
        );
        vm.prank(user1.addr);
        address[] memory wl = new address[](1);
        wl[0] = user2.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        vm.expectEmit(true, true, true, false);
        emit DepositSync(user1.addr, user2.addr, userBalance, expectedShares);
        vm.expectEmit(true, true, true, false);

        emit Referral(user2.addr, user1.addr, 0, userBalance);

        vm.prank(user1.addr);
        uint256 shares = vault.syncDeposit(userBalance, user2.addr, user2.addr);

        assertEq(shares, vault.balanceOf(user2.addr));
        assertEq(shares, expectedShares);
    }

    function test_syncDeposit_addressZeroReceiver() public {
        test_syncDeposit_simple();
        dealAndApproveAndWhitelist(user1.addr);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(user1.addr);
        vault.syncDeposit(1, address(0), address(0));
    }

    function test_syncDeposit_whenPaused() public {
        test_syncDeposit_simple();
        dealAndApproveAndWhitelist(user1.addr);

        // pause the vault
        vm.prank(admin.addr);
        vault.pause();

        // make sure he is wl
        address[] memory wl = new address[](1);
        wl[0] = user1.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(user1.addr);
        vault.syncDeposit(1, user1.addr, address(0));
    }

    function test_syncDeposit_whenClosed() public {
        dealAndApproveAndWhitelist(user1.addr);

        address[] memory wl = new address[](1);
        wl[0] = user1.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        // close the vault
        vm.prank(admin.addr);
        vault.initiateClosing();

        vm.prank(safe.addr);
        vault.expireTotalAssets();

        updateNewTotalAssets(vault.totalAssets());
        vm.stopPrank();

        vm.expectRevert(OnlyAsyncDepositAllowed.selector);
        vm.prank(user1.addr);
        vault.syncDeposit(1, user1.addr, address(0));

        vm.startPrank(safe.addr);
        vault.close(vault.newTotalAssets());
        vm.stopPrank();

        // make sure he is wl

        vm.expectRevert(abi.encodeWithSelector(NotOpen.selector, State.Closed));
        vm.prank(user1.addr);
        vault.syncDeposit(1, user1.addr, address(0));
    }

    function test_syncDeposit_whitelist() public {
        dealAndApproveAndWhitelist(user1.addr);

        vm.expectRevert(NotWhitelisted.selector);
        vm.prank(user2.addr);
        vault.syncDeposit(1, user2.addr, address(0));
    }

    function test_whenSyncDepositAllowed_asyncDepositIsForbidden() public {
        dealAndApproveAndWhitelist(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert(OnlySyncDepositAllowed.selector);
        vault.requestDeposit(12, user1.addr, user1.addr);
    }

    function test_syncDeposit_with_eth() public {
        uint256 userBalance = 10e18;

        // checking initial state
        uint256 safeAssetsBefore = assetBalance(address(vault.safe()));
        assertEq(assetBalance(address(vault.pendingSilo())), 0, "pending silo asset balance is not 0"); // pendingSilo
        // has 0 assets
        uint256 safeEthBefore = address(vault.safe()).balance;

        if (!underlyingIsNativeToken) {
            vm.startPrank(user1.addr);
            vm.expectRevert(CantDepositNativeToken.selector);
            vault.syncDeposit{value: 1}(userBalance, user1.addr, user1.addr);
            vm.stopPrank();

            setUpVault(0, 0, 0);
            whitelist(user1.addr);
        } else {
            vm.startPrank(user1.addr);
            // vm.expectRevert(CantDepositNativeToken.selector);
            vault.syncDeposit{value: 1}(userBalance, user1.addr, user1.addr);
            assertEq(assetBalance(address(vault.safe())), safeAssetsBefore + 1, "safe should have received the weth"); // safe
            // has received
            // the weth
            assertEq(assetBalance(address(vault.pendingSilo())), 0, "silo should have receiver 0"); // silo has received
            // 0
            assertEq(address(vault.safe()).balance, safeEthBefore, "safe should have received 0 eth"); // safe has
            // received 0 eth
            // assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
        }
    }
}
