// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, IERC20} from "@src/Vault.sol";
import {BaseTest} from "./Base.t.sol";

contract TestRequestDeposit is BaseTest {
    function setUp() public {
        dealAndApprove(user1.addr);
    }

    function test_deposit() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        settle(0);
        assertEq(vault.claimableDepositRequest(0, user1.addr), userBalance);
        uint256 shares = deposit(userBalance, user1.addr);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance);
    }
}
