// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestWithdraw is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_withdraw() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        console.log("here");
        updateAndSettle(0);
        console.log("here2");
        assertEq(vault.maxDeposit(user1.addr), userBalance, "wrong max deposit");
        uint256 sharesObtained = deposit(userBalance, user1.addr);
        assertEq(sharesObtained, vault.balanceOf(user1.addr), "wrong amount of shares obtained");
        assertEq(sharesObtained, userBalance * 10 ** vault.decimalsOffset(), "wrong amount of shares obtained 2");
        requestRedeem(sharesObtained, user1.addr);

        assertEq(vault.claimableRedeemRequest(vault.redeemEpochId(), user1.addr), 0, "wrong claimable redeem amount");
        updateAndSettle(userBalance + 100);
        assertEq(vault.maxRedeem(user1.addr), sharesObtained, "user1 should be able to redeem all his shares");
        uint256 assetsToWithdraw = vault.convertToAssets(sharesObtained, vault.redeemEpochId() - 2);

        uint256 sharesTaken = withdraw(assetsToWithdraw, user1.addr);
        assertEq(assetsToWithdraw, assetBalance(user1.addr), "assetsToWithdraw should be equal to assetBalance");
        assertApproxEqAbs(
            sharesObtained - sharesTaken,
            vault.balanceOf(user1.addr),
            1 * 10 ** vault.decimalsOffset(),
            "sharesObtained - sharesTaken should be equal to balanceOf"
        );
        assertEq(vault.maxWithdraw(user1.addr), 0, "maxWithdraw should be 0");
        assertEq(vault.redeemEpochId(), 4, "redeemId should be 4");
        assertEq(
            vault.claimableRedeemRequest(vault.redeemEpochId(), user1.addr), 0, "claimableRedeemRequest should be 0"
        );
    }

    function test_withdraw_revertIfRequestIdNotClaimable() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance, "wrong max deposit");
        uint256 sharesObtained = deposit(userBalance, user1.addr);
        assertEq(sharesObtained, vault.balanceOf(user1.addr), "wrong shares obtained");
        assertEq(sharesObtained, userBalance * 10 ** vault.decimalsOffset(), "wrong shares obtained 2");
        requestRedeem(sharesObtained, user1.addr);

        assertEq(vault.claimableRedeemRequest(vault.redeemEpochId(), user1.addr), 0);
        uint256 assetsToWithdraw = vault.convertToAssets(sharesObtained, vault.redeemEpochId());

        vm.prank(user1.addr);
        vm.expectRevert(RequestIdNotClaimable.selector);
        vault.withdraw(assetsToWithdraw, user1.addr, user1.addr);
    }

    function test_withdraw_revertIfNotOperator() public {
        vm.prank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.withdraw(42, user1.addr, user1.addr);
    }
}
