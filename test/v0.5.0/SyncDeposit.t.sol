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
        uint256 userBalance = assetBalance(user1.addr);
        // it will be equal since pps is 1:1

        vm.prank(user1.addr);
        uint256 shares = vault.syncDeposit(userBalance, user1.addr, address(0));

        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
    }

    function test_syncDeposit_lifespanOutdate() public {
        // we go one second after the expiration
        vm.warp(block.timestamp + 1001);

        vm.expectRevert(OnlyAsyncDepositAllowed.selector);
        vm.prank(user1.addr);
        vault.syncDeposit(1, user1.addr, address(0));
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
        uint256 shares = vault.syncDeposit(userBalance, user2.addr, address(0));
        assertEq(shares, vault.balanceOf(user2.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
    }

    function test_syncDeposit_addressZeroReceiver() public {
        test_syncDeposit();
        dealAndApproveAndWhitelist(user1.addr);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(user1.addr);
        vault.syncDeposit(1, address(0), address(0));
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
        vault.unvalidateTotalAssets();

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
}
