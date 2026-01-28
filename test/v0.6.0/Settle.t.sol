// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

using Math for uint256;

contract TestSettle is BaseTest {
    function setUp() public {
        // State after setup:
        // user1:
        //  - 50_000 shares
        //  - 50_000 assets
        // user2:
        //  - 100_000 assets
        setUpVault(0, 0, 0);

        // deals 100_000 assets to user1
        dealAndApproveAndWhitelist(user1.addr);

        // 100_000
        uint256 user1Assets = assetBalance(user1.addr);

        // 50_000 assets deposit request
        requestDeposit(user1Assets / 2, user1.addr);

        // deals 100_000 assets to user2
        dealAndApproveAndWhitelist(user2.addr);

        // Settlement:
        // user1:
        //  - 50_000 claimable shares
        //  - 50_000 assets
        // user2:
        //  - 100_000 assets
        updateAndSettle(0);
        vm.warp(block.timestamp + 1);

        // user1 claims 50_000 shares
        deposit(user1Assets / 2, user1.addr);
    }

    function test_simple_settle() public {
        uint256 user1Assets = assetBalance(user1.addr);
        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Assets = IERC20(vault.asset()).balanceOf(user2.addr);

        requestRedeem(user1Shares, user1.addr);
        requestDeposit(user2Assets, user2.addr);
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = vault.totalSupply();
        updateAndSettle(totalAssets.mulDiv(150, 100));
        assertApproxEqAbs(vault.highWaterMark(), vault.pricePerShare(), 1, "wrong highWaterMark");

        // when settle-deposit:
        uint256 totalAssetsWhenDeposit = totalAssets.mulDiv(150, 100);
        uint256 totalSupplyWhenDeposit = totalSupply;

        // totalAssets when settle-redeem:
        uint256 totalAssetsWhenRedeem = totalAssetsWhenDeposit + user2Assets;
        uint256 user2Shares =
            user2Assets.mulDiv(totalSupplyWhenDeposit + 1, totalAssetsWhenDeposit + 1, Math.Rounding.Floor);
        uint256 totalSupplyWhenRedeem = totalSupplyWhenDeposit + user2Shares;
        redeem(user1Shares, user1.addr);
        deposit(user2Assets, user2.addr);
        uint256 user1NewAssets = assetBalance(user1.addr);
        // user1 assets: user1Assets + user1Shares.muldiv(75*1e6 + 1, 50e1e6 + 1, Math.Round.floor)
        assertApproxEqAbs(
            user1NewAssets,
            user1Assets + user1Shares.mulDiv(totalAssetsWhenRedeem, totalSupplyWhenRedeem, Math.Rounding.Floor),
            1,
            "wrong user1 new assets"
        );
    }

    function test_settleDepositAfterUpdate() public {
        uint256 user1Assets = assetBalance(user1.addr);
        uint256 totalAssets = assetBalance(safe.addr);

        // 50_000 assets deposit request
        requestDeposit(user1Assets, user1.addr);

        updateNewTotalAssets(totalAssets);

        uint256 settleDepositIdBefore = vault.depositSettleId();

        vm.expectEmit(true, true, true, true);
        emit SettleDeposit(
            3, // there is one updateAndSettle in Setup function so 1 => 3
            3, // same here
            100_000 * 10 ** vault.underlyingDecimals(),
            100_000 * 10 ** vault.decimals(),
            user1Assets,
            50_000 * 10 ** vault.decimals()
        );
        vm.startPrank(vault.safe());
        vault.settleDeposit(vault.newTotalAssets());
        vm.stopPrank();

        uint256 settleDepositIdAfter = vault.depositSettleId();

        assertEq(settleDepositIdBefore + 2, settleDepositIdAfter, "wrong settle redeem id after settle redeem");
    }

    function test_settleRedeemAfterUpdate() public {
        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 totalAssets = assetBalance(safe.addr);

        requestRedeem(user1Shares, user1.addr);
        updateNewTotalAssets(totalAssets);

        uint256 settleRedeemIdBefore = vault.redeemSettleId();

        vm.expectEmit(true, true, true, true);
        emit SettleRedeem(2, 2, 0, 0, 50_000 * 10 ** vault.underlyingDecimals(), user1Shares);
        vm.startPrank(vault.safe());
        vault.settleRedeem(vault.newTotalAssets());
        vm.stopPrank();
        uint256 settleRedeemIdAfter = vault.redeemSettleId();

        assertEq(settleRedeemIdBefore + 2, settleRedeemIdAfter, "wrong settle redeem id after settle redeem");
    }

    function test_settleDepositThenRedeemAfterUpdate() public {
        updateNewTotalAssets(10 ** vault.underlyingDecimals());
        vm.warp(block.timestamp + 1);
        uint256 hwmBefore = vault.highWaterMark();
        vm.startPrank(vault.safe());
        vault.settleDeposit(vault.newTotalAssets());
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
        assertEq(vault.highWaterMark(), hwmBefore, "assertion 0");

        updateNewTotalAssets(1);

        hwmBefore = vault.highWaterMark();
        vm.startPrank(vault.safe());
        vault.settleRedeem(vault.newTotalAssets());
        vm.stopPrank();
        assertEq(vault.highWaterMark(), hwmBefore, "assertion 1");
    }

    function test_settle_deposit_without_totalAssets_update_reverts() public {
        setUpVault(0, 0, 0);

        dealAndApproveAndWhitelist(user1.addr);

        uint256 user1Assets = assetBalance(user1.addr);

        requestDeposit(user1Assets / 2, user1.addr);

        vm.startPrank(vault.safe());
        vm.expectRevert(NewTotalAssetsMissing.selector);
        vault.settleDeposit(1);
        vm.stopPrank();
        vm.warp(block.timestamp + 1);

        uint256 hwmBefore = vault.highWaterMark();
        updateNewTotalAssets(0);
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(vault.safe());
        vault.settleDeposit(vault.newTotalAssets());
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
        assertEq(vault.highWaterMark(), hwmBefore);

        vm.prank(vault.safe());
        vm.expectRevert(NewTotalAssetsMissing.selector);
        vault.settleDeposit(1);

        uint256 expectedDepositId = vault.depositEpochId();

        updateNewTotalAssets(0);
        vm.warp(block.timestamp + 1 days);
        assertEq(vault.depositEpochId(), expectedDepositId, "wrong depositId 1");

        updateNewTotalAssets(0);
        vm.warp(block.timestamp + 1 days);
        assertEq(vault.depositEpochId(), expectedDepositId, "wrong depositId 2");

        uint256 userRequestId = requestDeposit(user1Assets / 2, user1.addr);

        updateNewTotalAssets(0);
        vm.warp(block.timestamp + 1 days);

        assertEq(userRequestId, expectedDepositId, "wrong userRequestId");
        assertEq(vault.depositEpochId(), expectedDepositId + 2, "wrong depositId 3");

        hwmBefore = vault.highWaterMark();
        vm.startPrank(vault.safe());
        vault.settleDeposit(vault.newTotalAssets());
        vm.stopPrank();
        assertEq(vault.highWaterMark(), hwmBefore);

        vm.prank(vault.safe());
        vm.expectRevert(NewTotalAssetsMissing.selector);
        vault.settleDeposit(1);
    }

    function test_settle_redeem_totalAssets_update_reverts() public {
        setUpVault(0, 0, 0);

        dealAndApproveAndWhitelist(user1.addr);

        uint256 user1Assets = assetBalance(user1.addr);

        requestDeposit(user1Assets / 2, user1.addr);

        uint256 hwmBefore = vault.highWaterMark();
        updateAndSettle(0);
        vm.warp(block.timestamp + 1);
        assertEq(vault.highWaterMark(), hwmBefore);

        vm.prank(user1.addr);
        uint256 user1Shares = vault.deposit(user1Assets / 2, user1.addr);

        requestRedeem(user1Shares / 2, user1.addr);

        vm.prank(vault.safe());
        vm.expectRevert(NewTotalAssetsMissing.selector);
        vault.settleRedeem(1);

        updateNewTotalAssets(user1Assets / 2);

        hwmBefore = vault.highWaterMark();
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(vault.safe());
        vault.settleRedeem(vault.newTotalAssets());
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
        assertEq(vault.highWaterMark(), hwmBefore);

        vm.prank(vault.safe());
        vm.expectRevert(NewTotalAssetsMissing.selector);
        vault.settleRedeem(1);

        vm.prank(vault.safe());
        vm.expectRevert(NewTotalAssetsMissing.selector);
        vault.settleDeposit(1);

        uint256 expectedRedeemId = vault.redeemEpochId();

        updateNewTotalAssets(0);
        assertEq(vault.redeemEpochId(), expectedRedeemId, "wrong redeemId 1");

        updateNewTotalAssets(0);
        assertEq(vault.redeemEpochId(), expectedRedeemId, "wrong redeemId 2");

        uint256 userRequestId = requestRedeem(user1Shares / 2, user1.addr);

        updateNewTotalAssets(0);
        vm.warp(block.timestamp + 1 days);

        assertEq(userRequestId, expectedRedeemId, "wrong userRequestId");
        assertEq(vault.redeemEpochId(), expectedRedeemId + 2, "wrong redeemId 3");

        hwmBefore = vault.highWaterMark();
        vm.startPrank(vault.safe());
        vault.settleRedeem(vault.newTotalAssets());
        vm.stopPrank();
        assertEq(vault.highWaterMark(), hwmBefore);

        vm.prank(vault.safe());
        vm.expectRevert(NewTotalAssetsMissing.selector);
        vault.settleRedeem(1);
    }

    function test_updateNewTotalAssets_revertIfNotTotalAssetsManager() public {
        vm.expectRevert(abi.encodeWithSelector(OnlyValuationManager.selector, vault.valuationManager()));
        vault.updateNewTotalAssets(0);
    }

    function test_settleDeposit_revertIfNotTotalAssetsManager() public {
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, vault.safe()));
        vault.settleDeposit(1);
    }

    function test_settleRedeem_revertIfNotTotalAssetsManager() public {
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, vault.safe()));
        vault.settleRedeem(1);
    }

    function test_settleRedeem_revertIfWrongNewTotalAssets() public {
        updateNewTotalAssets(2);

        vm.prank(vault.safe());
        vm.expectRevert(WrongNewTotalAssets.selector);
        vault.settleRedeem(1);
    }

    function test_settleDeposit_revertIfWrongNewTotalAssets() public {
        updateNewTotalAssets(2);
        vm.prank(vault.safe());
        vm.expectRevert(WrongNewTotalAssets.selector);
        vault.settleRedeem(1);
    }

    function test_close_revertIfWrongNewTotalAssets() public {
        updateNewTotalAssets(2);
        vm.prank(vault.owner());
        vault.initiateClosing();
        vm.prank(vault.safe());
        vm.expectRevert(WrongNewTotalAssets.selector);
        vault.close(1);
    }

    function test_close_revertIfNotTotalAssetsManager() public {
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, vault.safe()));
        vault.close(1);
    }
}
