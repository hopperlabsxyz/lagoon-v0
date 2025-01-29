// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC7540InvalidOperator, RequestIdNotClaimable} from "@src/vault0.1/ERC7540.sol";
import {OnlyOneRequestAllowed} from "@src/vault0.1/ERC7540.sol";
import {Vault} from "@src/vault0.1/Vault.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";

contract TestDeposit is BaseTest {
    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        uint256 balance = assetBalance(user1.addr);
        requestDeposit(balance, user1.addr);
        requestDeposit(balance, user2.addr);
        updateAndSettle(0);
        deposit(balance, user1.addr);
        deposit(balance, user2.addr);
    }

    function test_claimSharesAndRequestRedeem_allPossibleShares() public {
        dealAndApprove(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(vault.totalAssets());
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 claimableShares = vault.maxMint(user1.addr);

        uint256 sharesBefore = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        vault.claimSharesAndRequestRedeem(sharesBefore + claimableShares);
        uint256 shares = vault.balanceOf(user1.addr);
        assertEq(0, shares);
    }

    function test_claimSharesAndRequestRedeem_almostAllPossibleShares() public {
        dealAndApprove(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(vault.totalAssets());
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 claimableShares = vault.maxMint(user1.addr);

        uint256 sharesBefore = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        uint256 maxSharesToRequest = sharesBefore + claimableShares;
        vault.claimSharesAndRequestRedeem(maxSharesToRequest - 5);
        uint256 shares = vault.balanceOf(user1.addr);
        assertEq(5, shares);
    }

    function test_claimSharesAndRequestRedeem_moreThanAllPossibleShares() public {
        dealAndApprove(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(vault.totalAssets());
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 claimableShares = vault.maxMint(user1.addr);

        uint256 sharesBefore = vault.balanceOf(user1.addr);
        uint256 maxSharesToRequest = sharesBefore + claimableShares;
        vm.prank(user1.addr);
        vm.expectRevert();
        vault.claimSharesAndRequestRedeem(maxSharesToRequest + 1);
    }

    function test_claimSharesAndRequestRedeemWithZeroInInput() public {
        uint256 sharesBefore = vault.balanceOf(user1.addr);
        dealAndApprove(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(userBalance, user1.addr);
        updateAndSettle(vault.totalAssets());
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        vm.prank(user1.addr);
        vault.claimSharesAndRequestRedeem(0);
        uint256 shares = vault.balanceOf(user1.addr);
        assertEq(vault.convertToShares(userBalance, requestId) + sharesBefore, shares);
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset() + sharesBefore);
    }

    function test_claimSharesAndRedeem_IfRequestIdNotClaimableShouldIgnore() public {
        dealAndApprove(user1.addr);
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        vm.prank(user1.addr);
        vault.claimSharesAndRequestRedeem(userBalance);
    }

    function test_claimSharesAndRequestRedeem() public {
        uint256 userBalance = balance(user1.addr);
        vm.prank(user1.addr);
        uint256 requestId = vault.claimSharesAndRequestRedeem(userBalance);
        assertEq(vault.pendingRedeemRequest(requestId, user1.addr), userBalance);
        assertEq(vault.pendingRedeemRequest(0, user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_claimSharesAndRequestRedeemTwoTimes() public {
        uint256 userBalance = balance(user1.addr);
        vm.prank(user1.addr);
        vault.claimSharesAndRequestRedeem(userBalance / 2);
        vm.prank(user1.addr);
        vault.claimSharesAndRequestRedeem(userBalance / 2);
        assertEq(vault.pendingRedeemRequest(vault.redeemEpochId(), user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_claimSharesAndRequestRedeem_notEnoughBalance() public {
        uint256 userBalance = balance(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.claimSharesAndRequestRedeem(userBalance + 1);
    }

    function test_claimSharesAndRequestRedeem_withClaimableBalance() public {
        uint256 userShareBalance = balance(user1.addr);
        vm.prank(user1.addr);
        vault.claimSharesAndRequestRedeem(userShareBalance / 2);
        updateAndSettle(vault.totalAssets());
        assertEq(vault.claimableRedeemRequest(0, user1.addr), userShareBalance / 2, "wrong claimable redeem value");
        vm.startPrank(user1.addr);
        vault.claimSharesAndRequestRedeem(balance(user1.addr));
        vm.stopPrank();
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0, "wrong claimable redeem value");
        assertEq(vault.pendingRedeemRequest(0, user1.addr), userShareBalance / 2, "wrong pending redeem value");
        assertEq(assetBalance(user1.addr) * 10 ** vault.decimalsOffset(), userShareBalance / 2, "wrong assets balance");
    }

    function test_claimSharesAndRequestRedeem_OnlyOneRequestAllowed() public {
        uint256 userBalance = balance(user1.addr);
        requestRedeem(userBalance / 2, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(OnlyOneRequestAllowed.selector);
        vault.claimSharesAndRequestRedeem(userBalance);
    }

    function test_requestRedeem_updateClaimableDepositRequestAndPendingDepositRequest() public {
        // REQUEST REDEEM 1
        vm.startPrank(user1.addr);
        uint256 requestId_1 = vault.claimSharesAndRequestRedeem(100 * 10 ** vault.decimals());
        vm.stopPrank();

        // pendings
        assertEq(
            vault.pendingRedeemRequest(requestId_1, user1.addr),
            100 * 10 ** vault.decimals(),
            "[0 - pending - requestId 1]: wrong amount"
        );
        assertEq(
            vault.pendingRedeemRequest(0, user1.addr),
            100 * 10 ** vault.decimals(),
            "[0 - pending - requestId 0]: wrong amount"
        );

        // claimables
        assertEq(
            vault.claimableRedeemRequest(requestId_1, user1.addr), 0, "[0 - claimable - requestId 1]: wrong amount"
        );
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0, "[0 - claimable - requestId 0]: wrong amount");

        /// ------------------ settlement ------------------ ///

        updateAndSettle(assetBalance(vault.safe()));

        // pendings
        assertEq(vault.pendingRedeemRequest(requestId_1, user1.addr), 0, "[1 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingRedeemRequest(0, user1.addr), 0, "[1 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableRedeemRequest(requestId_1, user1.addr),
            100 * 10 ** vault.decimals(),
            "[1 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(0, user1.addr),
            100 * 10 ** vault.decimals(),
            "[1 - claimable - requestId 0]: wrong amount"
        );

        // REQUEST REDEEM 2
        vm.startPrank(user1.addr);
        uint256 requestId_2 = vault.claimSharesAndRequestRedeem(200 * 10 ** vault.decimals());
        vm.stopPrank();
        // pendings
        assertEq(vault.pendingRedeemRequest(requestId_1, user1.addr), 0, "[2 - pending - requestId 1]: wrong amount");
        assertEq(
            vault.pendingRedeemRequest(requestId_2, user1.addr),
            200 * 10 ** vault.decimals(),
            "[2 - pending - requestId 2]: wrong amount"
        );
        assertEq(
            vault.pendingRedeemRequest(0, user1.addr),
            200 * 10 ** vault.decimals(),
            "[2 - pending - requestId 0]: wrong amount"
        );

        // claimables
        assertEq(
            vault.claimableRedeemRequest(requestId_1, user1.addr), 0, "[2 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(requestId_2, user1.addr), 0, "[2 - claimable - requestId 2]: wrong amount"
        );
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0, "[2 - claimable - requestId 0]: wrong amount");

        /// ------------------ settlement ------------------ ///
        updateAndSettle(assetBalance(vault.safe()));

        // pendings
        assertEq(vault.pendingRedeemRequest(requestId_1, user1.addr), 0, "[3 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingRedeemRequest(requestId_2, user1.addr), 0, "[3 - pending - requestId 2]: wrong amount");
        assertEq(vault.pendingRedeemRequest(0, user1.addr), 0, "[3 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableRedeemRequest(requestId_1, user1.addr), 0, "[3 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(requestId_2, user1.addr),
            200 * 10 ** vault.decimals(),
            "[3 - claimable - requestId 2]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(0, user1.addr),
            200 * 10 ** vault.decimals(),
            "[3 - claimable - requestId 0]: wrong amount"
        );

        // REQUEST REDEEM 3
        vm.startPrank(user1.addr);
        uint256 requestId_3 = vault.claimSharesAndRequestRedeem(150 * 10 ** vault.decimals());
        vm.stopPrank();

        // pendings
        assertEq(vault.pendingRedeemRequest(requestId_1, user1.addr), 0, "[4 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingRedeemRequest(requestId_2, user1.addr), 0, "[4 - pending - requestId 2]: wrong amount");
        assertEq(
            vault.pendingRedeemRequest(requestId_3, user1.addr),
            150 * 10 ** vault.decimals(),
            "[4 - pending - requestId 3]: wrong amount"
        );
        assertEq(
            vault.pendingRedeemRequest(0, user1.addr),
            150 * 10 ** vault.decimals(),
            "[4 - pending - requestId 0]: wrong amount"
        );

        // claimables
        assertEq(
            vault.claimableRedeemRequest(requestId_1, user1.addr), 0, "[4 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(requestId_2, user1.addr), 0, "[4 - claimable - requestId 2]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(requestId_3, user1.addr), 0, "[4 - claimable - requestId 3]: wrong amount"
        );
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0, "[4 - claimable - requestId 0]: wrong amount");

        // /// ------------------ settlement ------------------ ///
        uint256 assetBalance = assetBalance(vault.safe());
        updateAndSettle(assetBalance);

        // pendings
        assertEq(vault.pendingRedeemRequest(requestId_1, user1.addr), 0, "[5 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingRedeemRequest(requestId_2, user1.addr), 0, "[5 - pending - requestId 2]: wrong amount");
        assertEq(vault.pendingRedeemRequest(requestId_3, user1.addr), 0, "[5 - pending - requestId 3]: wrong amount");
        assertEq(vault.pendingRedeemRequest(0, user1.addr), 0, "[5 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableRedeemRequest(requestId_1, user1.addr), 0, "[5 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(requestId_2, user1.addr), 0, "[5 - claimable - requestId 2]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(requestId_3, user1.addr),
            150 * 10 ** vault.decimals(),
            "[5 - claimable - requestId 3]: wrong amount"
        );
        assertEq(
            vault.claimableRedeemRequest(0, user1.addr),
            150 * 10 ** vault.decimals(),
            "[5 - claimable - requestId 0]: wrong amount"
        );
    }
}
