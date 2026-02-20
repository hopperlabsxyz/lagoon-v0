// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "../Base.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SanctionsList} from "@src/v0.6.0/interfaces/SanctionsList.sol";
import {AccessMode} from "@src/v0.6.0/primitives/Enums.sol";

contract TestBlacklist is BaseTest {
    address constant EXTERNAL_SANCTIONS_LIST = 0x40C57923924B5c5c5455c48D93317139ADDaC8fb;
    address constant SANCTIONED_ADDRESS = 0xd5ED34b52AC4ab84d8FA8A231a3218bbF01Ed510;

    function withWhitelistSetUp() public {
        whitelistInit.push(user5.addr);
        setUpVault(0, 0, 0);
        for (uint256 i; i < whitelistInit.length; i++) {
            assertTrue(vault.isAllowed(whitelistInit[i]));
        }
        dealAndApprove(user1.addr);
    }

    function test_transfer_WhenReceiverNotWhitelistedAfterDeactivateOfWhitelisting() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        requestDeposit(userBalance, user1.addr);

        updateAndSettle(0);

        deposit(userBalance, user1.addr);
        address receiver = user2.addr;
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);
        vm.assertEq(vault.isBlacklistActivated(), true);
        vm.assertEq(vault.isWhitelistActivated(), false);
        uint256 shares = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        vault.transfer(receiver, shares);
    }

    function test_sanctionedAddress_ShouldReturnFalseInBlacklistMode() public {
        if (block.chainid != 1) return;
        withWhitelistSetUp();

        vm.prank(vault.whitelistManager());
        vault.setExternalSanctionsList(SanctionsList(EXTERNAL_SANCTIONS_LIST));

        // Switch to Blacklist mode
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        // We make sure that the sanctioned address is blacklisted
        assertFalse(
            vault.isAllowed(SANCTIONED_ADDRESS),
            "Sanctioned address should return false even when manually whitelisted in Blacklist mode"
        );
    }

    function test_transfer_RevertsWhen_SenderIsBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        blacklist(user1.addr);

        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user1.addr));
        vault.transfer(user2.addr, shares);
    }

    function test_transfer_RevertsWhen_ReceiverIsBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        blacklist(user2.addr);

        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user2.addr));
        vault.transfer(user2.addr, shares);
    }

    function test_transfer_SucceedsWhen_NeitherPartyIsBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        address receiver = user2.addr;

        vm.prank(user1.addr);
        vault.transfer(receiver, shares);

        assertEq(vault.balanceOf(receiver), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transferFrom_RevertsWhen_SenderIsBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        blacklist(user1.addr);

        vm.prank(user1.addr);
        vault.approve(user2.addr, shares);

        vm.prank(user2.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user1.addr));
        vault.transferFrom(user1.addr, user3.addr, shares);
    }

    function test_transferFrom_RevertsWhen_ReceiverIsBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        blacklist(user3.addr);

        vm.prank(user1.addr);
        vault.approve(user2.addr, shares);

        vm.prank(user2.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user3.addr));
        vault.transferFrom(user1.addr, user3.addr, shares);
    }

    function test_transferFrom_RevertsWhen_BothPartiesAreBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        blacklist(user1.addr);
        blacklist(user3.addr);

        vm.prank(user1.addr);
        vault.approve(user2.addr, shares);

        vm.prank(user2.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user1.addr));
        vault.transferFrom(user1.addr, user3.addr, shares);
    }

    function test_transferFrom_SucceedsWhen_NeitherPartyIsBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);

        vm.prank(user1.addr);
        vault.approve(user2.addr, shares);

        vm.prank(user2.addr);
        vault.transferFrom(user1.addr, user3.addr, shares);

        assertEq(vault.balanceOf(user3.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_revokeFromBlacklist() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        // Blacklist an address
        blacklist(user1.addr);
        assertFalse(vault.isAllowed(user1.addr), "Address should be blacklisted");

        // Revoke from blacklist and verify event
        vm.expectEmit(true, false, false, false);
        emit BlacklistUpdated(user1.addr, false);

        vm.prank(vault.whitelistManager());
        address[] memory accounts = new address[](1);
        accounts[0] = user1.addr;
        vault.revokeFromBlacklist(accounts);

        // Verify address is no longer blacklisted
        assertTrue(vault.isAllowed(user1.addr), "Address should no longer be blacklisted");
    }

    function test_revokeFromBlacklist_MultipleAddresses() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        // Blacklist multiple addresses
        address[] memory toBlacklist = new address[](2);
        toBlacklist[0] = user1.addr;
        toBlacklist[1] = user2.addr;
        blacklist(toBlacklist);

        assertFalse(vault.isAllowed(user1.addr), "user1 should be blacklisted");
        assertFalse(vault.isAllowed(user2.addr), "user2 should be blacklisted");

        // Revoke from blacklist
        vm.prank(vault.whitelistManager());
        vault.revokeFromBlacklist(toBlacklist);

        // Verify addresses are no longer blacklisted
        assertTrue(vault.isAllowed(user1.addr), "user1 should no longer be blacklisted");
        assertTrue(vault.isAllowed(user2.addr), "user2 should no longer be blacklisted");
    }

    function test_claimSharesOnBehalf_DoesNotRevertWhenUserBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        dealAndApprove(user3.addr);

        uint256 user1Balance = assetBalance(user1.addr);
        uint256 user2Balance = assetBalance(user2.addr);
        uint256 user3Balance = assetBalance(user3.addr);

        requestDeposit(user1Balance, user1.addr);
        requestDeposit(user2Balance, user2.addr);
        requestDeposit(user3Balance, user3.addr);
        // In blacklist mode, users are whitelisted by default
        // We blacklist user3
        blacklist(user3.addr);

        updateAndSettle(0);
        vm.warp(block.timestamp + 1);

        // All three users have claimable deposits
        assertGt(vault.maxDeposit(user1.addr), 0, "user1 should have claimable deposit");
        assertGt(vault.maxDeposit(user2.addr), 0, "user2 should have claimable deposit");
        assertGt(vault.maxDeposit(user3.addr), 0, "user3 should have claimable deposit");

        address[] memory controllers = new address[](3);
        controllers[0] = user1.addr;
        controllers[1] = user2.addr;
        controllers[2] = user3.addr; // blacklisted

        // Should not revert, but skip user3
        vm.prank(safe.addr);
        vault.claimSharesOnBehalf(controllers);

        // user1 and user2 should have received shares
        assertGt(vault.balanceOf(user1.addr), 0, "user1 should have received shares");
        assertGt(vault.balanceOf(user2.addr), 0, "user2 should have received shares");
        // user3 should not have received shares (skipped)
        assertEq(vault.balanceOf(user3.addr), 0, "user3 should not have received shares");
        // user3 should still have claimable deposit
        assertGt(vault.maxDeposit(user3.addr), 0, "user3 should still have claimable deposit");
    }

    function test_claimAssetsOnBehalf_DoesNotRevertWhenUserBlacklisted() public {
        withWhitelistSetUp();
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);

        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        dealAndApprove(user3.addr);

        uint256 user1Balance = assetBalance(user1.addr);
        uint256 user2Balance = assetBalance(user2.addr);
        uint256 user3Balance = assetBalance(user3.addr);

        requestDeposit(user1Balance, user1.addr);
        requestDeposit(user2Balance, user2.addr);
        requestDeposit(user3Balance, user3.addr);

        // First, deposit and get shares
        updateAndSettle(0);
        vm.warp(block.timestamp + 1);

        // Deposit shares
        vm.prank(user1.addr);
        vault.deposit(user1Balance, user1.addr);
        vm.prank(user2.addr);
        vault.deposit(user2Balance, user2.addr);
        vm.prank(user3.addr);
        vault.deposit(user3Balance, user3.addr);

        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Shares = vault.balanceOf(user2.addr);
        uint256 user3Shares = vault.balanceOf(user3.addr);

        // Request redeems
        vm.prank(user1.addr);
        vault.requestRedeem(user1Shares, user1.addr, user1.addr);
        vm.prank(user2.addr);
        vault.requestRedeem(user2Shares, user2.addr, user2.addr);
        vm.prank(user3.addr);
        vault.requestRedeem(user3Shares, user3.addr, user3.addr);

        updateAndSettle(user1Balance + user2Balance + user3Balance);
        vm.warp(block.timestamp + 1);

        // We blacklist user3
        blacklist(user3.addr);

        // All three users have claimable redeems
        assertGt(vault.maxRedeem(user1.addr), 0, "user1 should have claimable redeem");
        assertGt(vault.maxRedeem(user2.addr), 0, "user2 should have claimable redeem");
        assertGt(vault.maxRedeem(user3.addr), 0, "user3 should have claimable redeem");

        uint256 user1AssetBefore = underlying.balanceOf(user1.addr);
        uint256 user2AssetBefore = underlying.balanceOf(user2.addr);
        uint256 user3AssetBefore = underlying.balanceOf(user3.addr);

        address[] memory controllers = new address[](3);
        controllers[0] = user1.addr;
        controllers[1] = user2.addr;
        controllers[2] = user3.addr; // blacklisted

        // Should not revert, but skip user3
        vm.prank(safe.addr);
        vault.claimAssetsOnBehalf(controllers);

        // user1 and user2 should have received assets
        assertGt(underlying.balanceOf(user1.addr), user1AssetBefore, "user1 should have received assets");
        assertGt(underlying.balanceOf(user2.addr), user2AssetBefore, "user2 should have received assets");
        // user3 should not have received assets (skipped)
        assertEq(underlying.balanceOf(user3.addr), user3AssetBefore, "user3 should not have received assets");
        // user3 should still have claimable redeem
        assertGt(vault.maxRedeem(user3.addr), 0, "user3 should still have claimable redeem");
    }
}
