// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";
import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AboveMaxRate, CooldownNotOver, FeeManager, Rates} from "@src/vault/FeeManager.sol";
import {Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";

contract TestFeeManager is BaseTest {
    using Math for uint256;

    uint256 _1;
    uint256 _1K;
    uint256 _10K;
    uint256 _100K;
    uint256 _1M;
    uint256 _10M;
    uint256 _20M;
    uint256 _50M;
    uint256 _100M;

    function setUp() public {
        // 20% performance fee
        // 0% management fee
        // 10%  protocol fee
        setUpVault(1000, 0, 2000);

        _1 = 1 * 10 ** vault.underlyingDecimals();
        _1K = 1000 * 10 ** vault.underlyingDecimals();
        _10K = 10_000 * 10 ** vault.underlyingDecimals();
        _100K = 100_000 * 10 ** vault.underlyingDecimals();
        _1M = 1_000_000 * 10 ** vault.underlyingDecimals();
        _10M = 10_000_000 * 10 ** vault.underlyingDecimals();
        _20M = 20_000_000 * 10 ** vault.underlyingDecimals();
        _50M = 50_000_000 * 10 ** vault.underlyingDecimals();
        _100M = 100_000_000 * 10 ** vault.underlyingDecimals();
    }

    function pricePerShare() internal view returns (uint256 pps) {
        pps = vault.convertToAssets(
            10 ** vault.decimals() // 1 share
        );
    }

    function test_defaultHighWaterMark_equalsPricePerShares() public view {
        assertEq(vault.highWaterMark(), pricePerShare());
    }

    function test_feeReceiverAndDaoHaveNoVaultSharesAtVaultCreation() public view {
        assertEq(vault.balanceOf(vault.feeReceiver()), 0);
        assertEq(vault.balanceOf(vault.protocolFeeReceiver()), 0);
    }

    function test_FeesAreTakenAfterFreeride() public {
        uint256 newTotalAssets = 0;

        // new airdrop !
        dealAmountAndApproveAndWhitelist(user1.addr, 1);
        dealAmountAndApproveAndWhitelist(user2.addr, 1_000_000);

        uint256 ppsAtStart = pricePerShare();

        uint256 user1InitialDeposit = _1;
        uint256 user2InitialDeposit = _1M;

        // user1 deposit into vault at 0$ per share
        requestDeposit(user1InitialDeposit, user1.addr);

        // ------------ Settle ------------ //
        updateAndSettle(newTotalAssets);

        vm.prank(user1.addr);
        vault.deposit(user1InitialDeposit, user1.addr, user1.addr);

        assertEq(vault.lastFeeTime(), block.timestamp);
        assertEq(pricePerShare(), ppsAtStart);

        // user2 will deposit at 0.5$ per shares
        requestDeposit(user2InitialDeposit, user2.addr);

        // ------------ Settle ------------ //
        newTotalAssets = 5 * 10 ** (vault.underlyingDecimals() - 1);
        updateAndSettle(newTotalAssets);

        vm.prank(user2.addr);
        vault.deposit(user2InitialDeposit, user2.addr, user2.addr);

        // no fees should be charged to user 1 because the pps
        // have decreased from 1 to ~0.5 and therefore do not exceed the highWaterMark of 1pps
        assertEq(
            pricePerShare(), 5 * 10 ** (vault.underlyingDecimals() - 1), "price per share didn't decreased as expected"
        );
        assertEq(vault.balanceOf(vault.feeReceiver()), 0, "feeReceiver received unexpected fee shares");
        assertEq(vault.balanceOf(vault.protocolFeeReceiver()), 0, "protocol received unexpected fee shares");

        // ------------ Settle ------------ //
        newTotalAssets = 4_000_002 * 10 ** vault.underlyingDecimals(); // vault valo made a x4 for user2; and x2 for
        // user1
        updateAndSettle(newTotalAssets);

        // We expect the price per share to do be equal to: 2 - 20% = 1.8
        assertApproxEqAbs(
            pricePerShare(),
            18 * 10 ** (vault.underlyingDecimals() - 1),
            5, // rounding approximation
            "Price per share didn't increased as expected"
        );

        assertEq(
            vault.highWaterMark(), pricePerShare(), "Highwater mark hasn't been raised at expected price per share"
        );

        uint256 user1ShareBalance = vault.balanceOf(user1.addr);
        uint256 user2ShareBalance = vault.balanceOf(user2.addr);

        requestRedeem(user1ShareBalance, user1.addr);
        requestRedeem(user2ShareBalance, user2.addr);

        // ------------ Settle ------------ //
        updateAndSettle(newTotalAssets);

        uint256 user1AssetBefore = assetBalance(user1.addr);
        uint256 user2AssetBefore = assetBalance(user2.addr);

        uint256 user1AssetAfter = redeem(user1ShareBalance, user1.addr);
        uint256 user2AssetAfter = redeem(user2ShareBalance, user2.addr);

        assetBalance(user1.addr);
        assetBalance(user2.addr);

        uint256 user1Profit = (user1AssetAfter - user1AssetBefore) - user1InitialDeposit;
        uint256 user2Profit = (user2AssetAfter - user2AssetBefore) - user2InitialDeposit;

        // Valo at totalAssets update
        // 0.5$       => pps = 0.5
        // 1.0$       => pps = 1.0 (we start taking fees)
        // 2.0$       => pps = 2.0 (fees = (2$ - 1$) * 0.2 = 0.2$ && profit = 0.8$)
        uint256 expectedUser1Profit = user1InitialDeposit - (user1InitialDeposit * 20) / 100;

        assertApproxEqAbs(user1Profit, expectedUser1Profit, 5, "user1 expected profit is wrong");

        // Valo at totalAssets update
        // 1M$       => pps = 0.5
        // 2M$       => pps = 1.0 (we start taking fees, user2 benefits a freeride between 0.5 and 1.0 pps)
        // 4M$       => pps = 2.0 (fees = (4$ - 2$) * 0.2 = 0.2M$ && profit = 2.6$)
        uint256 freeride = user2InitialDeposit;
        uint256 expectedUser2Profit = (2 * user2InitialDeposit + freeride) - (2 * user2InitialDeposit * 20) / 100;

        assertApproxEqAbs(user2Profit, expectedUser2Profit, 5, "user2 expected profit is wrong");
        uint256 expectedTotalFees = 400_000_200_000;

        address feeReceiver = vault.feeReceiver();
        address dao = vault.protocolFeeReceiver();

        uint256 feeReceiverShareBalance = vault.balanceOf(feeReceiver);
        uint256 daoShareBalance = vault.balanceOf(dao);

        requestRedeem(feeReceiverShareBalance, feeReceiver);
        requestRedeem(daoShareBalance, dao);

        // ------------ Settle ------------ //
        updateAndSettle(vault.totalAssets());

        uint256 feeReceiverAssetAfter = redeem(feeReceiverShareBalance, feeReceiver);
        uint256 daoAssetAfter = redeem(daoShareBalance, dao);

        uint256 totalFees = feeReceiverAssetAfter + daoAssetAfter;

        assertEq(totalFees, expectedTotalFees, "wrong total Fees");
    }

    function test_NoFeesAreTakenDuringFreeRide() public {
        uint256 newTotalAssets = 0;

        // new airdrop !
        dealAmountAndApproveAndWhitelist(user1.addr, 1);
        dealAmountAndApproveAndWhitelist(user2.addr, 1_000_000);

        uint256 ppsAtStart = pricePerShare();

        uint256 user1InitialDeposit = _1;
        uint256 user2InitialDeposit = _1M;

        // user1 deposit into vault at 0$ per share
        requestDeposit(user1InitialDeposit, user1.addr);

        // ------------ Settle ------------ //
        updateAndSettle(newTotalAssets);

        vm.prank(user1.addr);
        vault.deposit(user1InitialDeposit, user1.addr, user1.addr);

        assertEq(vault.lastFeeTime(), block.timestamp);
        assertEq(pricePerShare(), ppsAtStart);

        // user2 will deposit at 0.5$ per shares
        requestDeposit(user2InitialDeposit, user2.addr);

        // ------------ Settle ------------ //
        newTotalAssets = 5 * 10 ** (vault.underlyingDecimals() - 1);
        updateAndSettle(newTotalAssets);

        vm.prank(user2.addr);
        vault.deposit(user2InitialDeposit, user2.addr, user2.addr);

        // no fees should be charged to user 1 because the pps
        // have decreased from 1 to ~0.5 and therefore do not exceed the highWaterMark of 1pps
        assertEq(
            pricePerShare(), 5 * 10 ** (vault.underlyingDecimals() - 1), "price per share didn't decreased as expected"
        );
        assertEq(vault.balanceOf(vault.feeReceiver()), 0, "feeReceiver received unexpected fee shares");
        assertEq(vault.balanceOf(vault.protocolFeeReceiver()), 0, "protocol received unexpected fee shares");

        // ------------ Settle ------------ //

        // user2 get x2 without paying performance fees
        newTotalAssets = 2_000_001 * 10 ** vault.underlyingDecimals(); // vault valo made a x2 for user2; and x1 for
        // user1
        updateAndSettle(newTotalAssets);

        // We expect the price per share to do be equal to: 2 - 20% = 1.8
        assertApproxEqAbs(
            pricePerShare(),
            1 * 10 ** vault.underlyingDecimals(),
            5, // rounding approximation
            "Wrong price per share"
        );

        assertEq(
            vault.highWaterMark(), pricePerShare(), "Highwater mark hasn't been raised at expected price per share"
        );

        uint256 user1ShareBalance = vault.balanceOf(user1.addr);
        uint256 user2ShareBalance = vault.balanceOf(user2.addr);

        requestRedeem(user1ShareBalance, user1.addr);
        requestRedeem(user2ShareBalance, user2.addr);

        // ------------ Settle ------------ //
        updateAndSettle(newTotalAssets);

        uint256 user1AssetBefore = assetBalance(user1.addr);
        uint256 user2AssetBefore = assetBalance(user2.addr);

        uint256 user1AssetAfter = redeem(user1ShareBalance, user1.addr);
        uint256 user2AssetAfter = redeem(user2ShareBalance, user2.addr);

        assetBalance(user1.addr);
        assetBalance(user2.addr);

        uint256 user1Profit = (user1AssetAfter - user1AssetBefore) - user1InitialDeposit;
        uint256 user2Profit = (user2AssetAfter - user2AssetBefore) - user2InitialDeposit;

        // Valo at totalAssets update
        // 0.5$       => pps = 0.5
        // 1.0$       => pps = 1.0 (no fees taken since we are back to the intial price per share)
        uint256 expectedUser1Profit = 0;

        assertApproxEqAbs(user1Profit, expectedUser1Profit, 5, "user1 expected profit is wrong");

        // Valo at totalAssets update
        // 1M$       => pps = 0.5
        // 2M$       => pps = 1.0 (user2 makes 1M profit without paying any fees)
        uint256 freeride = user2InitialDeposit;

        assertApproxEqAbs(user2Profit, freeride, 5, "user2 expected profit is wrong");

        assertEq(vault.balanceOf(vault.feeReceiver()), 0, "feeReceiver received unexpected fee shares");
        assertEq(vault.balanceOf(vault.protocolFeeReceiver()), 0, "protocol received unexpected fee shares");
    }

    function test_updateRates_revertIfManagementRateAboveMaxRates() public {
        uint16 MAX_MANAGEMENT_RATE = vault.MAX_MANAGEMENT_RATE();
        uint16 MAX_PERFORMANCE_RATE = vault.MAX_PERFORMANCE_RATE();

        Rates memory newRates =
            Rates({managementRate: MAX_MANAGEMENT_RATE + 1, performanceRate: MAX_PERFORMANCE_RATE - 1});

        Rates memory ratesBefore = vault.feeRates();

        vm.prank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_MANAGEMENT_RATE));
        vault.updateRates(newRates);

        Rates memory ratesAfter = vault.feeRates();

        assertEq(ratesAfter.managementRate, ratesBefore.managementRate, "managementRate before and after are different");
        assertEq(
            ratesAfter.performanceRate, ratesBefore.performanceRate, "performanceRate before and after are different"
        );
    }

    function test_updateRates_revertIfPerformanceRateAboveMaxRates() public {
        uint16 MAX_MANAGEMENT_RATE = vault.MAX_MANAGEMENT_RATE();
        uint16 MAX_PERFORMANCE_RATE = vault.MAX_PERFORMANCE_RATE();

        Rates memory newRates =
            Rates({managementRate: MAX_MANAGEMENT_RATE - 1, performanceRate: MAX_PERFORMANCE_RATE + 1});

        Rates memory ratesBefore = vault.feeRates();

        vm.prank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_PERFORMANCE_RATE));
        vault.updateRates(newRates);

        Rates memory ratesAfter = vault.feeRates();

        assertEq(ratesAfter.managementRate, ratesBefore.managementRate, "managementRate before and after are different");
        assertEq(
            ratesAfter.performanceRate, ratesBefore.performanceRate, "performanceRate before and after are different"
        );
    }

    function test_updateRates_revertIfCoolDownNotOver() public {
        Rates memory newRates = Rates({managementRate: 42, performanceRate: 42});

        vm.prank(vault.owner());
        vault.updateRates(newRates);

        vm.prank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(CooldownNotOver.selector, 1 days));
        vault.updateRates(newRates);

        vm.warp(block.timestamp + 1 days);
        vm.prank(vault.owner());
        vault.updateRates(newRates);
    }
}
