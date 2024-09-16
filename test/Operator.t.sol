// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";

contract TestOperator is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        requestDeposit(user1Assets / 2, user1.addr);

        updateAndSettle(0);
        deposit(user1Assets / 2, user1.addr);
    }

    function test_addOperator() public {
        bool isOpBefore = vault.isOperator(user1.addr, user2.addr);
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);
        assertFalse(isOpBefore, "isOperator should be false");
        assertTrue(
            vault.isOperator(user1.addr, user2.addr),
            "isOperator should be true"
        );
    }

    function test_addOperatorwhenOpIsAlreadyOp() public {
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);
        bool isOpBefore = vault.isOperator(user1.addr, user2.addr);
        assertTrue(isOpBefore, "isOperator should be true");
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);
        assertTrue(
            vault.isOperator(user1.addr, user2.addr),
            "isOperator should be true"
        );
    }

    function test_rmvOperator() public {
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);
        bool isOpBefore = vault.isOperator(user1.addr, user2.addr);
        assertTrue(isOpBefore, "isOperator should be true");
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, false);
        assertFalse(
            vault.isOperator(user1.addr, user2.addr),
            "isOperator should be false"
        );
    }

    function test_rmvOperatorWhenAddressIsNotOperator() public {
        bool isOpBefore = vault.isOperator(user1.addr, user2.addr);
        assertFalse(isOpBefore, "isOperator should be false");
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, false);
        assertFalse(
            vault.isOperator(user1.addr, user2.addr),
            "isOperator should be false"
        );
    }
}
