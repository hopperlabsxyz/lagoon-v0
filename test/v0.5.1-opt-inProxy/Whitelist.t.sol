// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestWhitelist is BaseTest {
    function withWhitelistSetUp() public {
        whitelistInit.push(user5.addr);
        enableWhitelist = true;
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

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelistedandOperatorAndOwnerAre() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        vm.startPrank(operator);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestDeposit(userBalance, controller, owner);
    }

    function test_cancelRequestDeposit_shouldFailWhenNotWhitelisted() public {
        withWhitelistSetUp();
        dealAndApprove(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        requestDeposit(userBalance, user1.addr);

        vm.prank(vault.whitelistManager());
        address[] memory users = new address[](1);
        users[0] = user1.addr;
        vault.revokeFromWhitelist(users);
        vm.prank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.cancelRequestDeposit();
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
        vault.disableWhitelist();
        vm.assertEq(vault.isWhitelistActivated(), false);
        uint256 shares = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        assertTrue(vault.transfer(receiver, shares));
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
        assertTrue(vault.transfer(receiver, shares));

        // owner is not whitelisted
        vm.prank(receiver);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestRedeem(shares, user5.addr, receiver);

        // controller is not whitelisted
        vm.prank(receiver);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestRedeem(shares, receiver, user5.addr);

        // owner and controller are not whitelisted
        vm.prank(user5.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestRedeem(shares, receiver, receiver);
    }

    function test_requestDepositWithoutBeingWhitelisted() public {
        withWhitelistSetUp();
        uint256 amount = 1;
        address whitelisted = user5.addr;
        address unwhitelisted = user1.addr;

        // owner is not whitelisted
        vm.prank(unwhitelisted);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestDeposit(amount, whitelisted, unwhitelisted);

        // controller is not whitelisted
        dealAndApprove(whitelisted);
        vm.prank(whitelisted);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestDeposit(amount, unwhitelisted, whitelisted);

        // owner and controller are not whitelisted, operator is whitelisted
        vm.startPrank(unwhitelisted);
        vault.setOperator(whitelisted, true);
        vm.stopPrank();

        vm.prank(whitelisted);
        vm.expectRevert(NotWhitelisted.selector);
        vault.requestDeposit(amount, unwhitelisted, unwhitelisted);
    }

    function test_claimSharesAndRequestRedeemWithoutBeingWhitelisted() public {
        withWhitelistSetUp();

        // msg.sender is not whitelisted
        vm.prank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.claimSharesAndRequestRedeem(1);
    }

    function test_claimSharesOnBehalfWithoutBeingWhitelisted() public {
        withWhitelistSetUp();

        // create a claimable deposit for a whitelisted user
        dealAndApprove(user5.addr);
        uint256 amount = assetBalance(user5.addr);
        requestDeposit(amount, user5.addr);
        updateAndSettle(0);

        // now remove user5 from the whitelist
        unwhitelist(user5.addr);

        address[] memory controllers = new address[](1);
        controllers[0] = user5.addr;

        vm.prank(safe.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.claimSharesOnBehalf(controllers);
    }

    function test_depositWithoutBeingWhitelisted() public {
        withWhitelistSetUp();
        uint256 amount = 1;

        // receiver is not whitelisted
        vm.prank(user5.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.deposit(amount, user1.addr);

        // controller is not whitelisted
        vm.prank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.deposit(amount, user5.addr);
    }

    function test_mintWithoutBeingWhitelisted() public {
        withWhitelistSetUp();
        uint256 shares = 1;

        // receiver is not whitelisted
        vm.prank(user5.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.mint(shares, user1.addr);

        // controller is not whitelisted
        vm.prank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.mint(shares, user1.addr, user1.addr);
    }

    function test_mintForWhitelistedUser() public {
        withWhitelistSetUp();
        uint256 shares = 1;
        // create a claimable deposit for a whitelisted user
        dealAndApprove(user5.addr);
        uint256 amount = assetBalance(user5.addr);
        requestDeposit(amount, user5.addr);
        updateAndSettle(0);

        vm.prank(user5.addr);
        // should work because controller and owner are whitelisted
        vault.mint(shares, user5.addr, user5.addr);

        vm.prank(user5.addr);
        // should work because controller and owner are whitelisted
        vault.mint(shares, user5.addr);
    }

    function test_depositForWhitelistedUser() public {
        withWhitelistSetUp();
        // create a claimable deposit for a whitelisted user
        dealAndApprove(user5.addr);
        uint256 amount = assetBalance(user5.addr);
        requestDeposit(amount, user5.addr);
        updateAndSettle(0);

        vm.prank(user5.addr);
        // should work because controller and owner are whitelisted
        vault.deposit(amount, user5.addr, user5.addr);
    }

    function test_withdrawWithoutBeingWhitelisted() public {
        withWhitelistSetUp();
        uint256 amount = 1;

        // receiver is not whitelisted
        vm.prank(user5.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.withdraw(amount, user1.addr, user5.addr);

        // controller is not whitelisted
        vm.prank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.withdraw(amount, user5.addr, user1.addr);
    }

    function test_withdrawForWhitelistedUser() public {
        withWhitelistSetUp();
        // create a claimable deposit for a whitelisted user
        dealAndApprove(user5.addr);
        uint256 amount = assetBalance(user5.addr);
        requestDeposit(amount, user5.addr);
        updateAndSettle(0);
        deposit(amount, user5.addr);

        uint256 shares = vault.balanceOf(user5.addr);
        requestRedeem(shares, user5.addr);
        updateAndSettle(amount);

        vm.prank(user5.addr);
        // should work because controller and owner are whitelisted
        vault.withdraw(1, user5.addr, user5.addr);
    }

    function test_redeemForWhitelistedUser() public {
        withWhitelistSetUp();
        // create a claimable deposit for a whitelisted user
        dealAndApprove(user5.addr);
        uint256 amount = assetBalance(user5.addr);
        requestDeposit(amount, user5.addr);
        updateAndSettle(0);
        deposit(amount, user5.addr);

        uint256 shares = vault.balanceOf(user5.addr);
        requestRedeem(shares, user5.addr);
        updateAndSettle(amount);

        vm.prank(user5.addr);
        // should work because controller and owner are whitelisted
        vault.redeem(1, user5.addr, user5.addr);
    }

    function test_redeemWithoutBeingWhitelisted() public {
        withWhitelistSetUp();
        uint256 shares = 1;

        // receiver is not whitelisted
        vm.prank(user5.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.redeem(shares, user1.addr, user5.addr);

        // controller is not whitelisted
        vm.prank(user1.addr);
        vm.expectRevert(NotWhitelisted.selector);
        vault.redeem(shares, user5.addr, user1.addr);
    }
}
