// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

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
        assertEq(shares, userBalance);
        requestRedeem(shares, user1.addr);
        assertEq(vault.claimableRedeemRequest(vault.epochId(), user1.addr), 0);

        updateAndSettle(userBalance + 100);
        unwind();
        assertApproxEqAbs(vault.maxRedeem(user1.addr), shares, 1);
        uint256 assets = redeem(shares, user1.addr);
        assertEq(assets, assetBalance(user1.addr));
        assertEq(vault.maxRedeem(user1.addr), 0);
        assertEq(vault.epochId(), 3);
        assertEq(vault.claimableRedeemRequest(vault.epochId(), user1.addr), 0);
    }
}
