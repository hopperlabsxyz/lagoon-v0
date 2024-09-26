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
        uint256 balance = assetBalance(user1.addr);
        requestDeposit(balance, user1.addr);
        updateAndSettle(0);
        deposit(balance, user1.addr);
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
        assertEq(vault.pendingRedeemRequest(vault.redeemId(), user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestRedeem_notEnoughBalance() public {
        uint256 userBalance = balance(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.requestRedeem(userBalance + 1, user1.addr, user1.addr);
    }

    function test_requestRedeem_withClaimableBalance() public {
        uint256 userBalance = balance(user1.addr);
        requestRedeem(userBalance / 2, user1.addr);
        updateAndSettle(vault.totalAssets());
        assertEq(vault.claimableRedeemRequest(0, user1.addr), userBalance / 2, "wrong claimable redeem value");
        requestRedeem(balance(user1.addr), user1.addr);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0, "wrong claimable redeem value");
        assertEq(vault.pendingRedeemRequest(0, user1.addr), userBalance / 2, "wrong pending redeem value");
        assertEq(assetBalance(user1.addr), userBalance / 2, "wrong assets balance");
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
}
