// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_deposit() public {
        uint256 userBalance = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 shares = deposit(userBalance, user1.addr);
        assertEq(vault.convertToShares(userBalance, requestId), shares);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
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

    function test_deposit_shouldRevertIfInvalidReceiver() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 totalSupplyBefore = vault.totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(user1.addr);
        vault.deposit(userBalance, address(0));
        uint256 totalSupplyAfter = vault.totalSupply();
        assertEq(totalSupplyBefore, totalSupplyAfter, "supply before != supply after");
    }

    function test_deposit_shouldTakeEntryFeesIntoConsideration() public {
        // we setup a vault with entry fees
        setUpVault({_protocolRate: 0, _managementRate: 0, _performanceRate: 0, _entryRate: 1000, _exitRate: 0});

        dealAndApproveAndWhitelist(user3.addr);

        requestDeposit(2000, user3.addr);
        updateAndSettle(0);
        deposit(2000, user3.addr);

        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);

        requestDeposit(800, user1.addr);
        requestDeposit(1000, user2.addr);

        // we settle deposits with a pps != 1:1 to complexify the situation
        updateAndSettle(2001);

        uint256 user1MaxDeposit = vault.maxDeposit(user1.addr);
        uint256 user2MaxDeposit = vault.maxDeposit(user2.addr);

        assertEq(user1MaxDeposit, 800);
        assertEq(user2MaxDeposit, 1000);

        uint256 user1MaxDepositSharesEquivalent = vault.convertToShares(user1MaxDeposit);
        uint256 user2MaxDepositSharesEquivalent = vault.convertToShares(user2MaxDeposit);

        assertEq(
            vault.maxMint(user1.addr),
            user1MaxDepositSharesEquivalent - FeeLib.computeFee(user1MaxDepositSharesEquivalent, vault.entryRate())
        );
        assertEq(
            vault.maxMint(user2.addr),
            user2MaxDepositSharesEquivalent - FeeLib.computeFee(user2MaxDepositSharesEquivalent, vault.entryRate())
        );

        // console.log();
        deposit(user1MaxDeposit, user1.addr);
        deposit(user2MaxDeposit, user2.addr);

        // they both have no more max deposit or mint
        assertEq(vault.maxMint(user1.addr), 0);
        assertEq(vault.maxMint(user2.addr), 0);
        assertEq(vault.maxDeposit(user1.addr), 0);
        assertEq(vault.maxDeposit(user2.addr), 0);

        // if all shares are claimed, the vault should have no balance
        assertEq(vault.balanceOf(address(vault)), 0); // this fails because of 1 wei, is it bad?
    }
}
