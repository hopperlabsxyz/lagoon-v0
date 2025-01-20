// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC7540InvalidOperator, RequestIdNotClaimable} from "@src/vault/ERC7540.sol";
import {Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";

contract TestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_claimSharesAndRequestRedeemWithZeroInInput() public {
        uint256 userBalance = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        vm.prank(user1.addr);
        vault.claimSharesAndRequestRedeem(0);
        uint256 shares = vault.balanceOf(user1.addr);
        assertEq(vault.convertToShares(userBalance, requestId), shares, "shares is not equal to ");
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
    }

    function test_claimSharesAndRedeem_revertIfRequestIdNotClaimable() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        vm.prank(user1.addr);
        vm.expectRevert(RequestIdNotClaimable.selector);
        vault.claimSharesAndRequestRedeem(userBalance);
    }
}
