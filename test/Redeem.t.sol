// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC7540InvalidOperator, RequestIdNotClaimable} from "@src/vault0.2.0/ERC7540.sol";
import {Vault0_2_1} from "@src/vault0.2.1/Vault0.2.1.sol";
import "forge-std/Test.sol";

contract TestRedeem is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_redeem() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 shares = deposit(userBalance, user1.addr);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
        requestRedeem(shares, user1.addr);
        assertEq(vault.claimableRedeemRequest(vault.redeemEpochId(), user1.addr), 0);

        updateAndSettle(userBalance + 100);
        assertEq(vault.maxRedeem(user1.addr), shares);
        uint256 assets = redeem(shares, user1.addr);
        assertEq(assets, assetBalance(user1.addr));
        assertEq(vault.maxRedeem(user1.addr), 0);
        assertEq(vault.redeemEpochId(), 4);
        assertEq(vault.claimableRedeemRequest(vault.redeemEpochId(), user1.addr), 0);
    }

    function test_redeem_whenNotOperatorShouldRevert() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 shares = deposit(userBalance, user1.addr);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
        requestRedeem(shares, user1.addr);
        updateAndSettle(userBalance);

        // here user 2 pretends to be an operator of user1.addr
        vm.startPrank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.redeem(shares, user2.addr, user1.addr);
    }

    function test_redeem_whenOperator() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 shares = deposit(userBalance, user1.addr);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
        requestRedeem(shares, user1.addr);
        updateAndSettle(userBalance);

        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);

        redeem(shares, user1.addr, user2.addr, user2.addr);
    }

    function test_redeem_revertIfRequestIdNotClaimable() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 shares = deposit(userBalance, user1.addr);
        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
        requestRedeem(shares, user1.addr);
        assertEq(vault.claimableRedeemRequest(vault.redeemEpochId(), user1.addr), 0);

        vm.prank(user1.addr);
        vm.expectRevert(RequestIdNotClaimable.selector);
        vault.redeem(shares, user1.addr, user1.addr);
    }
}
