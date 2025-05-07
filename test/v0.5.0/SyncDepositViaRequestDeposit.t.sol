// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract TestSyncDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);

        // for the next 1000 seconds, we will be able to use the sync deposit flow
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);
    }

    function test_syncDeposit() public {
        uint256 userBalanceBefore = assetBalance(user1.addr);
        // it will be equal since pps is 1:1
        uint256 sharesBefore = vault.balanceOf(user1.addr);
        assertEq(sharesBefore, 0, "asert 1");

        vm.prank(user1.addr);
        uint256 ret = vault.requestDeposit(userBalanceBefore, user1.addr, user1.addr);
        assertEq(userBalanceBefore * 10 ** vault.decimalsOffset(), vault.balanceOf(user1.addr), "assert 2");
    }

    function test_syncDeposit_lifespanOutdate() public {
        // we go one second after the expiration
        vm.warp(block.timestamp + 1001);

        // vm.expectRevert(TotalAssetsExpired.selector);
        vm.prank(user1.addr);
        vault.requestDeposit(1, user1.addr, user1.addr);
        assertEq(1, vault.pendingDepositRequest(0, user1.addr));
    }

    function test_syncDeposit_differentReceiver() public {
        test_syncDeposit();
        dealAndApproveAndWhitelist(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        vm.prank(user1.addr);
        address[] memory wl = new address[](1);
        wl[0] = user2.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        vm.prank(user1.addr);
        uint256 shares = vault.requestDeposit(userBalance, user2.addr, user1.addr);
        assertEq(shares, 0);
        assertEq(vault.balanceOf(user2.addr), userBalance * 10 ** vault.decimalsOffset());
    }

    function test_syncDeposit_addressZeroReceiver() public {
        test_syncDeposit();
        dealAndApproveAndWhitelist(user1.addr);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(user1.addr);
        vault.requestDeposit(1, address(0), user1.addr);
    }

    function test_syncDeposit_whenPaused() public {
        test_syncDeposit();
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
        vault.requestDeposit(1, user1.addr, user1.addr);
    }

    function test_syncDeposit_whenClosed() public {
        dealAndApproveAndWhitelist(user1.addr);

        // close the vault
        vm.prank(admin.addr);
        vault.initiateClosing();
        updateNewTotalAssets(vault.totalAssets());
        vm.stopPrank();
        vm.startPrank(safe.addr);
        vault.close(vault.newTotalAssets());
        vm.stopPrank();

        // make sure he is wl
        address[] memory wl = new address[](1);
        wl[0] = user1.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        vm.expectRevert(abi.encodeWithSelector(NotOpen.selector, State.Closed));
        vm.prank(user1.addr);
        vault.requestDeposit(1, user1.addr, user1.addr);
    }

    function test_syncDeposit_whitelist() public {
        dealAndApproveAndWhitelist(user1.addr);

        vm.expectRevert(NotWhitelisted.selector);
        vm.prank(user2.addr);
        vault.requestDeposit(1, user2.addr, user2.addr);
    }
}
