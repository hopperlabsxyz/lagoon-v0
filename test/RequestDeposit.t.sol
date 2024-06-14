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
        requestDeposit(user1.addr, userBalance);
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
    }

    function test_requestDepositTwoTimes() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(user1.addr, userBalance / 2);
        requestDeposit(user1.addr, userBalance / 2);
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
    }

    function test_requestDeposit_notEnoughBalance() public {
        uint256 userBalance = assetBalance(user1.addr);
        vm.expectRevert();
        requestDeposit(user1.addr, userBalance + 1);
    }
}
