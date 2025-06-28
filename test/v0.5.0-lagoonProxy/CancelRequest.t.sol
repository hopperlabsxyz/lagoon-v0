// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestCancelRequest is BaseTest {
    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        requestDeposit(user1Assets / 2, user1.addr);

        updateAndSettle(0);
        deposit(user1Assets / 2, user1.addr);
    }

    function test_cancelRequestDeposit() public {
        uint256 assetsBeforeRequest = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(assetsBeforeRequest / 2, user1.addr);
        uint256 assetsBeforeCancel = assetBalance(user1.addr);

        assertEq(vault.pendingDepositRequest(requestId, user1.addr), assetsBeforeRequest / 2);
        assertEq(vault.pendingDepositRequest(0, user1.addr), assetsBeforeRequest / 2);
        assertEq(vault.claimableDepositRequest(requestId, user1.addr), 0);
        assertEq(vault.claimableDepositRequest(0, user1.addr), 0);

        vm.prank(user1.addr);
        vm.expectEmit(address(vault));
        emit DepositRequestCanceled(3, user1.addr);
        vault.cancelRequestDeposit();

        assertEq(vault.pendingDepositRequest(requestId, user1.addr), 0);
        assertEq(vault.pendingDepositRequest(0, user1.addr), 0);
        assertEq(vault.claimableDepositRequest(requestId, user1.addr), 0);
        assertEq(vault.claimableDepositRequest(0, user1.addr), 0);

        uint256 assetsAfterCancel = assetBalance(user1.addr);
        assertLt(assetsBeforeCancel, assetsAfterCancel);
        assertEq(assetsAfterCancel, assetsBeforeRequest);
    }

    function test_cancelRequestDeposit_when0PendingRequest() public {
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.cancelRequestDeposit();
        vm.stopPrank();
    }

    function test_cancelRequestDeposit_revertsWhenNewTotalAssetsHasBeenUpdated() public {
        uint256 assetsBeforeRequest = assetBalance(user1.addr);

        uint256 requestId = requestDeposit(assetsBeforeRequest / 2, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(RequestNotCancelable.selector, requestId));
        vault.cancelRequestDeposit();
    }

    function test_cancelRequestDeposit_whenNoRequestWereMade() public {
        vm.prank(user2.addr);
        vm.expectRevert(abi.encodeWithSelector(RequestNotCancelable.selector, 0));
        vault.cancelRequestDeposit();
    }

    function test_cancelRequestDeposit_whenRequestIsClaimable() public {
        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(RequestNotCancelable.selector, 1));
        vault.cancelRequestDeposit();
    }
}
