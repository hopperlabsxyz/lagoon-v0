// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, IERC20} from "@src/Vault.sol";
import {BaseTest} from "./Base.t.sol";

contract TestRequestDeposit is BaseTest {
    function setUp() public {
        dealAndApprove(user1.addr);
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
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
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
        settle(0);
        assertEq(
            vault.claimableDepositRequest(0, user1.addr),
            userBalance / 2,
            "wrong claimable deposit value"
        );
        requestDeposit(userBalance / 2, user1.addr);
        assertEq(
            vault.claimableDepositRequest(0, user1.addr),
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
}
