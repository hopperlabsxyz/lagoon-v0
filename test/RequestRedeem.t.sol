// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OnlyOneRequestAllowed} from "@src/vault/ERC7540.sol";
import {Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";

contract TestRequestRedeem is BaseTest {
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

    function test_requestRedeem() public {
        uint256 userBalance = balance(user1.addr);
        uint256 requestId = requestRedeem(userBalance, user1.addr);
        assertEq(vault.pendingRedeemRequest(requestId, user1.addr), userBalance);
        assertEq(vault.pendingRedeemRequest(0, user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestRedeemTwoTimes() public {
        uint256 userBalance = balance(user1.addr);
        requestRedeem(userBalance / 2, user1.addr);
        requestRedeem(userBalance / 2, user1.addr);
        assertEq(vault.pendingRedeemRequest(vault.redeemEpochId(), user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestRedeem_notEnoughBalance() public {
        uint256 userBalance = balance(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.requestRedeem(userBalance + 1, user1.addr, user1.addr);
    }

    function test_requestRedeem_withClaimableBalance() public {
        uint256 userShareBalance = balance(user1.addr);
        requestRedeem(userShareBalance / 2, user1.addr);
        updateAndSettle(vault.totalAssets());
        assertEq(vault.claimableRedeemRequest(0, user1.addr), userShareBalance / 2, "wrong claimable redeem value");
        requestRedeem(balance(user1.addr), user1.addr);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0, "wrong claimable redeem value");
        assertEq(vault.pendingRedeemRequest(0, user1.addr), userShareBalance / 2, "wrong pending redeem value");
        assertEq(assetBalance(user1.addr) * 10 ** vault.decimalsOffset(), userShareBalance / 2, "wrong assets balance");
    }

    function test_requestRedeem_asAnOperator() public {
        address owner = user1.addr;
        address operator = user2.addr;
        address controller = user3.addr;
        uint256 ownerBalance = balance(owner);
        uint256 operatorBalance = balance(operator);
        uint256 controllerBalance = balance(controller);
        vm.prank(owner);
        vault.setOperator(operator, true);
        requestRedeem(ownerBalance, controller, owner, operator);
        assertEq(operatorBalance, balance(operator), "operator balance should not change");
        assertEq(controllerBalance, balance(controller), "controller balance should not change");
        assertEq(
            ownerBalance,
            vault.pendingRedeemRequest(0, controller),
            "owner former balance should be the controller pending Redeem request"
        );
        assertEq(balance(owner), 0, "owner balance should be 0");
    }

    function test_requestRedeem_asAnOperatorNotAllowed() public {
        address owner = user1.addr;
        address operator = user2.addr;
        address controller = user3.addr;
        uint256 ownerBalance = balance(owner);
        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, operator, 0, ownerBalance)
        );
        vault.requestRedeem(ownerBalance, controller, owner);
    }

    function test_requestRedeem_OnlyOneRequestAllowed() public {
        uint256 userBalance = balance(user1.addr);
        requestRedeem(userBalance / 2, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(OnlyOneRequestAllowed.selector);
        vault.requestRedeem(userBalance / 2, user1.addr, user1.addr);
    }

    function test_requestRedeem_updateClaimableDepositRequestAndPendingDepositRequest() public {
        // REQUEST REDEEM 1
        uint256 requestId_1 = requestRedeem(100 * 10 ** vault.decimals(), user1.addr);

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
        uint256 requestId_2 = requestRedeem(200 * 10 ** vault.decimals(), user1.addr);

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
        uint256 requestId_3 = requestRedeem(150 * 10 ** vault.decimals(), user1.addr);

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

    function test_requestRedeem_ShouldBeAbleToRequestRedeemAfterNAVUpdateAndClaimTheCorrectAmountOfAssets() public {
        uint256 amountToRedeem = vault.balanceOf(user1.addr);

        // user1 request redeem
        uint256 requestId_1 = requestRedeem(amountToRedeem, user1.addr);

        // Then the NAV commity commit a new NAV (defined to the amoun already deposited in the vault in setUp function)
        updateNewTotalAssets(2 * vault.convertToAssets(amountToRedeem));

        // user 1 is not able to cancel his request - The shares are still in the pending silo waiting for being
        // settled
        assertEq(vault.balanceOf(vault.pendingSilo()), amountToRedeem);

        // user2 request redeem
        uint256 requestId_2 = requestRedeem(amountToRedeem, user2.addr);

        // There is now 2 * amountToRedeem shares waiting in the pending silo to be settlled
        assertEq(vault.balanceOf(vault.pendingSilo()), 2 * amountToRedeem);

        // the asset manager settle the vault
        settleRedeem();

        // We expect the pending Silo to only send the assets of the first deposit and not the one from user2
        assertEq(vault.balanceOf(vault.pendingSilo()), amountToRedeem);
        assertEq(vault.claimableRedeemRequest(requestId_1, user1.addr), amountToRedeem);
        assertEq(vault.claimableRedeemRequest(requestId_2, user2.addr), 0);

        // now we update settle the vault again and we expect user2's deposit to be deposited into the vault
        updateAndSettle(vault.convertToAssets(amountToRedeem));

        assertEq(vault.claimableRedeemRequest(requestId_1, user1.addr), amountToRedeem);
        assertEq(vault.claimableRedeemRequest(requestId_2, user2.addr), amountToRedeem);

        redeem(amountToRedeem, user1.addr);
        redeem(amountToRedeem, user2.addr);

        assertEq(assetBalance(user1.addr), vault.convertToAssets(amountToRedeem));
        assertEq(assetBalance(user2.addr), vault.convertToAssets(amountToRedeem));
    }
}
