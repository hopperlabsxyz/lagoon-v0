// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
        enableWhitelist = false;
        // 10%  protocol fee
        // 10% management fee
        // 20% performance fee
        setUpVault(1000, 1000, 2000);

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
        dealAmountAndApproveAndWhitelist(user1.addr, _1);
        dealAmountAndApproveAndWhitelist(user2.addr, _1M);

        uint256 ppsAtStart = pricePerShare();

        uint256 user1InitialDeposit = _1;
        uint256 user2InitialDeposit = _1M;

        // user1 deposit into vault at 1$ per share
        // console.log("user1InitialDeposit", user1InitialDeposit, assetBalance(user1.addr));
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
        vm.warp(block.timestamp + 364 days);
        newTotalAssets = 5 * 10 ** (vault.underlyingDecimals() - 1);
        updateAndSettle(newTotalAssets);

        vm.prank(user2.addr);
        vault.deposit(user2InitialDeposit, user2.addr, user2.addr);

        // Only management fees should be charged to user1 because pps have decreased from 1 to 0.5 (with 10%
        // management fee it goes to 0.45) and therefore do not exceed the highWaterMark of 1
        assertEq(
            pricePerShare(), 45 * 10 ** (vault.underlyingDecimals() - 2), "price per share didn't decreased as expected"
        );
        // The assets manager is supposed to take 10% off what all users old before new request deposit are taken into
        // account.
        // Here only user1 is in the vault holding 1 share that worth 0.45$ after taking the fees so the asset manager
        // is supposed to hold some shares that worth 0.05$ - protocol fees.
        assertApproxEqAbs(
            vault.convertToAssets(vault.balanceOf(vault.feeReceiver())),
            45 * 10 ** (vault.underlyingDecimals() - 3),
            1,
            "feeReceiver received unexpected fee shares"
        );
        // There is also 10% protocol fees taken by the protocol. So the asset manager is only receiving ~0.045$ worth
        // of share and the protocol ~0.005$.
        assertEq(
            vault.convertToAssets(vault.balanceOf(vault.protocolFeeReceiver())),
            5 * 10 ** (vault.underlyingDecimals() - 3),
            "protocol received unexpected fee shares"
        );

        // ------------ Settle ------------ //
        vm.warp(block.timestamp + 364 days);
        // vault price per share will increase from 0.45 -> 1.8 (x4 for user2; x1.8 for user1)
        newTotalAssets = 4_000_002 * 10 ** vault.underlyingDecimals();
        updateAndSettle(newTotalAssets);

        // We expect the price per share to do be equal to:
        //
        //      mFees = totalAssets * 0.1                                                    (~400_000.2$)
        //      pFees = (pps - hwm) * totalSupply * 0.2                                      (~355_555.3$)
        //      newShares = (mFees + pFees) * (totalSupply / (totalAssets - mFees + pFees))  (~517503.1 shares)
        //
        //      pps = totalAssets / (totalSupply + newShares) (~1.46)
        //
        assertApproxEqAbs(
            pricePerShare(),
            1460 * 10 ** (vault.underlyingDecimals() - 3),
            5, // rounding approximation
            "Price per share didn't increased as expected"
        );

        // We expect the highWaterMark to be ~1.8$ per share
        assertApproxEqAbs(
            vault.highWaterMark(),
            18 * 10 ** (vault.underlyingDecimals() - 1),
            5, // rounding approximation
            "Highwater mark hasn't been raised at expected price per share"
        );

        uint256 user1ShareBalance = vault.balanceOf(user1.addr);
        uint256 user2ShareBalance = vault.balanceOf(user2.addr);

        requestRedeem(user1ShareBalance, user1.addr);
        requestRedeem(user2ShareBalance, user2.addr);

        // ------------ Settle ------------ //
        vm.warp(block.timestamp + 364 days);
        updateAndSettle(newTotalAssets);

        console.log("======");
        console.log("totalSupply        :", vault.totalSupply());
        console.log("totalAssets        :", vault.totalAssets());
        console.log("price per share    :", vault.pricePerShare());
        console.log("------");
        console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
        console.log("shares user1       :", vault.balanceOf(user1.addr));
        console.log("shares user2       :", vault.balanceOf(user2.addr));
        console.log("------");
        console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
        console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
        console.log("======");

        uint256 user1AssetBefore = assetBalance(user1.addr);
        uint256 user2AssetBefore = assetBalance(user2.addr);

        uint256 user1AssetAfter = redeem(user1ShareBalance, user1.addr);
        uint256 user2AssetAfter = redeem(user2ShareBalance, user2.addr);

        assetBalance(user1.addr);
        assetBalance(user2.addr);

        uint256 user1Profit = (user1AssetAfter - user1AssetBefore) - user1InitialDeposit;
        uint256 user2Profit = (user2AssetAfter - user2AssetBefore) - user2InitialDeposit;

        // Initial deposit
        // -- 1 year gap --
        // 0.500 => 0.450 (10% mFees taken = 0.05)
        // -- 1 year gap --
        // 1.800 => 1.460 (20% pFees + 10% mFees = (1.8 - 1) * 0.2 + 1.8 * 0.1 = 0.16 + 0.18 = 0.34)
        // -- 1 year gap --
        // 1.460 =>  1.314 (10% mFees =  1.46 * 0.1 = 0.146)
        //
        // totalFees = 1 * (0.05 + 0.1 + (0.8 * 0.2 / 1.8) + (1.46  * 0.1)/ 1.8) = 0.32
        // profit = (initialDeposit -  pps) = 1$ - 1 * 1.314 = 0.314
        uint256 expectedUser1Profit = 314 * 10 ** (vault.underlyingDecimals() - 3);

        assertApproxEqAbs(user1Profit, expectedUser1Profit, 5, "user1 expected profit is wrong");

        // Initial deposit
        // -- 1 year gap --
        // 0.500 => 0.450 (no fees taken)
        // -- 1 year gap --
        // 1.800 => 1.460 (20% pFees + 10% mFees = (1.8 - 1) * 0.2 + 1.8 * 0.1 = 0.16 + 0.18 = 0.34)
        // -- 1 year gap --
        // 1.460 =>  1.314 (10% mFees =  1.46 * 0.1 = 0.146)
        //
        // totalFees = 4_000_000 * (0.1 + (0.8 * 0.2 * / 1.8) + (1.46 *  0.1)/ 1.8) = 1_080_000
        // profit = 3M - 1_080_000 = 1_920_000
        uint256 expectedUser2Profit = 1_920_000 * 10 ** vault.underlyingDecimals();

        assertApproxEqAbs(
            user2Profit, expectedUser2Profit, 10 ** vault.underlyingDecimals(), "user2 expected profit is wrong"
        );
        // expectedTotalFees = 1_080_000 + 0.32 = 1_920_000.314
        uint256 expectedTotalFees = 1_080_000_320 * 10 ** (vault.underlyingDecimals() - 3);

        address feeReceiver = vault.feeReceiver();
        address dao = vault.protocolFeeReceiver();

        uint256 feeReceiverShareBalance = vault.balanceOf(feeReceiver);
        uint256 daoShareBalance = vault.balanceOf(dao);

        requestRedeem(feeReceiverShareBalance, feeReceiver);
        requestRedeem(daoShareBalance, dao);

        // // ------------ Settle ------------ //
        updateNewTotalAssets(vault.totalAssets());
        settle();

        uint256 feeReceiverAssetAfter = redeem(feeReceiverShareBalance, feeReceiver);
        uint256 daoAssetAfter = redeem(daoShareBalance, dao);

        uint256 totalFees = feeReceiverAssetAfter + daoAssetAfter;

        assertApproxEqAbs(totalFees, expectedTotalFees, 10 ** vault.underlyingDecimals(), "wrong total Fees");
    }

    function test_SettleRedeemTakesCorrectAmountOfFees() public {
        // setup
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        uint256 balance1Before = assetBalance(user1.addr);
        uint256 balance2Before = assetBalance(user2.addr);
        uint256 balance = assetBalance(user1.addr);
        requestDeposit(balance, user1.addr);
        requestDeposit(balance, user2.addr);
        updateAndSettle(0);
        deposit(balance, user1.addr);
        deposit(balance, user2.addr);
        ////

        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Shares = vault.balanceOf(user2.addr);

        requestRedeem(user1Shares, user1.addr);
        requestRedeem(user2Shares, user2.addr);

        vm.warp(block.timestamp + 364 days);
        // the asset manager takes 10% management fees + 20% performance fees
        // vault valo went from 200K (pps = 1) to 400K (pps = 2)
        // totalFees = 400K * 10% + [(400K - 200K) * 20%] = 80K
        updateAndSettleRedeem(4 * balance);

        redeem(user1Shares, user1.addr);
        redeem(user2Shares, user2.addr);

        uint256 balance1After = assetBalance(user1.addr);
        uint256 balance2After = assetBalance(user2.addr);
        uint256 amSharesBalance = vault.balanceOf(feeReceiver.addr);
        uint256 daoSharesBalance = vault.balanceOf(dao.addr);

        uint256 user1Profit = 60_000 * 10 ** vault.underlyingDecimals();
        uint256 user2Profit = 60_000 * 10 ** vault.underlyingDecimals();
        uint256 amProfit = vault.convertToShares(72_000 * 10 ** vault.underlyingDecimals());
        uint256 daoProfit = vault.convertToShares(8000 * 10 ** vault.underlyingDecimals());

        assertApproxEqAbs(balance1After - balance1Before, user1Profit, 100_000);
        assertApproxEqAbs(balance2After - balance2Before, user2Profit, 100_000);
        assertApproxEqAbs(amSharesBalance, amProfit, vault.convertToShares(100_000), "am: wrong profits");
        assertApproxEqAbs(daoSharesBalance, daoProfit, vault.convertToShares(100_000), "dao: wrong profits");
    }

    function test_CloseTakesCorrectAmountOfFees() public {
        // setup
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        uint256 balance1Before = assetBalance(user1.addr);
        uint256 balance2Before = assetBalance(user2.addr);
        uint256 balance = assetBalance(user1.addr);
        requestDeposit(balance, user1.addr);
        requestDeposit(balance, user2.addr);
        updateAndSettle(0);
        deposit(balance, user1.addr);
        deposit(balance, user2.addr);
        ////

        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Shares = vault.balanceOf(user2.addr);

        vm.warp(block.timestamp + 364 days);
        // the asset manager takes 10% management fees + 20% performance fees
        // vault valo went from 200K (pps = 1) to 400K (pps = 2)
        // totalFees = 400K * 10% + [(400K - 200K) * 20%] = 80K
        vm.prank(vault.owner());
        vault.initiateClosing();
        updateAndClose(4 * balance);

        redeem(user1Shares, user1.addr);
        redeem(user2Shares, user2.addr);

        uint256 balance1After = assetBalance(user1.addr);
        uint256 balance2After = assetBalance(user2.addr);
        uint256 amSharesBalance = vault.balanceOf(feeReceiver.addr);
        uint256 daoSharesBalance = vault.balanceOf(dao.addr);

        uint256 user1Profit = 60_000 * 10 ** vault.underlyingDecimals();
        uint256 user2Profit = 60_000 * 10 ** vault.underlyingDecimals();
        uint256 amProfit = vault.convertToShares(72_000 * 10 ** vault.underlyingDecimals());
        uint256 daoProfit = vault.convertToShares(8000 * 10 ** vault.underlyingDecimals());

        assertApproxEqAbs(
            assetBalance(address(vault)),
            80_000 * 10 ** vault.underlyingDecimals(),
            100_000,
            "wrong vault asset balance"
        );

        assertApproxEqAbs(balance1After - balance1Before, user1Profit, 100_000, "user1: wrong profits");
        assertApproxEqAbs(balance2After - balance2Before, user2Profit, 100_000, "user2: wrong profits");
        assertApproxEqAbs(amSharesBalance, amProfit, vault.convertToShares(100_000), "am: wrong profits");
        assertApproxEqAbs(daoSharesBalance, daoProfit, vault.convertToShares(100_000), "dao: wrong profits");
    }

    function test_NoFeesAreTakenDuringFreeRide() public {
        Rates memory rates = Rates(0, 2000);
        vm.prank(vault.owner());
        vault.updateRates(rates);
        uint256 newTotalAssets = 0;

        // new airdrop !
        dealAmountAndApproveAndWhitelist(user1.addr, _1);
        dealAmountAndApproveAndWhitelist(user2.addr, _1M);

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

    function test_takeFees_cantBeCalledMultipleTimes() public {
        updateNewTotalAssets(0);

        vm.startPrank(safe.addr);
        vault.settleDeposit();

        vm.expectRevert(abi.encodeWithSelector(NewTotalAssetsMissing.selector));
        vault.settleDeposit();
        vm.stopPrank();

        vm.prank(vault.safe());
        vm.expectRevert(abi.encodeWithSelector(NewTotalAssetsMissing.selector));
        vault.settleRedeem();

        vm.prank(vault.owner());
        vault.initiateClosing();

        vm.prank(vault.safe());
        vm.expectRevert(abi.encodeWithSelector(NewTotalAssetsMissing.selector));
        vault.close();
    }
}
