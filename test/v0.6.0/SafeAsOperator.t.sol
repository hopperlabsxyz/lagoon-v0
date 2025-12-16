// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestSafeAsOperator is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);
        dealAndApproveAndWhitelist(user3.addr);
        dealAndApproveAndWhitelist(user4.addr);
        dealAndApproveAndWhitelist(user5.addr);
        dealAndApproveAndWhitelist(user6.addr);
    }

    function test_giveUpOperatorPrivileges() public {
        requestDeposit(100, user1.addr);
        updateAndSettle(0);

        vm.prank(safe.addr);
        vault.deposit(50, user2.addr, user1.addr);
        // we have been able to claim (call deposit) has an operator

        assertEq(vault.claimableDepositRequest(0, user1.addr), 50);
        assertEq(vault.balanceOf(user2.addr), 50 * 10 ** vault.decimalsOffset());

        // owner decides to give up this right
        assertFalse(vault.gaveUpOperatorPrivileges(), "gaveUpOperatorPrivileges should be false");
        vm.prank(vault.owner());
        vault.giveUpOperatorPrivileges();
        assertTrue(vault.gaveUpOperatorPrivileges(), "gaveUpOperatorPrivileges should be true");

        vm.startPrank(safe.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.deposit(50, user2.addr, user1.addr);
        vm.stopPrank();
    }

    function test_giveUpOperatorPrivileges_onlyOwner() public {
        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user1.addr));
        vault.giveUpOperatorPrivileges();
    }

    function test_SafeAsOperator() public {
        requestDeposit(100, user1.addr);
        updateAndSettle(0);

        assertEq(vault.claimableDepositRequest(0, user1.addr), 100);
        uint256 maxMint = vault.maxMint(user1.addr);
        vm.prank(safe.addr);
        vault.deposit(100, user2.addr, user1.addr);
        assertEq(vault.balanceOf(user2.addr), maxMint);
    }
}
