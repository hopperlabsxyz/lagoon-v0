// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestRequestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
    }

    function test_requestDeposit() public {
        uint256 userBalance = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(userBalance, user1.addr);
        assertEq(vault.pendingDepositRequest(requestId, user1.addr), userBalance);
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDeposit_with_eth() public {
        uint256 userBalance = 10e18;

        if (!underlyingIsNativeToken) {
            vm.startPrank(user1.addr);
            vm.expectRevert(CantDepositNativeToken.selector);
            vault.requestDeposit{value: 1}(userBalance, user1.addr, user1.addr);
            vm.stopPrank();

            setUpVault(0, 0, 0);
            whitelist(user1.addr);
        } else {
            requestDeposit(userBalance, user1.addr, true);
            assertEq(assetBalance(address(vault)), 0);
            assertEq(assetBalance(address(vault.pendingSilo())), userBalance);
            assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
            assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
        }
    }

    function test_requestDeposit_with_eth_and_wrong_userBalance() public {
        uint256 userBalance = 10e18;

        if (underlyingIsNativeToken) {
            vm.startPrank(user1.addr);
            uint256 requestId = vault.requestDeposit{value: userBalance}(0, user1.addr, user1.addr);
            console.log("requestId", requestId);
            vm.stopPrank();

            assertEq(assetBalance(address(vault)), 0);
            assertEq(assetBalance(address(vault.pendingSilo())), userBalance);
            assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
            assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
        }
    }

    function test_requestDepositTwoTimes() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        assertEq(vault.pendingDepositRequest(vault.depositEpochId(), user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDeposit_notEnoughBalance() public {
        uint256 userBalance = assetBalance(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.requestDeposit(userBalance + 1, user1.addr, user1.addr);
    }

    function test_requestDeposit_withClaimableBalance() public {
        uint256 userBalance = assetBalance(user1.addr);

        uint256 requestId_1 = requestDeposit(userBalance / 2, user1.addr);

        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), userBalance / 2);

        updateAndSettle(0);

        assertEq(requestId_1 + 2, vault.depositEpochId(), "wrong deposit id");
        assertEq(
            vault.lastDepositRequestId_debug(user1.addr), // keep track of the last deposit id of the user, only one
                // requestId is allowed by settle period by user
            requestId_1,
            "wrong internal lastDepositRequestId"
        );
        assertEq(vault.lastDepositEpochIdSettled_debug(), requestId_1, "wrong internal lastDepositTotalAssetsIdSettle");

        assertEq(vault.maxDeposit(user1.addr), userBalance / 2, "wrong claimable deposit value");

        assertEq(
            vault.balanceOf(address(vault)),
            (userBalance * 10 ** vault.decimalsOffset()) / 2,
            "wrong amount of claimable shares"
        );

        uint256 requestId_2 = requestDeposit(userBalance / 2, user1.addr);

        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), 0);
        assertEq(vault.pendingDepositRequest(requestId_2, user1.addr), userBalance / 2);

        assertEq(vault.maxDeposit(user1.addr), 0, "wrong claimable deposit value");
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance / 2, "wrong pending deposit value");

        // we automatically claim for the user if he has claimable shares
        assertEq(vault.balanceOf(user1.addr), (userBalance * 10 ** vault.decimalsOffset()) / 2, "wrong shares balance");
    }

    // @dev Once one of the request of the user has been taken into a TotalAssets
    //      he has to wait for settlement before being able to request again
    function test_only_one_request_allowed_per_settle_id() public {
        uint256 userBalance = assetBalance(user1.addr);

        requestDeposit(userBalance / 2, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(OnlyOneRequestAllowed.selector);
        vault.requestDeposit(userBalance / 2, user1.addr, user1.addr);
    }

    function test_requestDeposit_withClaimableBalance_with_eth() public {
        uint256 userBalance = 10e18;

        if (underlyingIsNativeToken) {
            requestDeposit(userBalance / 2, user1.addr);
            updateAndSettle(0);
            assertEq(vault.maxDeposit(user1.addr), userBalance / 2, "wrong claimable deposit value");
            requestDeposit(userBalance / 2, user1.addr, true);
            assertEq(vault.maxDeposit(user1.addr), 0, "wrong claimable deposit value");
            assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance / 2, "wrong pending deposit value");
            assertEq(vault.balanceOf(user1.addr), userBalance / 2, "wrong shares balance");
        }
    }

    function test_requestDeposit_asAnOperator() public {
        address owner = user1.addr;
        address operator = user2.addr;
        address controller = user3.addr;

        uint256 ownerBalance = assetBalance(owner);
        uint256 operatorBalance = assetBalance(operator);
        uint256 controllerBalance = assetBalance(controller);
        vm.prank(owner);
        vault.setOperator(operator, true);
        requestDeposit(ownerBalance, controller, owner, operator);
        assertEq(operatorBalance, assetBalance(operator), "operator balance should not change");
        assertEq(controllerBalance, assetBalance(controller), "controller balance should not change");
        assertEq(
            ownerBalance,
            vault.pendingDepositRequest(0, controller),
            "owner balance should be the controller pending deposit request"
        );
        assertEq(assetBalance(owner), 0, "owner balance should be 0");
    }

    function test_requestDeposit_asAnOperatorNotAllowed() public {
        address owner = user1.addr;
        address operator = user2.addr;
        address controller = user3.addr;
        uint256 ownerBalance = assetBalance(owner);
        vm.startPrank(operator);
        vm.expectRevert();
        vault.requestDeposit(ownerBalance, controller, owner);
    }

    function test_requestDeposit_asAnOperatorButOwnerNotEnoughApprove() public {
        address owner = user2.addr;
        address operator = user1.addr;
        address controller = user3.addr;
        uint256 ownerBalance = assetBalance(owner);
        vm.prank(owner);
        vault.setOperator(operator, true);
        vm.startPrank(operator);
        // vm.expectRevert();
        vault.requestDeposit(ownerBalance, controller, owner);
    }

    function test_requestDeposit_revertIfNotOperator() public {
        vm.prank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.requestDeposit(42, user1.addr, user1.addr);
    }

    function test_requestDeposit_ShouldBeAbleToDepositAgainWhenIndeterminationIsRaidedAtSettlement() public {
        vm.prank(user1.addr);
        vault.requestDeposit(42, user1.addr, user1.addr);

        vm.prank(user1.addr);
        vault.requestDeposit(42, user1.addr, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(OnlyOneRequestAllowed.selector);
        vault.requestDeposit(42, user1.addr, user1.addr);

        settle();

        vm.prank(user1.addr);
        vault.requestDeposit(42, user1.addr, user1.addr);
    }

    function test_requestDeposit_updateClaimableDepositRequest() public {
        // REQUEST DEPOSIT 1
        uint256 requestId_1 = requestDeposit(100, user1.addr);

        // pendings
        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), 100, "[0 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingDepositRequest(0, user1.addr), 100, "[0 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableDepositRequest(requestId_1, user1.addr), 0, "[0 - claimable - requestId 1]: wrong amount"
        );
        assertEq(vault.claimableDepositRequest(0, user1.addr), 0, "[0 - claimable - requestId 0]: wrong amount");

        /// ------------------ settlement ------------------ ///
        updateAndSettle(0);

        // pendings
        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), 0, "[1 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingDepositRequest(0, user1.addr), 0, "[1 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableDepositRequest(requestId_1, user1.addr), 100, "[1 - claimable - requestId 1]: wrong amount"
        );
        assertEq(vault.claimableDepositRequest(0, user1.addr), 100, "[1 - claimable - requestId 0]: wrong amount");

        // REQUEST DEPOSIT 2
        uint256 requestId_2 = requestDeposit(200, user1.addr);

        // pendings
        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), 0, "[2 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingDepositRequest(requestId_2, user1.addr), 200, "[2 - pending - requestId 2]: wrong amount");
        assertEq(vault.pendingDepositRequest(0, user1.addr), 200, "[2 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableDepositRequest(requestId_1, user1.addr), 0, "[2 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableDepositRequest(requestId_2, user1.addr), 0, "[2 - claimable - requestId 2]: wrong amount"
        );
        assertEq(vault.claimableDepositRequest(0, user1.addr), 0, "[2 - claimable - requestId 0]: wrong amount");

        /// ------------------ settlement ------------------ ///
        updateAndSettle(100);

        // pendings
        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), 0, "[3 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingDepositRequest(requestId_2, user1.addr), 0, "[3 - pending - requestId 2]: wrong amount");
        assertEq(vault.pendingDepositRequest(0, user1.addr), 0, "[3 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableDepositRequest(requestId_1, user1.addr), 0, "[3 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableDepositRequest(requestId_2, user1.addr), 200, "[3 - claimable - requestId 2]: wrong amount"
        );
        assertEq(vault.claimableDepositRequest(0, user1.addr), 200, "[3 - claimable - requestId 0]: wrong amount");

        // REQUEST DEPOSIT 3
        uint256 requestId_3 = requestDeposit(150, user1.addr);

        // pendings
        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), 0, "[4 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingDepositRequest(requestId_2, user1.addr), 0, "[4 - pending - requestId 2]: wrong amount");
        assertEq(vault.pendingDepositRequest(requestId_3, user1.addr), 150, "[4 - pending - requestId 3]: wrong amount");
        assertEq(vault.pendingDepositRequest(0, user1.addr), 150, "[4 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableDepositRequest(requestId_1, user1.addr), 0, "[4 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableDepositRequest(requestId_2, user1.addr), 0, "[4 - claimable - requestId 2]: wrong amount"
        );
        assertEq(
            vault.claimableDepositRequest(requestId_3, user1.addr), 0, "[4 - claimable - requestId 3]: wrong amount"
        );
        assertEq(vault.claimableDepositRequest(0, user1.addr), 0, "[4 - claimable - requestId 0]: wrong amount");

        /// ------------------ settlement ------------------ ///
        updateAndSettle(100);

        // pendings
        assertEq(vault.pendingDepositRequest(requestId_1, user1.addr), 0, "[5 - pending - requestId 1]: wrong amount");
        assertEq(vault.pendingDepositRequest(requestId_2, user1.addr), 0, "[5 - pending - requestId 2]: wrong amount");
        assertEq(vault.pendingDepositRequest(requestId_3, user1.addr), 0, "[5 - pending - requestId 3]: wrong amount");
        assertEq(vault.pendingDepositRequest(0, user1.addr), 0, "[5 - pending - requestId 0]: wrong amount");

        // claimables
        assertEq(
            vault.claimableDepositRequest(requestId_1, user1.addr), 0, "[5 - claimable - requestId 1]: wrong amount"
        );
        assertEq(
            vault.claimableDepositRequest(requestId_2, user1.addr), 0, "[5 - claimable - requestId 2]: wrong amount"
        );
        assertEq(
            vault.claimableDepositRequest(requestId_3, user1.addr), 150, "[5 - claimable - requestId 3]: wrong amount"
        );
        assertEq(vault.claimableDepositRequest(0, user1.addr), 150, "[5 - claimable - requestId 0]: wrong amount");
    }

    function test_requestDeposit_ShouldBeAbleToRequestDepositAfterNAVUpdateAndClaimTheCorrectAmountOfShares() public {
        // first: User 1 make a request deposit
        uint256 amountToDeposit = 10 * 10 ** vault.underlyingDecimals();
        vm.prank(user1.addr);
        uint256 requestId_1 = vault.requestDeposit(amountToDeposit, user1.addr, user1.addr);
        assertEq(requestId_1, 1);

        // The request amount is now inside the pending silo wainting for Nav update and then settlement

        // Then the NAV commity commit a new NAV
        updateNewTotalAssets(0);

        // Now user 1 is not able to cancel his request - The assets are still in the pending silo waiting for being
        // settle
        assertEq(assetBalance(vault.pendingSilo()), amountToDeposit);

        // second: User 2 make an other request deposit
        vm.prank(user2.addr);
        uint256 requestId_2 = vault.requestDeposit(amountToDeposit, user2.addr, user2.addr);
        assertEq(requestId_2, 3);

        // Now the pendingSilo olds the two deposits
        assertEq(assetBalance(vault.pendingSilo()), 2 * amountToDeposit);

        // the asset manager settle the vault
        settle();

        // We expect the pending Silo to only send the assets of the first deposit and not the one from user2
        assertEq(assetBalance(vault.pendingSilo()), amountToDeposit);

        assertEq(vault.claimableDepositRequest(requestId_1, user1.addr), amountToDeposit);
        assertEq(vault.claimableDepositRequest(requestId_2, user2.addr), 0);

        // now we update settle the vault again and we expect user2's deposit to be deposited into the vault
        updateAndSettle(amountToDeposit);

        assertEq(vault.claimableDepositRequest(requestId_1, user1.addr), amountToDeposit);
        assertEq(vault.claimableDepositRequest(requestId_2, user2.addr), amountToDeposit);
    }

    function test_requestDeposit_shouldBeCancelableAfterSettlementWhenRequestIsMadeDuringTheCurrentEpoch() public {
        // first: User 1 make a request deposit
        uint256 amountToDeposit = 10 * 10 ** vault.underlyingDecimals();
        vm.prank(user1.addr);
        uint256 requestId_1 = vault.requestDeposit(amountToDeposit, user1.addr, user1.addr);
        assertEq(requestId_1, 1);

        // The request amount is now inside the pending silo wainting for Nav update and then settlement

        // Then the NAV commity commit a new NAV
        updateNewTotalAssets(0);

        // Now user 1 is not able to cancel his request - The assets are still in the pending silo waiting for being
        // settle
        assertEq(assetBalance(vault.pendingSilo()), amountToDeposit);

        // second: User 2 make an other request deposit
        vm.prank(user2.addr);
        uint256 requestId_2 = vault.requestDeposit(amountToDeposit, user2.addr, user2.addr);
        assertEq(requestId_2, 3);

        // Now the pendingSilo olds the two deposits
        assertEq(assetBalance(vault.pendingSilo()), 2 * amountToDeposit);

        // the asset manager settle the vault
        settle();

        // We expect the pending Silo to only send the assets of the first deposit and not the one from user2
        assertEq(assetBalance(vault.pendingSilo()), amountToDeposit);

        uint256 assetBefore = assetBalance(user2.addr);

        // now the request from user2 should still be cancelable and he can get his deposit back since no update total
        // assets has been made
        vm.prank(user2.addr);
        vault.cancelRequestDeposit();

        // the pendingSilo should now be empty
        assertEq(assetBalance(vault.pendingSilo()), 0);

        uint256 assetAfter = assetBalance(user2.addr);

        // and user2 get his money back
        assertEq(assetAfter - assetBefore, amountToDeposit);
    }
}
