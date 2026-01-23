// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {State} from "@src/v0.6.0/primitives/Enums.sol";
import {WithdrawSync} from "@src/v0.6.0/primitives/Events.sol";
import {Rates} from "@src/v0.6.0/primitives/Struct.sol";

contract TestSyncRedeem is BaseTest {
    using Math for uint256;

    uint16 entryFeeRate = 1000; // 10 %
    uint16 exitFeeRate = 500; // 5 %
    uint16 haircutRate = 200; // 2 %

    function setUp() public {
        setUpVault(0, 0, 0, entryFeeRate, exitFeeRate);
        dealAndApproveAndWhitelist(user1.addr);

        // for the next 1000 seconds, we will be able to use the sync deposit/redeem flow
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);
    }

    function test_syncRedeem_simple() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        // Now redeem some shares
        uint256 sharesToRedeem = sharesReceived / 2;
        uint256 expectedAssets = vault.previewSyncRedeem(sharesToRedeem);

        uint256 safeAssetsBefore = assetBalance(address(vault.safe()));
        uint256 userSharesBefore = vault.balanceOf(user1.addr);
        uint256 userAssetsBefore = assetBalance(user1.addr);
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.expectEmit(true, true, true, true);
        emit WithdrawSync(user1.addr, user1.addr, user1.addr, expectedAssets, sharesToRedeem);

        vm.prank(user1.addr);
        uint256 assets = vault.syncRedeem(sharesToRedeem, user1.addr);

        assertEq(assets, expectedAssets, "assets returned != previewSyncRedeem");
        assertEq(vault.balanceOf(user1.addr), userSharesBefore - sharesToRedeem, "shares not burned correctly");
        assertEq(assetBalance(user1.addr), userAssetsBefore + assets, "user assets not increased correctly");
        assertEq(assetBalance(address(vault.safe())), safeAssetsBefore - assets, "safe assets not decreased correctly");
        assertEq(vault.totalAssets(), totalAssetsBefore - assets, "totalAssets not decreased correctly");
    }

    function test_syncRedeem_lifespanOutdate() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        vault.syncDeposit(depositAmount, user1.addr, address(0));

        // we go one second after the expiration
        vm.warp(block.timestamp + 1001);

        vm.expectRevert(OnlyAsyncDepositAllowed.selector);
        vm.prank(user1.addr);
        vault.syncRedeem(1, user1.addr);
    }

    function test_syncRedeem_whenClosed() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        vault.syncDeposit(depositAmount, user1.addr, address(0));

        address[] memory wl = new address[](1);
        wl[0] = user1.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        // close the vault
        vm.prank(admin.addr);
        vault.initiateClosing();

        vm.prank(safe.addr);
        vault.expireTotalAssets();

        updateNewTotalAssets(vault.totalAssets());
        vm.stopPrank();

        vm.expectRevert(OnlyAsyncDepositAllowed.selector);
        vm.prank(user1.addr);
        vault.syncRedeem(1, user1.addr);

        vm.startPrank(safe.addr);
        vault.close(vault.newTotalAssets());
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(NotOpen.selector, State.Closed));
        vm.prank(user1.addr);
        vault.syncRedeem(1, user1.addr);
    }

    function test_syncRedeem_whitelist() public {
        // First deposit to get shares for user1
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        vault.syncDeposit(depositAmount, user1.addr, address(0));

        // user2 is not whitelisted
        vm.expectRevert(NotWhitelisted.selector);
        vm.prank(user2.addr);
        vault.syncRedeem(1, user2.addr);
    }

    function test_syncRedeem_whenPaused() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        vault.syncDeposit(depositAmount, user1.addr, address(0));

        // pause the vault
        vm.prank(admin.addr);
        vault.pause();

        // make sure he is wl
        address[] memory wl = new address[](1);
        wl[0] = user1.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(user1.addr);
        vault.syncRedeem(1, user1.addr);
    }

    function test_syncRedeem_differentReceiver() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        // Whitelist user2
        address[] memory wl = new address[](1);
        wl[0] = user2.addr;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);

        uint256 sharesToRedeem = sharesReceived / 2;
        uint256 expectedAssets = vault.previewSyncRedeem(sharesToRedeem);

        uint256 user2AssetsBefore = assetBalance(user2.addr);
        uint256 user1SharesBefore = vault.balanceOf(user1.addr);
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.expectEmit(true, true, true, false);
        emit WithdrawSync(user1.addr, user2.addr, user1.addr, expectedAssets, sharesToRedeem);

        vm.prank(user1.addr);
        uint256 assets = vault.syncRedeem(sharesToRedeem, user2.addr);

        assertEq(assets, expectedAssets);
        assertEq(vault.balanceOf(user1.addr), user1SharesBefore - sharesToRedeem, "user1 shares not burned correctly");
        assertEq(assetBalance(user2.addr), user2AssetsBefore + assets, "user2 assets not increased correctly");
        assertEq(vault.totalAssets(), totalAssetsBefore - assets, "totalAssets not decreased correctly");
    }

    function test_syncRedeem_exitFeeShares() public {
        // Set up vault with known exit rate
        setUpVault(0, 0, 0, 0, exitFeeRate);
        dealAndApproveAndWhitelist(user1.addr);
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);

        // Deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        uint256 sharesToRedeem = sharesReceived;
        uint256 exitFeeShares = FeeLib.computeFee(sharesToRedeem, exitFeeRate);
        uint256 expectedAssets = vault.previewSyncRedeem(sharesToRedeem);

        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 feeReceiverSharesBefore = vault.balanceOf(vault.feeReceiver());
        uint256 protocolFeeReceiverSharesBefore = vault.balanceOf(vault.protocolFeeReceiver());
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.prank(user1.addr);
        uint256 assets = vault.syncRedeem(sharesToRedeem, user1.addr);

        // Exit fee shares should be minted to fee receivers
        uint256 totalSupplyAfter = vault.totalSupply();
        uint256 feeReceiverSharesAfter = vault.balanceOf(vault.feeReceiver());
        uint256 protocolFeeReceiverSharesAfter = vault.balanceOf(vault.protocolFeeReceiver());

        // Total supply should decrease by (sharesToRedeem - exitFeeShares)
        // because exitFeeShares are minted as fees
        assertEq(totalSupplyBefore - totalSupplyAfter, sharesToRedeem - exitFeeShares, "total supply change incorrect");

        // Fee receivers should receive the exit fee shares
        uint256 totalFeeSharesReceived = (feeReceiverSharesAfter - feeReceiverSharesBefore)
            + (protocolFeeReceiverSharesAfter - protocolFeeReceiverSharesBefore);
        assertEq(totalFeeSharesReceived, exitFeeShares, "exit fee shares not minted correctly");

        // Total assets should decrease by the assets withdrawn
        assertEq(vault.totalAssets(), totalAssetsBefore - assets, "totalAssets not decreased correctly");
        assertEq(assets, expectedAssets, "assets returned != previewSyncRedeem");
    }

    function test_syncRedeem_haircutShares_burned() public {
        // Set up vault with haircut rate but no exit fee
        setUpVault(0, 0, 0, 0, 0);

        // Update rates to set haircut rate
        Rates memory newRates =
            Rates({managementRate: 0, performanceRate: 0, entryRate: 0, exitRate: 0, haircutRate: haircutRate});
        vm.prank(vault.owner());
        vault.updateRates(newRates);
        vm.warp(block.timestamp + 1 days); // wait for cooldown

        dealAndApproveAndWhitelist(user1.addr);
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);

        // Deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        uint256 sharesToRedeem = sharesReceived;
        uint256 haircutShares = FeeLib.computeFee(sharesToRedeem, haircutRate);

        uint256 userSharesBefore = vault.balanceOf(user1.addr);
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 expectedAssets = vault.convertToAssetsWithRounding(sharesToRedeem - haircutShares, Math.Rounding.Floor);

        vm.prank(user1.addr);
        uint256 assets = vault.syncRedeem(sharesToRedeem, user1.addr);

        // All shares should be burned
        assertEq(vault.balanceOf(user1.addr), userSharesBefore - sharesToRedeem, "all shares should be burned");

        // Total supply should decrease by sharesToRedeem (no fees minted since exitRate = 0)
        assertEq(totalSupplyBefore - vault.totalSupply(), sharesToRedeem, "total supply should decrease by all shares");

        // Assets should correspond to (sharesToRedeem - haircutShares)
        assertEq(assets, expectedAssets, "assets should account for haircut");

        // Total assets should decrease by the assets withdrawn
        assertEq(vault.totalAssets(), totalAssetsBefore - assets, "totalAssets not decreased correctly");
    }

    function test_syncRedeem_pps_consistent_when_no_haircut() public {
        // Set up vault with exit fee but no haircut
        setUpVault(0, 0, 0, 0, exitFeeRate);
        dealAndApproveAndWhitelist(user1.addr);
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);

        // Deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        uint256 ppsBeforeDeposit = vault.pricePerShare();
        vm.prank(user1.addr);

        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        uint256 ppsBeforeRedeem = vault.pricePerShare();

        assertApproxEqAbs(ppsBeforeDeposit, ppsBeforeRedeem, 1, "price per share should remain consistent");

        uint256 sharesToRedeem = sharesReceived / 2;
        uint256 expectedAssets = vault.previewSyncRedeem(sharesToRedeem);
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.prank(user1.addr);
        uint256 assets = vault.syncRedeem(sharesToRedeem, user1.addr);

        uint256 ppsAfter = vault.pricePerShare();

        // Allow for small rounding differences
        // When haircut = 0, only exit fees are taken, so PPS should remain approximately the same
        assertApproxEqAbs(ppsAfter, ppsBeforeRedeem, 1, "price per share should remain consistent when haircut = 0");

        // Total assets should decrease by the assets withdrawn
        assertEq(vault.totalAssets(), totalAssetsBefore - assets, "totalAssets not decreased correctly");
        assertEq(assets, expectedAssets, "assets returned != previewSyncRedeem");
    }

    function test_syncRedeem_pps_increases_when_haircut_non_zero() public {
        // Set up vault with haircut rate but no exit fee
        setUpVault(0, 0, 0, 0, 0);

        // Update rates to set haircut rate
        Rates memory newRates =
            Rates({managementRate: 0, performanceRate: 0, entryRate: 0, exitRate: 0, haircutRate: haircutRate});
        vm.prank(vault.owner());
        vault.updateRates(newRates);
        vm.warp(block.timestamp + 1 days); // wait for cooldown

        dealAndApproveAndWhitelist(user1.addr);
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        updateAndSettle(0);

        // Deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        uint256 ppsBefore = vault.pricePerShare();

        uint256 sharesToRedeem = sharesReceived / 2;
        uint256 expectedAssets = vault.previewSyncRedeem(sharesToRedeem);
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.prank(user1.addr);
        uint256 assets = vault.syncRedeem(sharesToRedeem, user1.addr);

        uint256 ppsAfter = vault.pricePerShare();

        // When haircut > 0, shares are burned but fewer assets are withdrawn
        // This means totalAssets decreases less than totalSupply, so PPS increases
        assertGt(ppsAfter, ppsBefore, "price per share should increase when haircut > 0");

        // Total assets should decrease by the assets withdrawn
        assertEq(vault.totalAssets(), totalAssetsBefore - assets, "totalAssets not decreased correctly");
        assertEq(assets, expectedAssets, "assets returned != previewSyncRedeem");
    }

    function test_syncRedeem_zero_shares() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        vault.syncDeposit(depositAmount, user1.addr, address(0));

        uint256 userAssetsBefore = assetBalance(user1.addr);
        uint256 userSharesBefore = vault.balanceOf(user1.addr);
        uint256 totalAssetsBefore = vault.totalAssets();

        vm.prank(user1.addr);
        uint256 assets = vault.syncRedeem(0, user1.addr);

        assertEq(assets, 0, "zero shares should return zero assets");
        assertEq(vault.balanceOf(user1.addr), userSharesBefore, "shares should not change");
        assertEq(assetBalance(user1.addr), userAssetsBefore, "assets should not change");
        assertEq(vault.totalAssets(), totalAssetsBefore, "totalAssets should not change when redeeming zero shares");
    }

    function test_syncRedeem_event() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        uint256 sharesToRedeem = sharesReceived / 2;
        uint256 expectedAssets = vault.previewSyncRedeem(sharesToRedeem);

        vm.expectEmit(true, true, true, true);
        emit WithdrawSync(user1.addr, user1.addr, user1.addr, expectedAssets, sharesToRedeem);

        vm.prank(user1.addr);
        vault.syncRedeem(sharesToRedeem, user1.addr);
    }

    function test_syncRedeem_insufficientSafeBalance() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        // Calculate how many assets would be needed for a full redeem
        uint256 sharesToRedeem = sharesReceived;

        uint256 safeBalance = assetBalance(address(vault.safe()));
        // Remove assets from safe so it doesn't have enough
        IERC20 asset = IERC20(vault.asset());
        vm.prank(vault.safe());
        asset.transfer(address(0xdead), safeBalance);

        // Now try to redeem - should fail because safe doesn't have enough assets
        vm.expectRevert();
        vm.prank(user1.addr);
        vault.syncRedeem(sharesToRedeem, user1.addr);
    }

    function test_syncRedeem_insufficientUserShares() public {
        // First deposit to get shares
        uint256 depositAmount = assetBalance(user1.addr);
        vm.prank(user1.addr);
        uint256 sharesReceived = vault.syncDeposit(depositAmount, user1.addr, address(0));

        // Try to redeem more shares than the user has
        uint256 sharesToRedeem = sharesReceived + 1;

        // Should fail because user doesn't have enough shares
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, user1.addr, sharesReceived, sharesToRedeem
            )
        );
        vm.prank(user1.addr);
        vault.syncRedeem(sharesToRedeem, user1.addr);
    }
}
