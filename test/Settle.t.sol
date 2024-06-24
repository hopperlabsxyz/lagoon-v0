// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.t.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

using Math for uint256;

contract TestSettle is BaseTest {
    function setUp() public {
        dealAndApprove(user1.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        requestDeposit(user1Assets / 2, user1.addr);
        dealAndApprove(user2.addr);

        updateAndSettle(0);
        deposit(user1Assets / 2, user1.addr);
    }

    function test_settle() public {
        uint256 user1Assets = assetBalance(user1.addr);

        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Assets = IERC20(vault.asset()).balanceOf(user2.addr);

        requestRedeem(user1Shares, user1.addr);
        requestDeposit(user2Assets, user2.addr);
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();

        updateAndSettle(totalAssets.mulDiv(150, 100));

        // when settle-deposit:
        uint256 totalAssetsWhenDeposit = totalAssets.mulDiv(150, 100);
        uint256 totalSupplyWhenDeposit = totalSupply;

        // totalAssets when settle-redeem:
        uint256 totalAssetsWhenRedeem = totalAssetsWhenDeposit + user2Assets;
        uint256 user2Shares = user2Assets.mulDiv(
            totalSupplyWhenDeposit + 1,
            totalAssetsWhenDeposit + 1,
            Math.Rounding.Floor
        );
        uint256 totalSupplyWhenRedeem = totalSupplyWhenDeposit + user2Shares;
        redeem(user1Shares, user1.addr);
        deposit(user2Assets, user2.addr);
        uint256 user1NewAssets = assetBalance(user1.addr);
        // user1 assets: user1Assets + user1Shares.muldiv(75*1e6 + 1, 50e1e6 + 1, Math.Round.floor)
        assertEq(
            user1NewAssets,
            user1Assets +
                user1Shares.mulDiv(
                    totalAssetsWhenRedeem,
                    totalSupplyWhenRedeem,
                    Math.Rounding.Floor
                )
        );
    }

    function test_settleAfterUpdate_TooSoon() public {
        updateTotalAssets(1);

        vm.startPrank(vault.vaultValorizationRole());
        vm.expectRevert();
        vault.settle();
        vm.stopPrank();
    }

    // function test_settleAfterUpdate_TooLate() public {
    //     updateTotalAssets(1);
    //     vm.warp(block.timestamp + 3 days);
    //     vm.startPrank(vault.vaultValorizationRole());
    //     vm.expectRevert();
    //     vault.settle();
    //     vm.stopPrank();
    // }
}
