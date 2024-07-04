// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

contract TestWithdraw is BaseTest {
    function setUp() public {
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_withdraw() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 sharesObtained = deposit(userBalance, user1.addr);
        assertEq(sharesObtained, vault.balanceOf(user1.addr));
        assertEq(sharesObtained, userBalance);
        requestRedeem(sharesObtained, user1.addr);
        assertEq(vault.claimableRedeemRequest(vault.epochId(), user1.addr), 0);

        updateAndSettle(userBalance + 100);
        assertEq(vault.maxRedeem(user1.addr), sharesObtained);
        uint256 assetsToWithdraw = vault.convertToAssets(
            sharesObtained,
            vault.epochId() - 1
        );
        uint256 sharesGiven = withdraw(assetsToWithdraw, user1.addr);
        assertEq(assetsToWithdraw, assetBalance(user1.addr));
        assertEq(sharesGiven, vault.balanceOf(user1.addr));
        assertEq(vault.maxWithdraw(user1.addr), 0);
        assertEq(vault.epochId(), 3);
        assertEq(vault.claimableRedeemRequest(vault.epochId(), user1.addr), 0);
    }
}
