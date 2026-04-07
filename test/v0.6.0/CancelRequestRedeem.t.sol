// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessMode} from "@src/v0.6.0/primitives/Enums.sol";

contract TestCancelRequestRedeem is BaseTest {
    uint256 shares;

    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        uint256 user1Assets = assetBalance(user1.addr);

        // Deposit for user1 so they have shares
        requestDeposit(user1Assets / 2, user1.addr);
        updateAndSettle(0);
        deposit(user1Assets / 2, user1.addr);
        vm.warp(block.timestamp + 1 days);

        // user1 requests a redeem
        shares = balance(user1.addr) / 2;
        requestRedeem(shares, user1.addr);
    }

    function test_cancelRequestRedeem_selfCancel() public {
        uint256 sharesBefore = balance(user1.addr);
        uint256 requestId = vault.redeemEpochId();

        assertEq(vault.pendingRedeemRequest(requestId, user1.addr), shares);

        vm.prank(user1.addr);
        vm.expectEmit(address(vault));
        emit RedeemRequestCanceled(requestId, user1.addr, shares);
        vault.cancelRequestRedeem(user1.addr);

        assertEq(vault.pendingRedeemRequest(requestId, user1.addr), 0);
        assertEq(balance(user1.addr), sharesBefore + shares);
    }

    function test_cancelRequestRedeem_revertsWhenNewTotalAssetsHasBeenUpdated() public {
        uint256 requestId = vault.lastRedeemRequestId(user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(RequestNotCancelable.selector, requestId));
        vault.cancelRequestRedeem(user1.addr);
    }

    function test_cancelRequestRedeem_asSuperOperator() public {
        uint256 sharesBefore = balance(user1.addr);

        vm.prank(superOperator.addr);
        vault.cancelRequestRedeem(user1.addr);

        assertEq(balance(user1.addr), sharesBefore + shares);
    }

    function test_cancelRequestRedeem_whenBlacklisted() public {
        // Switch to blacklist mode and blacklist user1
        vm.prank(vault.owner());
        vault.switchAccessMode(AccessMode.Blacklist);
        blacklist(user1.addr);

        uint256 sharesBefore = balance(user1.addr);

        vm.prank(user1.addr);
        vault.cancelRequestRedeem(user1.addr);

        assertEq(balance(user1.addr), sharesBefore + shares);
    }

    function test_cancelRequestRedeem_whenPaused_shouldRevert() public {
        vm.prank(vault.owner());
        vault.pause();

        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.cancelRequestRedeem(user1.addr);
    }

    function test_cancelRequestRedeem_asOperator() public {
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);

        uint256 sharesBefore = balance(user1.addr);

        vm.prank(user2.addr);
        vault.cancelRequestRedeem(user1.addr);

        assertEq(balance(user1.addr), sharesBefore + shares);
    }

    function test_cancelRequestRedeem_notOperator_shouldRevert() public {
        vm.prank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.cancelRequestRedeem(user1.addr);
    }

    function test_cancelRequestRedeem_superOperator_forProtocolFeeReceiver_shouldRevert() public {
        address protocolFeeReceiver = vault.protocolFeeReceiver();

        vm.prank(superOperator.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.cancelRequestRedeem(protocolFeeReceiver);
    }
}
