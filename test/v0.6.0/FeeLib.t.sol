// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Test} from "forge-std/Test.sol";

contract FeeLibTest is Test {
    using Math for uint256;

    // ====== MANAGEMENT FEE TESTS ======

    function test_calculateManagementFee_zeroAssets() public pure {
        uint256 assets = 0;
        uint256 annualRate = 100; // 1%
        uint256 timeElapsed = 365 days;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);

        assertEq(managementFee, 0);
    }

    function test_calculateManagementFee_zeroRate() public pure {
        uint256 assets = 1000e18;
        uint256 annualRate = 0; // 0%
        uint256 timeElapsed = 365 days;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);

        assertEq(managementFee, 0);
    }

    function test_calculateManagementFee_zeroTime() public pure {
        uint256 assets = 1000e18;
        uint256 annualRate = 100; // 1%
        uint256 timeElapsed = 0;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);

        assertEq(managementFee, 0);
    }

    function test_calculateManagementFee_oneYear() public pure {
        uint256 assets = 1000e18;
        uint256 annualRate = 100; // 1%
        uint256 timeElapsed = 365 days;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);
        uint256 expectedFee = 10e18; // 1% of 1000 for full year

        assertEq(managementFee, expectedFee);
    }

    function test_calculateManagementFee_halfYear() public pure {
        uint256 assets = 1000e18;
        uint256 annualRate = 200; // 2%
        uint256 timeElapsed = 182.5 days;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);
        // Expected: 1000 * 2% * (182.5/365) = 10
        uint256 expectedFee = 10e18;

        assertApproxEqAbs(managementFee, expectedFee, 1e15); // Allow small rounding difference
    }

    function test_calculateManagementFee_oneMonth() public pure {
        uint256 assets = 12_000e18;
        uint256 annualRate = 1200; // 12% annual
        uint256 timeElapsed = 30 days;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);
        // Expected: 12000 * 12% * (30/365) ≈ 118.36
        uint256 expectedFee = 118_356_164_383_561_643_836; // Approximately 118.36

        assertApproxEqAbs(managementFee, expectedFee, 1e16);
    }

    function test_calculateManagementFee_maxRate() public pure {
        uint256 assets = 1000e18;
        uint256 annualRate = FeeLib.MAX_MANAGEMENT_RATE; // 10%
        uint256 timeElapsed = 365 days;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);
        uint256 expectedFee = 100e18; // 10% of 1000

        assertEq(managementFee, expectedFee);
    }

    function test_calculateManagementFee_moreThanOneYear() public pure {
        uint256 assets = 1000e18;
        uint256 annualRate = 100; // 1%
        uint256 timeElapsed = 730 days; // 2 years

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);
        uint256 expectedFee = 20e18; // 1% * 2 years = 2%

        assertEq(managementFee, expectedFee);
    }

    function test_calculateManagementFee_roundingUp() public pure {
        uint256 assets = 333; // Small amount that will cause rounding
        uint256 annualRate = 333; // 3.33%
        uint256 timeElapsed = 100 days;

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);

        // Should round up due to Math.Rounding.Ceil
        assertGt(managementFee, 0);
    }

    function testFuzz_calculateManagementFee(
        uint256 assets,
        uint256 annualRate,
        uint256 timeElapsed
    ) public pure {
        assets = bound(assets, 0, type(uint128).max);
        annualRate = bound(annualRate, 0, FeeLib.BPS_DIVIDER); // 0% to 100%
        timeElapsed = bound(timeElapsed, 0, 10 * 365 days); // Up to 10 years

        uint256 managementFee = FeeLib.calculateManagementFee(assets, annualRate, timeElapsed);

        // Fee should never exceed assets for reasonable time periods
        if (timeElapsed <= 365 days && annualRate <= FeeLib.BPS_DIVIDER) {
            assertLe(managementFee, assets);
        }

        // Zero inputs should result in zero fee
        if (assets == 0 || annualRate == 0 || timeElapsed == 0) {
            assertEq(managementFee, 0);
        }
    }

    // ====== PERFORMANCE FEE TESTS ======

    function test_calculatePerformanceFee_noProfitEqualPrices() public pure {
        uint256 rate = 2000; // 20%
        uint256 totalSupply = 1000e18;
        uint256 pricePerShare = 1e18; // Same as high water mark
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        assertEq(performanceFee, 0);
    }

    function test_calculatePerformanceFee_noProfitLowerPrice() public pure {
        uint256 rate = 2000; // 20%
        uint256 totalSupply = 1000e18;
        uint256 pricePerShare = 0.9e18; // Lower than high water mark
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        assertEq(performanceFee, 0);
    }

    function test_calculatePerformanceFee_withProfit() public pure {
        uint256 rate = 2000; // 20%
        uint256 totalSupply = 1000e18;
        uint256 pricePerShare = 1.1e18; // 10% higher than high water mark
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        // Profit per share: 0.1e18
        // Total profit: 0.1e18 * 1000e18 / 1e18 = 100e18
        // Performance fee: 100e18 * 20% = 20e18
        uint256 expectedFee = 20e18;

        assertEq(performanceFee, expectedFee);
    }

    function test_calculatePerformanceFee_zeroRate() public pure {
        uint256 rate = 0; // 0%
        uint256 totalSupply = 1000e18;
        uint256 pricePerShare = 1.2e18;
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        assertEq(performanceFee, 0);
    }

    function test_calculatePerformanceFee_maxRate() public pure {
        uint256 rate = FeeLib.MAX_PERFORMANCE_RATE; // 50% (5000 bps)
        uint256 totalSupply = 1000e18;
        uint256 pricePerShare = 1.2e18; // 20% profit
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        // Profit: 200e18, Fee: 200e18 * 50% = 100e18
        uint256 expectedFee = 100e18;

        assertEq(performanceFee, expectedFee);
    }

    function test_calculatePerformanceFee_zeroSupply() public pure {
        uint256 rate = 2000; // 20%
        uint256 totalSupply = 0;
        uint256 pricePerShare = 1.5e18;
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        assertEq(performanceFee, 0);
    }

    function test_calculatePerformanceFee_differentDecimals() public pure {
        uint256 rate = 1000; // 10%
        uint256 totalSupply = 1000e6; // 6 decimals
        uint256 pricePerShare = 1.5e6;
        uint256 highWaterMark = 1e6;
        uint256 decimals = 6;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        // Profit per share: 0.5e6
        // Total profit: 0.5e6 * 1000e6 / 1e6 = 500e6
        // Performance fee: 500e6 * 10% = 50e6
        uint256 expectedFee = 50e6;

        assertEq(performanceFee, expectedFee);
    }

    function test_calculatePerformanceFee_largeProfit() public pure {
        uint256 rate = 2000; // 20%
        uint256 totalSupply = 1000e18;
        uint256 pricePerShare = 3e18; // 3x the high water mark
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        // Profit: 2000e18, Fee: 2000e18 * 20% = 400e18
        uint256 expectedFee = 400e18;

        assertEq(performanceFee, expectedFee);
    }

    function test_calculatePerformanceFee_smallProfit() public pure {
        uint256 rate = 2000; // 20%
        uint256 totalSupply = 1000e18;
        uint256 pricePerShare = 1_000_000_000_000_000_001; // Tiny profit (1 wei above 1e18)
        uint256 highWaterMark = 1e18;
        uint256 decimals = 18;

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        // Should be greater than 0 due to rounding up
        assertGt(performanceFee, 0);
    }

    function test_calculatePerformanceFee_roundingUp() public pure {
        uint256 rate = 333; // 3.33%
        uint256 totalSupply = 333;
        uint256 pricePerShare = 334; // Small profit
        uint256 highWaterMark = 333;
        uint256 decimals = 0; // No decimals for simplicity

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        // Should round up due to Math.Rounding.Ceil
        assertGt(performanceFee, 0);
    }

    function testFuzz_calculatePerformanceFee(
        uint256 rate,
        uint256 totalSupply,
        uint256 pricePerShare,
        uint256 highWaterMark,
        uint8 decimals
    ) public pure {
        rate = bound(rate, 0, FeeLib.BPS_DIVIDER); // 0% to 100%
        totalSupply = bound(totalSupply, 0, type(uint128).max);
        decimals = uint8(bound(decimals, 0, 18));

        uint256 maxPrice = 10 ** (decimals + 10); // Reasonable max price
        pricePerShare = bound(pricePerShare, 0, maxPrice);
        highWaterMark = bound(highWaterMark, 0, maxPrice);

        uint256 performanceFee =
            FeeLib.calculatePerformanceFee(rate, totalSupply, pricePerShare, highWaterMark, decimals);

        // No fee if price <= high water mark
        if (pricePerShare <= highWaterMark) {
            assertEq(performanceFee, 0);
        }

        // No fee if rate is 0 or total supply is 0
        if (rate == 0 || totalSupply == 0) {
            assertEq(performanceFee, 0);
        }

        // Fee should be reasonable compared to profit
        if (pricePerShare > highWaterMark && totalSupply > 0 && decimals <= 18) {
            uint256 profitPerShare = pricePerShare - highWaterMark;
            // uint256 totalProfit = (profitPerShare * totalSupply) /
            //     (10 ** decimals);
            uint256 totalProfit = profitPerShare.mulDiv(totalSupply, 10 ** decimals, Math.Rounding.Ceil);

            // Performance fee should not exceed total profit
            if (totalProfit > 0) {
                assertLe(performanceFee, totalProfit);
            }
        }
    }

    // ====== ENTRY FEE TESTS ======

    function test_calculateEntryFees_zeroRate() public pure {
        uint256 rate = 0; // 0%
        uint256 assets = 1000e18;

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);

        assertEq(entryFee, 0);
    }

    function test_calculateEntryFees_zeroAssets() public pure {
        uint256 rate = 100; // 1%
        uint256 assets = 0;

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);

        assertEq(entryFee, 0);
    }

    function test_calculateEntryFees_normalCase() public pure {
        uint256 rate = 100; // 1%
        uint256 assets = 1000e18;

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);
        uint256 expectedFee = 10e18; // 1% of 1000 = 10

        assertEq(entryFee, expectedFee);
    }

    function test_calculateEntryFees_highRate() public pure {
        uint256 rate = 500; // 5%
        uint256 assets = 2000e18;

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);
        uint256 expectedFee = 100e18; // 5% of 2000 = 100

        assertEq(entryFee, expectedFee);
    }

    function test_calculateEntryFees_maxRate() public pure {
        uint256 rate = 10_000; // 100%
        uint256 assets = 1000e18;

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);
        uint256 expectedFee = 1000e18; // 100% of 1000 = 1000

        assertEq(entryFee, expectedFee);
    }

    function test_calculateEntryFees_smallAmounts() public pure {
        uint256 rate = 50; // 0.5%
        uint256 assets = 100; // Small amount without decimals

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);
        uint256 expectedFee = 1; // 0.5% of 100 = 0.5, rounded up to 1 due to Math.Rounding.Ceil

        assertEq(entryFee, expectedFee);
    }

    function test_calculateEntryFees_roundingUp() public pure {
        uint256 rate = 33; // 0.33%
        uint256 assets = 100; // This should result in 0.33, which rounds up to 1

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);

        // Expected: (100 * 33) / 10000 = 0.33, rounded up = 1
        assertEq(entryFee, 1);
    }

    function testFuzz_calculateEntryFees(
        uint256 rate,
        uint256 assets
    ) public pure {
        rate = bound(rate, 0, FeeLib.BPS_DIVIDER); // 0% to 100%
        assets = bound(assets, 0, type(uint128).max); // Reasonable asset range

        uint256 entryFee = FeeLib.calculateEntryFees(rate, assets);

        // Fee should never exceed the total assets
        assertLe(entryFee, assets);

        // If rate is 0 or assets is 0, fee should be 0
        if (rate == 0 || assets == 0) {
            assertEq(entryFee, 0);
        }

        // If rate is 100% (10000 bps), fee should equal assets
        if (rate == FeeLib.BPS_DIVIDER) {
            assertEq(entryFee, assets);
        }
    }
}
