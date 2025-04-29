// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_syncDeposit() public {
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);

        // for the next 1000 seconds, we will use the sync deposit flow
        uint256 userBalance = assetBalance(user1.addr);
        // it will be equal since pps is 1:1
        assertEq(vault.previewDeposit(userBalance), userBalance * 10 ** vault.decimalsOffset());

        vm.prank(user1.addr);
        uint256 shares = vault.syncDeposit(userBalance, user1.addr);
        // assertEq(vault.convertToShares(userBalance, requestId), shares);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
    }

    function test_syncDeposit_lifespanOutdate() public {
        test_syncDeposit();
        vm.warp(block.timestamp + 1001);
        dealAndApproveAndWhitelist(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        vm.expectRevert(TotalAssetsExpired.selector);
        vm.prank(user1.addr);
        vault.syncDeposit(userBalance, user1.addr);
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
        uint256 shares = vault.syncDeposit(userBalance, user2.addr);
        assertEq(shares, vault.balanceOf(user2.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
    }

    function test_syncDeposit_addressZeroReceiver() public {
        test_syncDeposit();
        dealAndApproveAndWhitelist(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vm.prank(user1.addr);
        vault.syncDeposit(userBalance, address(0));
    }

    function test_syncDeposit_whenPaused() public {
        test_syncDeposit();
        dealAndApproveAndWhitelist(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        // vm.expectRevert(NotWhitelisted.selector);
        address[] memory wl = new address[](1);
        wl[0] = user1.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        vm.prank(user1.addr);
        vault.syncDeposit(userBalance, user1.addr);
    }

    function test_deposit_shouldRevertIfInvalidReceiver() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 totalSupplyBefore = vault.totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(user1.addr);
        vault.deposit(userBalance, address(0));
        uint256 totalSupplyAfter = vault.totalSupply();
        assertEq(totalSupplyBefore, totalSupplyAfter, "supply before != supply after");
    }
}
