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

    uint16 protocolFee = 1000;
    uint16 managementFee = 1000;
    uint16 performanceFee = 2000;
    uint16 entryFee = 1000;
    uint16 exitFee = 1000;

    function setUp() public {
        enableWhitelist = false;
        // 10% protocol fee
        // 10% management fee
        // 20% performance fee
        // 10% entry fee (new)
        // 0% exit fee (new)
        setUpVault(protocolFee, managementFee, performanceFee, entryFee, exitFee);

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

    function test_FeesAreTakenAfterFreeride_0() public {
        vault.activateWhitelist();
        address[] memory wl = new address[](3);
        wl[0] = user1.addr;
        wl[1] = user2.addr;
        wl[2] = vault.feeReceiver();
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(wl);
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
        vault.deposit(user1InitialDeposit - 1, user1.addr, user1.addr);

        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));

        assertEq(vault.lastFeeTime(), block.timestamp);
        assertEq(pricePerShare(), ppsAtStart);

        // user2 will deposit at 0.5$ per shares
        requestDeposit(user2InitialDeposit, user2.addr);
        // 1M * 0.1 = 100K entryfee

        // ------------ Settle ------------ //
        vm.warp(block.timestamp + 364 days);
        newTotalAssets = 5 * 10 ** (vault.underlyingDecimals() - 1);
        updateAndSettle(newTotalAssets);

        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
        vm.prank(user2.addr);
        vault.deposit(user2InitialDeposit, user2.addr, user2.addr);
        console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));

        assertApproxEqAbs(
            pricePerShare(),
            45 * 10 ** (vault.underlyingDecimals() - 2),
            1,
            "price per share didn't decreased as expected"
        );

        // Fee Calculations at Settlement:
        //
        // Entry Fees:
        //   user1: 1     * 0.1 = 0.1     entry fee → worth 0.05     at settlement
        //   user2: 1M    * 0.1 = 100K    entry fee → worth 100K     at settlement
        //
        // Management Fees:
        //   user1: 0.9   * 0.1 = 0.09    mgmt fee  → worth 0.045    at settlement
        //
        // Fee Distribution:
        //   Total fees    = 0.05 + 100K + 0.045 = 100,000.095
        //   Manager fee   = 100,000.095 * 0.9   =  90,000.0855
        //   Protocol fee  = 100,000.095 * 0.1   =  10,000.0095
        assertApproxEqAbs(
            vault.convertToAssets(vault.balanceOf(vault.feeReceiver())),
            900_000_855 * 10 ** (vault.underlyingDecimals() - 4),
            1,
            "feeReceiver received unexpected fee shares"
        );
        assertEq(
            vault.convertToAssets(vault.balanceOf(vault.protocolFeeReceiver())),
            100_000_095 * 10 ** (vault.underlyingDecimals() - 4),
            "protocol received unexpected fee shares"
        );

        // ------------ Settle ------------ //
        vm.warp(block.timestamp + 364 days);
        // vault price per share will increase from 0.45 -> 1.8 (x4)
        newTotalAssets = 4_000_002 * 10 ** vault.underlyingDecimals();
        console.log("totalSupply before", vault.totalSupply());
        console.log("totalAssets before", vault.totalAssets());
        console.log("hwm before", vault.highWaterMark());
        updateAndSettle(newTotalAssets);
        console.log("totalSupply after", vault.totalSupply());
        console.log("totalAssets after", vault.totalAssets());
        console.log("hwm after", vault.highWaterMark());

        // We expect the price per share to do be equal to:
        //
        //      mFees = totalAssets * 0.1                                                    (~400_000.2$)
        //      newPps = (totalAssets - mFees) / totalSupply                                 (~1.62000198$/share)
        //      pFees = (newPps - hwm) * totalSupply * 0.2                                   (~275556.24$)
        //      newShares = (mFees + pFees) * (totalSupply / (totalAssets - (mFees + pFees)))  (~451574.68 shares)
        //
        //      pps = totalAssets / (totalSupply + newShares) (~1.496)
        //
        assertApproxEqAbs(
            pricePerShare(),
            1496 * 10 ** (vault.underlyingDecimals() - 3),
            5, // rounding approximation
            "Price per share didn't increased as expected"
        );

        // We expect the highWaterMark to be equal to the price per share
        assertApproxEqAbs(
            vault.highWaterMark(),
            vault.pricePerShare(),
            5, // rounding approximation
            "Highwater mark shoudn't have been raised"
        );

        uint256 user1ShareBalance = vault.balanceOf(user1.addr);
        uint256 user2ShareBalance = vault.balanceOf(user2.addr);

        // ------------ Settle ------------ //

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

        requestRedeem(user1ShareBalance, user1.addr);
        requestRedeem(user2ShareBalance, user2.addr);

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
        // uint256 user2AssetAfter = redeem(user2ShareBalance, user2.addr);
        uint40 user2LastRequestId = vault.lastRedeemRequestId(user2.addr);
        uint256 user2AssetsToWithdraw = vault.convertToAssets(user2ShareBalance, user2LastRequestId);

        user2AssetsToWithdraw -= FeeLib.computeFee(
            user2AssetsToWithdraw, vault.getSettlementExitFeeRate(user2LastRequestId)
        );
        uint256 shares = withdraw(user2AssetsToWithdraw, user2.addr);
        uint256 user2AssetAfter = vault.convertToAssets(shares, user2LastRequestId);

        assetBalance(user1.addr);
        assetBalance(user2.addr);

        uint256 user1Profit = (user1AssetAfter - user1AssetBefore) - user1InitialDeposit;
        uint256 user2Profit = (user2AssetAfter - user2AssetBefore) - user2InitialDeposit;

        // User Position Evolution:
        // ════════════════════════════════════════════════════════════════════════════════════════
        // Initial deposit                    1.000000
        // Entry fees (10%)                  -0.100000  →  0.900000
        // -- 1 year gap --
        // Management fees (10%)             -0.045000  →  0.405000  (0.450000 * 0.1 = 0.045000)
        // -- 1 year gap --
        // Management fees (10%)             -0.162000  →  1.458000  (1.620000 * 0.1 = 0.162000)
        // Performance fees (20%)            -0.111600  →  1.346400  ((1.62 - 0.162 - 0.9) * 0.2)
        // -- 1 year gap --
        // Management fees (10%)             -0.134640  →  1.211760  (1.346400 * 0.1 = 0.134640)
        // Exit fees (10%)                   -0.121176  →  1.090584  (1.211760 * 0.1 = 0.121176)
        // ════════════════════════════════════════════════════════════════════════════════════════
        // Final Position: 1.090584
        uint256 expectedUser1Profit = 90_584 * 10 ** (vault.underlyingDecimals() - 6);

        assertApproxEqAbs(user1Profit, expectedUser1Profit, 5, "user1 expected profit is wrong");

        // User Position Evolution:
        // ════════════════════════════════════════════════════════════════════════════════════════
        // Initial deposit                    1,000,000
        // Entry fees (10%)                    -100,000  →    900,000
        // -- 1 year gap --
        // Management fees (10%)               -360,000  →  2,992,000  (3,600,000 * 0.1 = 360,000)
        // Performance fees (20%)              -248,000  →  2,992,000  ((3,600,000 - 360,000 - 2,000,000) * 0.2)
        // -- 1 year gap --
        // Management fees (10%)               -299,200  →  2,692,800  (2,992,000 * 0.1 = 299,200)
        // Exit fees (10%)                     -269,280  →  2,423,520  (2,692,800 * 0.1 = 269,280)
        // ════════════════════════════════════════════════════════════════════════════════════════
        // Final Position: 2,423,520
        uint256 expectedUser2Profit = 1_423_520 * 10 ** vault.underlyingDecimals();

        assertApproxEqAbs(
            user2Profit, expectedUser2Profit, 10 ** (vault.underlyingDecimals() + 1), "user2 expected profit is wrong"
        );

        // expectedTotalFees = (totalAssets - (deposit1 + profit1 + deposit2 + profit2)) * (1 - exitFees)
        //                   = (4_000_002 - (1 + 0.09584 + 1_000_000 + 1_423_520)) * 0.9
        //                   = ~1_576_480.9$ * 0.9
        //                   = ~1_418_832.81$
        uint256 expectedTotalFees = 1_418_833_000 * 10 ** (vault.underlyingDecimals() - 3);

        address feeReceiver = vault.feeReceiver();
        address dao = vault.protocolFeeReceiver();

        uint256 feeReceiverShareBalance = vault.balanceOf(feeReceiver);
        uint256 daoShareBalance = vault.balanceOf(dao);

        assertApproxEqAbs(
            pricePerShare(),
            13_464 * 10 ** (vault.underlyingDecimals() - 4),
            5, // rounding approximation
            "Price per share didn't decreased as expected"
        );

        requestRedeem(feeReceiverShareBalance, feeReceiver);
        requestRedeem(daoShareBalance, dao);

        // ------------ Settle ------------ //
        console.log("total assets", vault.totalAssets());
        updateNewTotalAssets(vault.totalAssets());
        settle();

        uint256 feeReceiverAssetAfter = redeem(feeReceiverShareBalance, feeReceiver);
        uint256 daoAssetAfter = redeem(daoShareBalance, dao);

        uint256 totalFees = feeReceiverAssetAfter + daoAssetAfter;

        assertApproxEqAbs(totalFees, expectedTotalFees, 5 * 10 ** vault.underlyingDecimals(), "wrong total Fees");
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
        uint40 user2LastRequestId = vault.lastDepositRequestId(user1.addr);
        console.log("-----user1LastRequestId", user2LastRequestId);
        console.log("-----historical entryFeeRate", vault.getSettlementEntryFeeRate(user2LastRequestId));
        console.log("-----current entryFeeRate", vault.entryRate());
        uint256 shares = vault.convertToShares(
            balance - FeeLib.computeFee(balance, vault.getSettlementEntryFeeRate(user2LastRequestId))
        );
        mint(shares, user2.addr);
        ////

        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Shares = vault.balanceOf(user2.addr);

        requestRedeem(user1Shares, user1.addr);
        requestRedeem(user2Shares, user2.addr);

        vm.warp(block.timestamp + 364 days);
        updateAndSettleRedeem(4 * balance);

        redeem(user1Shares, user1.addr);
        redeem(user2Shares, user2.addr);

        uint256 balance1After = assetBalance(user1.addr);
        uint256 balance2After = assetBalance(user2.addr);
        uint256 amSharesBalance = vault.balanceOf(feeReceiver.addr);
        uint256 daoSharesBalance = vault.balanceOf(dao.addr);

        // User Position Evolution:
        // ════════════════════════════════════════════════════════════════════
        // Initial Investment      100.0
        // Entry Fees (10%)       -10.0  →   90.0
        // Valorisation (2x)       90.0  →  180.0
        // Management Fees (10%)  -18.0  →  162.0
        // Performance Fees (20%) -14.4  →  147.6
        // Exit Fees (10%)        -14.76  →   132.84
        // ════════════════════════════════════════════════════════════════════
        // Final Position: 132.84
        uint256 user1Profit = 32_840 * 10 ** vault.underlyingDecimals();
        uint256 user2Profit = 32_840 * 10 ** vault.underlyingDecimals();

        // AM Position Evolution:
        // ════════════════════════════════════════════════════════════════════
        // Initial Investment      0
        // User's Fees            +134.32 →  134.32
        // Protocol Fees (10%)    -13.432  →  120.888
        // ════════════════════════════════════════════════════════════════════
        // Final Position: 120.888
        uint256 amProfit = vault.convertToShares(120_888 * 10 ** vault.underlyingDecimals());
        // Protocol Position Evolution:
        // ════════════════════════════════════════════════════════════════════
        // Initial Investment      0
        // Protocol Fees (10%)    +13.432  →  13.432
        // ════════════════════════════════════════════════════════════════════
        // Final Position: 13.432
        uint256 daoProfit = vault.convertToShares(13_432 * 10 ** vault.underlyingDecimals());

        assertApproxEqAbs(balance1After - balance1Before, user1Profit, 100_000, "unexpected balance 1");
        assertApproxEqAbs(balance2After - balance2Before, user2Profit, 100_000, "unexpected balance 2");
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
        vm.prank(vault.owner());
        vault.initiateClosing();
        updateAndClose(4 * balance);

        redeem(user1Shares, user1.addr);
        uint256 user2AssetsToWithdraw = vault.convertToAssets(user2Shares);
        // user2AssetsToWithdraw -= FeeLib.computeFee(user2AssetsToWithdraw, vault.exitRate());
        withdraw(user2AssetsToWithdraw, user2.addr);

        uint256 balance1After = assetBalance(user1.addr);
        uint256 balance2After = assetBalance(user2.addr);
        uint256 amSharesBalance = vault.balanceOf(feeReceiver.addr);
        uint256 daoSharesBalance = vault.balanceOf(dao.addr);

        // User Position Evolution:
        // ════════════════════════════════════════════════════════════════════
        // Initial Investment      100.0
        // Entry Fees (10%)       -10.0  →   90.0
        // Valorisation (2x)       90.0  →  180.0
        // Management Fees (10%)  -18.0  →  162.0
        // Performance Fees (20%) -14.4  →  147.6
        // Exit Fees (10%)        -14.76  →   132.84
        // ════════════════════════════════════════════════════════════════════
        // Final Position: 132.84
        uint256 user1Profit = 32_840 * 10 ** vault.underlyingDecimals();
        uint256 user2Profit = 32_840 * 10 ** vault.underlyingDecimals();

        // AM Position Evolution:
        // ════════════════════════════════════════════════════════════════════
        // Initial Investment      0
        // User's Fees            +134.32 →  134.32
        // Protocol Fees (10%)    -13.432  →  120.888
        // ════════════════════════════════════════════════════════════════════
        // Final Position: 120.888
        uint256 amProfit = vault.convertToShares(120_888 * 10 ** vault.underlyingDecimals());
        // Protocol Position Evolution:
        // ════════════════════════════════════════════════════════════════════
        // Initial Investment      0
        // Protocol Fees (10%)    +13.432  →  13.432
        // ════════════════════════════════════════════════════════════════════
        // Final Position: 13.432
        uint256 daoProfit = vault.convertToShares(13_432 * 10 ** vault.underlyingDecimals());

        assertApproxEqAbs(
            assetBalance(address(vault)),
            134_320 * 10 ** vault.underlyingDecimals(),
            100_000,
            "wrong vault asset balance"
        );

        assertApproxEqAbs(balance1After - balance1Before, user1Profit, 100_000, "user1: wrong profits");
        assertApproxEqAbs(balance2After - balance2Before, user2Profit, 100_000, "user2: wrong profits");
        assertApproxEqAbs(amSharesBalance, amProfit, vault.convertToShares(100_000), "am: wrong profits");
        assertApproxEqAbs(daoSharesBalance, daoProfit, vault.convertToShares(100_000), "dao: wrong profits");
    }

    function test_NoFeesAreTakenDuringFreeRide() public {
        Rates memory rates = Rates(0, 2000, 0, 0);
        vm.prank(vault.owner());
        vault.updateRates(rates);
        uint256 newTotalAssets = 0;

        // new airdrop !
        dealAmountAndApproveAndWhitelist(user1.addr, _1);
        dealAmountAndApproveAndWhitelist(user2.addr, _1M);

        uint256 ppsAtStart = pricePerShare();

        uint256 user1InitialDeposit = _1;
        uint256 user2InitialDeposit = _1M;

        // user1 deposit into vault at 1$ per share
        requestDeposit(user1InitialDeposit, user1.addr);

        console.log("======");
        console.log("totalSupply        :", vault.totalSupply());
        console.log("totalAssets        :", vault.totalAssets());
        console.log("price per share    :", vault.pricePerShare());
        console.log("hwm                :", vault.highWaterMark());
        console.log("------");
        console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
        console.log("shares user1       :", vault.balanceOf(user1.addr));
        console.log("shares user2       :", vault.balanceOf(user2.addr));
        console.log("------");
        console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
        console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
        console.log("======");
        // ------------ Settle ------------ //
        updateAndSettle(newTotalAssets);
        console.log("======");
        console.log("totalSupply        :", vault.totalSupply());
        console.log("totalAssets        :", vault.totalAssets());
        console.log("price per share    :", vault.pricePerShare());
        console.log("hwm                :", vault.highWaterMark());
        console.log("------");
        console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
        console.log("shares user1       :", vault.balanceOf(user1.addr));
        console.log("shares user2       :", vault.balanceOf(user2.addr));
        console.log("------");
        console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
        console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
        console.log("======");

        vm.prank(user1.addr);
        vault.deposit(user1InitialDeposit, user1.addr, user1.addr);

        assertEq(vault.lastFeeTime(), block.timestamp);
        assertEq(pricePerShare(), ppsAtStart);

        // user2 will deposit at 0.5$ per shares
        requestDeposit(user2InitialDeposit, user2.addr);

        // ------------ Settle ------------ //
        newTotalAssets = 5 * 10 ** (vault.underlyingDecimals() - 1);
        updateAndSettle(newTotalAssets);
        console.log("======");
        console.log("totalSupply        :", vault.totalSupply());
        console.log("totalAssets        :", vault.totalAssets());
        console.log("price per share    :", vault.pricePerShare());
        console.log("hwm                :", vault.highWaterMark());
        console.log("------");
        console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
        console.log("shares user1       :", vault.balanceOf(user1.addr));
        console.log("shares user2       :", vault.balanceOf(user2.addr));
        console.log("------");
        console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
        console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
        console.log("======");

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
        newTotalAssets =
            (vault.highWaterMark() * (vault.totalSupply() + 1 * vault.decimalsOffset())) / 10 ** vault.decimals();
        console.log("HERE newtotalasset", newTotalAssets);
        // newTotalAssets = 2_000_001 * 10 ** vault.underlyingDecimals(); // vault
        // valo made a x2 for user2; and x1 for
        // user1
        updateAndSettle(newTotalAssets);
        console.log("======");
        console.log("totalSupply        :", vault.totalSupply());
        console.log("totalAssets        :", vault.totalAssets());
        console.log("price per share    :", vault.pricePerShare());
        console.log("hwm                :", vault.highWaterMark());
        console.log("------");
        console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
        console.log("shares user1       :", vault.balanceOf(user1.addr));
        console.log("shares user2       :", vault.balanceOf(user2.addr));
        console.log("------");
        console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
        console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
        console.log("------");
        console.log("underlying decimals :", vault.underlyingDecimals());
        console.log("decimals            :", vault.decimals());
        console.log("decimals     offset :", vault.decimalsOffset());
        console.log("======");

        // We expect the price per share to do be equal to be 1 again
        assertApproxEqAbs(
            vault.pricePerShare(),
            1 * 10 ** vault.underlyingDecimals(),
            1, // rounding approximation
            "Wrong price per share"
        );

        assertApproxEqAbs(
            vault.highWaterMark(),
            pricePerShare(),
            1, // rounding approximation
            "Highwater mark hasn't been raised at expected price per share"
        );

        uint256 user1ShareBalance = vault.balanceOf(user1.addr);
        uint256 user2ShareBalance = vault.balanceOf(user2.addr);

        requestRedeem(user1ShareBalance, user1.addr);
        requestRedeem(user2ShareBalance, user2.addr);

        // ------------ Settle ------------ //
        console.log("======");
        console.log("totalSupply        :", vault.totalSupply());
        console.log("totalAssets        :", vault.totalAssets());
        console.log("price per share    :", vault.pricePerShare());
        console.log("hwm                :", vault.highWaterMark());
        console.log("------");
        console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
        console.log("shares user1       :", vault.balanceOf(user1.addr));
        console.log("shares user2       :", vault.balanceOf(user2.addr));
        console.log("------");
        console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
        console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
        console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
        console.log("======");
        updateAndSettle(newTotalAssets);

        // uint256 user1AssetBefore = assetBalance(user1.addr);
        uint256 user2AssetBefore = assetBalance(user2.addr);

        // exit fees are set to 0, we would have to account them otherwise
        uint256 user1AssetsToWithdraw = vault.convertToAssets(user1ShareBalance, vault.lastRedeemRequestId(user1.addr));
        uint256 shares = withdraw(user1AssetsToWithdraw, user1.addr);
        // uint256 user1AssetAfter = redeem(user1ShareBalance, user1.addr);
        uint256 user1AssetAfter = vault.convertToAssets(shares);
        uint256 user2AssetAfter = redeem(user2ShareBalance, user2.addr);

        // assetBalance(user1.addr);
        // assetBalance(user2.addr);

        uint256 user2Profit = (user2AssetAfter - user2AssetBefore) - user2InitialDeposit;

        // Valo at totalAssets update
        // 0.5$       => pps = 0.5
        // 1.0$       => pps = 1.0 (no fees taken since we are back to the intial price per share)
        assertApproxEqAbs(user1AssetAfter, 10 ** vault.underlyingDecimals(), 5, "user1 expected profit is wrong");

        // Valo at totalAssets update
        // 1M$       => pps = 0.5
        // 2M$       => pps = 1.0 (user2 makes 1M profit without paying any fees)
        uint256 freeride = user2InitialDeposit;

        assertApproxEqAbs(user2Profit, freeride, 5 * 10 ** vault.underlyingDecimals(), "user2 expected profit is wrong");

        assertEq(vault.balanceOf(vault.feeReceiver()), 0, "feeReceiver received unexpected fee shares");
        assertEq(vault.balanceOf(vault.protocolFeeReceiver()), 0, "protocol received unexpected fee shares");
    }

    function test_updateRates_revertIfManagementRateAboveMaxRates() public {
        uint16 MAX_MANAGEMENT_RATE = vault.MAX_MANAGEMENT_RATE();
        uint16 MAX_PERFORMANCE_RATE = vault.MAX_PERFORMANCE_RATE();

        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE + 1,
            performanceRate: MAX_PERFORMANCE_RATE - 1,
            entryRate: 0,
            exitRate: 0
        });

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

        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE - 1,
            performanceRate: MAX_PERFORMANCE_RATE + 1,
            entryRate: 0,
            exitRate: 0
        });

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
        vault.settleDeposit(vault.newTotalAssets());

        vm.expectRevert(abi.encodeWithSelector(NewTotalAssetsMissing.selector));
        vault.settleDeposit(1);
        vm.stopPrank();

        vm.prank(vault.safe());
        vm.expectRevert(abi.encodeWithSelector(NewTotalAssetsMissing.selector));
        vault.settleRedeem(1);

        vm.prank(vault.owner());
        vault.initiateClosing();

        vm.prank(vault.safe());
        vm.expectRevert(abi.encodeWithSelector(NewTotalAssetsMissing.selector));
        vault.close(1);
    }
}
