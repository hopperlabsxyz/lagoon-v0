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
            assertTrue(vault.isWhitelisted(whitelistInit[i]));
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
            vault.isWhitelisted(SANCTIONED_ADDRESS),
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
}
