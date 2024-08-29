// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

contract TestWithdraw is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
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

        assertEq(vault.claimableRedeemRequest(vault.redeemId(), user1.addr), 0);
        updateAndSettle(userBalance + 100);
        assertEq(
            vault.maxRedeem(user1.addr),
            sharesObtained,
            "user1 should be able to redeem all his shares"
        );
        uint256 assetsToWithdraw = vault.convertToAssets(
            sharesObtained,
            vault.redeemId() - 2
        );

        uint256 sharesTaken = withdraw(assetsToWithdraw, user1.addr);
        assertEq(
            assetsToWithdraw,
            assetBalance(user1.addr),
            "assetsToWithdraw should be equal to assetBalance"
        );
        assertApproxEqAbs(
            sharesObtained - sharesTaken,
            vault.balanceOf(user1.addr),
            1,
            "sharesObtained - sharesTaken should be equal to balanceOf"
        );
        assertEq(vault.maxWithdraw(user1.addr), 0, "maxWithdraw should be 0");
        assertEq(vault.redeemId(), 4, "redeemId should be 4");
        assertEq(
            vault.claimableRedeemRequest(vault.redeemId(), user1.addr),
            0,
            "claimableRedeemRequest should be 0"
        );
    }
}
