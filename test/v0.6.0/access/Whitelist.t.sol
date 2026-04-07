// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "../Base.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SanctionsList} from "@src/v0.6.0/interfaces/SanctionsList.sol";
import {AccessMode} from "@src/v0.6.0/primitives/Enums.sol";

contract TestWhitelist is BaseTest {
    address constant EXTERNAL_SANCTIONS_LIST = 0x40C57923924B5c5c5455c48D93317139ADDaC8fb;
    address constant SANCTIONED_ADDRESS = 0xd5ED34b52AC4ab84d8FA8A231a3218bbF01Ed510;

    function withWhitelistSetUp() public {
        whitelistInit.push(user5.addr);
        setUpVault(0, 0, 0);
        for (uint256 i; i < whitelistInit.length; i++) {
            assertTrue(vault.isAllowed(whitelistInit[i]));
        }
        assertTrue(vault.isWhitelistMode(), "Vault should be in whitelist mode initially");
        dealAndApprove(user1.addr);
    }

    function withoutWhitelistSetUp() public {
        whitelistInit.push(user5.addr);
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        for (uint256 i; i < whitelistInit.length; i++) {
            // By default, if whitelist is disabled all user are whitelisted
            assertTrue(vault.isAllowed(whitelistInit[i]));
        }
        dealAndApprove(user1.addr);
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);

        // referral
        vm.startPrank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user1.addr));
        vault.requestDeposit(userBalance, user1.addr, user1.addr, user2.addr);

        // no referral
        vm.startPrank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user1.addr));
        vault.requestDeposit(userBalance, user1.addr, user1.addr);
    }

    function test_requestDeposit_ShouldNotFailWhenControllerNotWhitelistedandOperatorAndOwnerAre() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        whitelist(controller);
        vm.startPrank(operator);
        vault.requestDeposit(userBalance, controller, owner);
    }

    function test_requestDeposit_WhenOwnerWhitelistedAndOperator() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        whitelist(controller);
        requestDeposit(userBalance, controller, operator, owner);
    }

    function test_transfer_ShouldWorkWhenReceiverWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        requestDeposit(userBalance, user1.addr);

        updateAndSettle(0);

        deposit(userBalance, user1.addr);
        uint256 shares = vault.balanceOf(user1.addr);
        address receiver = user2.addr;
        whitelist(user2.addr);
        vm.prank(user1.addr);
        assertTrue(vault.transfer(receiver, shares));
    }

    function test_whitelist() public {
        withWhitelistSetUp();
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, true);
        whitelist(user1.addr);
        assertEq(vault.isAllowed(user1.addr), true);
    }

    function test_whitelistList() public {
        withWhitelistSetUp();
        address[] memory users = new address[](2);
        users[0] = user1.addr;
        users[1] = user2.addr;
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, true);
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user2.addr, true);
        whitelist(users);
        assertEq(vault.isAllowed(user1.addr), true);
    }

    function test_unwhitelist() public {
        withWhitelistSetUp();
        address[] memory users = new address[](2);
        users[0] = user1.addr;
        users[1] = user2.addr;
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, true);
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user2.addr, true);
        whitelist(users);
        assertEq(vault.isAllowed(user1.addr), true, "user1 is not whitelisted");
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, false);
        unwhitelist(users[0]);
        assertEq(vault.isAllowed(user1.addr), false, "user1 is still whitelisted");
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user2.addr, false);
        unwhitelist(users[1]);
        assertEq(vault.isAllowed(user2.addr), false, "user2 is still whitelisted");
    }

    function test_unwhitelistList() public {
        withWhitelistSetUp();
        address[] memory users = new address[](2);

        users[0] = user1.addr;
        users[1] = user2.addr;

        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, true);

        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user2.addr, true);

        whitelist(users);

        assertEq(vault.isAllowed(user1.addr), true, "user1 is not whitelisted");

        assertEq(vault.isAllowed(user2.addr), true, "user2 is not whitelisted");

        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, false);

        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user2.addr, false);

        unwhitelist(users);

        assertEq(vault.isAllowed(user1.addr), false, "user1 is still whitelisted");
        assertEq(vault.isAllowed(user2.addr), false, "user2 is still whitelisted");
    }

    function test_noWhitelist() public {
        withoutWhitelistSetUp();
        requestDeposit(1, user1.addr);
    }

    function test_addToWhitelist_revert() public {
        withWhitelistSetUp();

        vm.expectRevert(abi.encodeWithSelector(OnlyWhitelistManager.selector, vault.whitelistManager()));
        vault.addToWhitelist(new address[](5));
    }

    function test_revokeFromWhitelist_revert() public {
        withWhitelistSetUp();

        vm.expectRevert(abi.encodeWithSelector(OnlyWhitelistManager.selector, vault.whitelistManager()));
        vault.revokeFromWhitelist(new address[](5));
    }

    function test_requestRedeemWithoutBeingWhitelisted() public {
        withWhitelistSetUp();
        dealAndApprove(user5.addr);
        uint256 userBalance = assetBalance(user5.addr);
        requestDeposit(userBalance, user5.addr);
        updateAndSettle(0);
        deposit(userBalance, user5.addr);
        uint256 shares = vault.balanceOf(user5.addr);
        address receiver = user1.addr;
        vm.prank(user5.addr);
        assertTrue(vault.transfer(receiver, shares));
        vm.startPrank(receiver);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, receiver));
        vault.requestRedeem(shares, receiver, receiver);
    }

    function test_whitelistedUserRemainsWhitelistedWhenSwitchingModes() public {
        withWhitelistSetUp();

        // whitelist user1 in whitelist mode
        whitelist(user1.addr);
        assertTrue(vault.isAllowed(user1.addr), "user1 should be whitelisted in whitelist mode");

        // switch to blacklist mode, user1 should remain effectively whitelisted
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);
        assertTrue(vault.isAllowed(user1.addr), "user1 should remain whitelisted in blacklist mode");

        // switch back to whitelist mode, user1 should still be whitelisted
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Whitelist);
        assertTrue(vault.isAllowed(user1.addr), "user1 should remain whitelisted after switching back");
    }

    function test_sanctionedAddress_ShouldReturnFalseInWhitelistMode() public {
        if (block.chainid != 1) return;
        withWhitelistSetUp();

        vm.prank(vault.whitelistManager());
        vault.setExternalSanctionsList(SanctionsList(EXTERNAL_SANCTIONS_LIST));

        // Ensure we're in Whitelist mode
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Whitelist);

        // Manually whitelist the sanctioned address
        address[] memory accounts = new address[](1);
        accounts[0] = SANCTIONED_ADDRESS;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(accounts);

        // Even though manually whitelisted, the sanctioned address should return false
        assertFalse(
            vault.isAllowed(SANCTIONED_ADDRESS),
            "Sanctioned address should return false even when manually whitelisted in Whitelist mode"
        );
    }

    function test_transfer_SucceedsWhen_SenderIsNotWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        unwhitelist(user1.addr);
        assertEq(vault.isAllowed(user1.addr), false);

        vm.prank(user1.addr);
        assertTrue(vault.transfer(user2.addr, shares));

        assertEq(vault.balanceOf(user2.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transfer_SucceedsWhen_ReceiverIsNotWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        unwhitelist(user2.addr);

        vm.prank(user1.addr);
        assertTrue(vault.transfer(user2.addr, shares));

        assertEq(vault.balanceOf(user2.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transfer_SucceedsWhen_NeitherPartyisAllowed() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        unwhitelist(user1.addr);
        unwhitelist(user2.addr);

        vm.prank(user1.addr);
        assertTrue(vault.transfer(user2.addr, shares));

        assertEq(vault.balanceOf(user2.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transfer_SucceedsWhen_BothPartiesAreWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);

        vm.prank(user1.addr);
        assertTrue(vault.transfer(user2.addr, shares));

        assertEq(vault.balanceOf(user2.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transferFrom_SucceedsWhen_SenderIsNotWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        unwhitelist(user1.addr);

        vm.prank(user1.addr);
        vault.approve(user2.addr, shares);

        vm.prank(user2.addr);
        assertTrue(vault.transferFrom(user1.addr, user3.addr, shares));

        assertEq(vault.balanceOf(user3.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transferFrom_SucceedsWhen_ReceiverIsNotWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        unwhitelist(user3.addr);

        vm.prank(user1.addr);
        vault.approve(user2.addr, shares);

        vm.prank(user2.addr);
        assertTrue(vault.transferFrom(user1.addr, user3.addr, shares));

        assertEq(vault.balanceOf(user3.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transferFrom_SucceedsWhen_NeitherPartyisAllowed() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        deposit(userBalance, user1.addr);

        uint256 shares = vault.balanceOf(user1.addr);
        unwhitelist(user1.addr);
        unwhitelist(user3.addr);

        vm.prank(user1.addr);
        vault.approve(user2.addr, shares);

        vm.prank(user2.addr);
        assertTrue(vault.transferFrom(user1.addr, user3.addr, shares));

        assertEq(vault.balanceOf(user3.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_transferFrom_SucceedsWhen_BothPartiesAreWhitelisted() public {
        withWhitelistSetUp();
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
        assertTrue(vault.transferFrom(user1.addr, user3.addr, shares));

        assertEq(vault.balanceOf(user3.addr), shares);
        assertEq(vault.balanceOf(user1.addr), 0);
    }

    function test_claimSharesOnBehalf_DoesNotRevertWhenUserNotWhitelisted() public {
        withWhitelistSetUp();
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        dealAndApprove(user3.addr);

        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);

        uint256 user1Balance = assetBalance(user1.addr);
        uint256 user2Balance = assetBalance(user2.addr);
        uint256 user3Balance = assetBalance(user3.addr);

        requestDeposit(user1Balance, user1.addr);
        requestDeposit(user2Balance, user2.addr);
        requestDeposit(user3Balance, user3.addr);

        updateAndSettle(0);
        vm.warp(block.timestamp + 1);

        // All three users have claimable deposits
        assertGt(vault.maxDeposit(user1.addr), 0, "user1 should have claimable deposit");
        assertGt(vault.maxDeposit(user2.addr), 0, "user2 should have claimable deposit");
        assertGt(vault.maxDeposit(user3.addr), 0, "user3 should have claimable deposit");

        unwhitelist(user3.addr);

        address[] memory controllers = new address[](3);
        controllers[0] = user1.addr;
        controllers[1] = user2.addr;
        controllers[2] = user3.addr; // not whitelisted

        // Should revert, user3 is not whitelisted
        vm.prank(safe.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user3.addr));

        vault.claimSharesOnBehalf(controllers);
    }

    function test_claimAssetsOnBehalf_RevertsWhenUserNotWhitelisted() public {
        withWhitelistSetUp();
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        dealAndApprove(user3.addr);

        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
        // user3 is not whitelisted

        uint256 user1Balance = assetBalance(user1.addr);
        uint256 user2Balance = assetBalance(user2.addr);
        uint256 user3Balance = assetBalance(user3.addr);

        // First, deposit and get shares
        requestDeposit(user1Balance, user1.addr);
        requestDeposit(user2Balance, user2.addr);
        requestDeposit(user3Balance, user3.addr);
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

        // All three users have claimable redeems
        assertGt(vault.maxRedeem(user1.addr), 0, "user1 should have claimable redeem");
        assertGt(vault.maxRedeem(user2.addr), 0, "user2 should have claimable redeem");
        assertGt(vault.maxRedeem(user3.addr), 0, "user3 should have claimable redeem");

        address[] memory controllers = new address[](3);
        controllers[0] = user1.addr;
        controllers[1] = user2.addr;
        controllers[2] = user3.addr; // not whitelisted

        unwhitelist(user3.addr);

        // Should revert, user3 is not whitelisted
        vm.prank(safe.addr);
        vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, user3.addr));
        vault.claimAssetsOnBehalf(controllers);
    }
}

