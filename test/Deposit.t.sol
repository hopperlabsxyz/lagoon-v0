// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC7540InvalidOperator, RequestIdNotClaimable} from "@src/ERC7540.sol";

import {BaseTest} from "./Base.sol";

contract TestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_deposit() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 shares = deposit(userBalance, user1.addr);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance);
    }

    function test_deposit_revertIfNotOperator() public {
        vm.prank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.deposit(42, user1.addr, user1.addr);
    }

    function test_deposit_revertIfRequestIdNotClaimable() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        vm.prank(user1.addr);
        vm.expectRevert(RequestIdNotClaimable.selector);
        vault.deposit(userBalance, user1.addr, user1.addr);
    }
}
