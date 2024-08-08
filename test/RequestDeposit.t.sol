// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";

contract TestRequestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
    }

    function test_requestDeposit() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDepositTwoTimes() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        assertEq(
            vault.pendingDepositRequest(vault.depositId(), user1.addr),
            userBalance
        );
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDeposit_notEnoughBalance() public {
        uint256 userBalance = assetBalance(user1.addr);
        vm.expectRevert();
        requestDeposit(userBalance + 1, user1.addr);
    }

    function test_requestDeposit_withClaimableBalance() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        updateAndSettle(0);
        assertEq(
            vault.maxDeposit(user1.addr),
            userBalance / 2,
            "wrong claimable deposit value"
        );
        requestDeposit(userBalance / 2, user1.addr);
        assertEq(
            vault.maxDeposit(user1.addr),
            0,
            "wrong claimable deposit value"
        );
        assertEq(
            vault.pendingDepositRequest(0, user1.addr),
            userBalance / 2,
            "wrong pending deposit value"
        );
        assertEq(
            vault.balanceOf(user1.addr),
            userBalance / 2,
            "wrong shares balance"
        );
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
        assertEq(
            operatorBalance,
            assetBalance(operator),
            "operator balance should not change"
        );
        assertEq(
            controllerBalance,
            assetBalance(controller),
            "controller balance should not change"
        );
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
        vm.expectRevert();
        requestDeposit(ownerBalance, controller, owner, operator);
    }

    function test_requestDeposit_asAnOperatorButOwnerNotEnoughApprove() public {
        address owner = user2.addr;
        address operator = user1.addr;
        address controller = user3.addr;
        uint256 ownerBalance = assetBalance(owner);
        vm.prank(owner);
        vault.setOperator(operator, true);
        vm.expectRevert();
        requestDeposit(ownerBalance, controller, owner, operator);
    }
}
