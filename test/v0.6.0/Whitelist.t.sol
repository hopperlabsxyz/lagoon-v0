// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SanctionsList} from "@src/v0.6.0/interfaces/SanctionsList.sol";
import {WhitelistState} from "@src/v0.6.0/primitives/Enums.sol";

contract TestWhitelist is BaseTest {
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

    function withoutWhitelistSetUp() public {
        whitelistInit.push(user5.addr);
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        for (uint256 i; i < whitelistInit.length; i++) {
            // By default, if whitelist is disabled all user are whitelisted
            assertTrue(vault.isWhitelisted(whitelistInit[i]));
        }
        dealAndApprove(user1.addr);
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);

        // referral
        vm.startPrank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestDeposit(userBalance, user1.addr, user1.addr, user2.addr);

        // no referral
        vm.startPrank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestDeposit(userBalance, user1.addr, user1.addr);
    }

    function test_requestDeposit_ShouldNotFailWhenControllerNotWhitelistedandOperatorAndOwnerAre() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
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
        requestDeposit(userBalance, controller, operator, owner);
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
        vault.switchWhitelistMode(WhitelistState.Deactivated);
        vm.assertEq(vault.isWhitelistActivated(), false);
        uint256 shares = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        vault.transfer(receiver, shares);
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
        vault.transfer(receiver, shares);
    }

    function test_whitelist() public {
        withWhitelistSetUp();
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, true);
        whitelist(user1.addr);
        assertEq(vault.isWhitelisted(user1.addr), true);
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
        assertEq(vault.isWhitelisted(user1.addr), true);
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
        assertEq(vault.isWhitelisted(user1.addr), true, "user1 is not whitelisted");
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, false);
        unwhitelist(users[0]);
        assertEq(vault.isWhitelisted(user1.addr), false, "user1 is still whitelisted");
        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user2.addr, false);
        unwhitelist(users[1]);
        assertEq(vault.isWhitelisted(user2.addr), false, "user2 is still whitelisted");
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

        assertEq(vault.isWhitelisted(user1.addr), true, "user1 is not whitelisted");

        assertEq(vault.isWhitelisted(user2.addr), true, "user2 is not whitelisted");

        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user1.addr, false);

        vm.expectEmit(true, true, true, true);
        emit WhitelistUpdated(user2.addr, false);

        unwhitelist(users);

        assertEq(vault.isWhitelisted(user1.addr), false, "user1 is still whitelisted");
        assertEq(vault.isWhitelisted(user2.addr), false, "user2 is still whitelisted");
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
        vault.transfer(receiver, shares);
        vm.prank(receiver);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestRedeem(shares, receiver, receiver);
    }

    function test_sanctionedAddress_ShouldReturnFalseInWhitelistMode() public {
        if (block.chainid != 1) return;
        withWhitelistSetUp();

        vm.prank(vault.whitelistManager());
        vault.setExternalSanctionsList(SanctionsList(EXTERNAL_SANCTIONS_LIST));

        // Ensure we're in Whitelist mode
        vm.prank(vault.owner());
        vault.switchWhitelistMode(WhitelistState.Whitelist);

        // Manually whitelist the sanctioned address
        address[] memory accounts = new address[](1);
        accounts[0] = SANCTIONED_ADDRESS;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(accounts);

        // Even though manually whitelisted, the sanctioned address should return false
        assertFalse(
            vault.isWhitelisted(SANCTIONED_ADDRESS),
            "Sanctioned address should return false even when manually whitelisted in Whitelist mode"
        );
    }

    function test_sanctionedAddress_ShouldReturnFalseInBlacklistMode() public {
        if (block.chainid != 1) return;
        withWhitelistSetUp();

        vm.prank(vault.whitelistManager());
        vault.setExternalSanctionsList(SanctionsList(EXTERNAL_SANCTIONS_LIST));

        // Switch to Blacklist mode
        vm.prank(vault.owner());
        vault.switchWhitelistMode(WhitelistState.Blacklist);

        // We make sure that the sanctioned address is blacklisted
        assertFalse(
            vault.isWhitelisted(SANCTIONED_ADDRESS),
            "Sanctioned address should return false even when manually whitelisted in Blacklist mode"
        );
    }
}
