// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessMode} from "@src/v0.6.0/primitives/Enums.sol";
import {HighWaterMarkResetNotAllowed, OnlySafe} from "@src/v0.6.0/primitives/Errors.sol";
import {HighWaterMarkUpdated} from "@src/v0.6.0/primitives/Events.sol";
import {InitStruct} from "@src/v0.6.0/vault/Vault-v0.6.0.sol";

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
    uint16 entryFee = 100;
    uint16 exitFee = 100;

    function setUp() public {
        enableWhitelist = false;
        // 10% protocol fee
        // 10% management fee
        // 20% performance fee
        // 1% entry fee (new)
        // 1% exit fee (new)
        setUpVault({
            _protocolRate: protocolFee,
            _managementRate: managementFee,
            _performanceRate: performanceFee,
            _entryRate: entryFee,
            _exitRate: exitFee
        });

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

    function test_firstSettleDeposit_afterPremint_takesNoFees() public {
        // Deploy a new vault with an initial premint
        uint256 initialAssets = 1000 * 10 ** underlying.decimals();

        InitStruct memory initStruct = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: managementFee,
            performanceRate: performanceFee,
            accessMode: AccessMode.Blacklist,
            entryRate: entryFee,
            exitRate: exitFee,
            haircutRate: 0,
            securityCouncil: admin.addr,
            externalSanctionsList: address(0),
            initialTotalAssets: initialAssets,
            superOperator: superOperator.addr,
            allowHighWaterMarkReset: false
        });

        VaultHelper newVault = new VaultHelper(false);
        newVault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);

        // Use the newly deployed vault for the rest of the test
        vault = newVault;

        // Sanity checks: premint set totalAssets/totalSupply and no fee shares
        assertEq(vault.totalAssets(), initialAssets, "premint should set totalAssets");
        uint256 expectedShares = vault.convertToSharesWithRounding(initialAssets, Math.Rounding.Floor);
        assertEq(vault.totalSupply(), expectedShares, "premint should mint shares to safe");
        assertEq(vault.balanceOf(vault.feeReceiver()), 0, "manager should have 0 shares after premint");
        assertEq(vault.balanceOf(vault.protocolFeeReceiver()), 0, "protocol should have 0 shares after premint");

        uint256 feeReceiverSharesBefore = vault.balanceOf(vault.feeReceiver());
        uint256 protocolSharesBefore = vault.balanceOf(vault.protocolFeeReceiver());
        uint256 lastFeeTimeBefore = vault.lastFeeTime();
        uint256 highWaterMarkBefore = vault.highWaterMark();

        // First valuation equal to current total assets, then first settleDeposit
        uint256 newTotalAssets = vault.totalAssets();
        vm.prank(valuationManager.addr);
        vault.updateNewTotalAssets(newTotalAssets);

        vm.prank(safe.addr);
        vault.settleDeposit(newTotalAssets);

        // No fees should be taken at the first settleDeposit even if a premint happened
        assertEq(
            vault.balanceOf(vault.feeReceiver()),
            feeReceiverSharesBefore,
            "feeReceiver should not receive fees on first settle after premint"
        );
        assertEq(
            vault.balanceOf(vault.protocolFeeReceiver()),
            protocolSharesBefore,
            "protocol should not receive fees on first settle after premint"
        );

        // lastFeeTime must be initialized and highWaterMark should not change on flat price per share
        assertEq(vault.highWaterMark(), highWaterMarkBefore, "highWaterMark should not change on flat pps");
    }

    // function test_FeesAreTakenAfterFreeride_0() public {
    //     vault.activateWhitelist();
    //     address[] memory wl = new address[](3);
    //     wl[0] = user1.addr;
    //     wl[1] = user2.addr;
    //     wl[2] = vault.feeReceiver();
    //     vm.prank(vault.whitelistManager());
    //     vault.addToWhitelist(wl);
    //     uint256 newTotalAssets = 0;

    //     // new airdrop !
    //     dealAmountAndApproveAndWhitelist(user1.addr, _1);
    //     dealAmountAndApproveAndWhitelist(user2.addr, _1M);

    //     uint256 ppsAtStart = pricePerShare();

    //     uint256 user1InitialDeposit = _1;
    //     uint256 user2InitialDeposit = _1M;

    //     // user1 deposit into vault at 1$ per share
    //     // console.log("user1InitialDeposit", user1InitialDeposit, assetBalance(user1.addr));
    //     requestDeposit(user1InitialDeposit, user1.addr);

    //     // ------------ Settle ------------ //
    //     updateAndSettle(newTotalAssets);

    //     vm.prank(user1.addr);
    //     vault.deposit(user1InitialDeposit - 1, user1.addr, user1.addr);

    //     console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));

    //     assertEq(vault.lastFeeTime(), block.timestamp);
    //     assertEq(pricePerShare(), ppsAtStart);

    //     // user2 will deposit at 0.5$ per shares
    //     requestDeposit(user2InitialDeposit, user2.addr);
    //     // 1M * 0.1 = 100K entryfee

    //     // ------------ Settle ------------ //
    //     vm.warp(block.timestamp + 364 days);
    //     newTotalAssets = 5 * 10 ** (vault.underlyingDecimals() - 1);
    //     updateAndSettle(newTotalAssets);

    //     console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
    //     vm.prank(user2.addr);
    //     vault.deposit(user2InitialDeposit, user2.addr, user2.addr);
    //     console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));

    //     assertApproxEqAbs(
    //         pricePerShare(),
    //         425 * 10 ** (vault.underlyingDecimals() - 3),
    //         1,
    //         "price per share didn't decreased as expected"
    //     );

    //     // Fee Calculations at Settlement:
    //     //
    //     // Entry Fees:
    //     //   user1: 1     * 0.1 = 0.1     entry fee → worth 0.0425    at settlement (PPS = 0.425)
    //     //   user2: 1M    * 0.1 = 100K    entry fee → worth 100K      at settlement
    //     //
    //     // Management Fees (using average of previous and current totalAssets):
    //     //   avg(1, 0.5) * 0.1 = 0.075    mgmt fee  → worth 0.0675    at settlement (user1 share: 0.9/1.0)
    //     //
    //     // Fee Distribution:
    //     //   Total fees    = 0.0425 + 100K + 0.0675 = 100,000.11
    //     //   Manager fee   = 100,000.11 * 0.9      =  90,000.099
    //     //   Protocol fee  = 100,000.11 * 0.1      =  10,000.011
    //     assertApproxEqAbs(
    //         vault.convertToAssets(vault.balanceOf(vault.feeReceiver())),
    //         900_000_990 * 10 ** (vault.underlyingDecimals() - 4),
    //         10 ** (vault.underlyingDecimals() - 1),
    //         "feeReceiver received unexpected fee shares"
    //     );
    //     assertApproxEqAbs(
    //         vault.convertToAssets(vault.balanceOf(vault.protocolFeeReceiver())),
    //         100_000_110 * 10 ** (vault.underlyingDecimals() - 4),
    //         10 ** (vault.underlyingDecimals() - 1),
    //         "protocol received unexpected fee shares"
    //     );

    //     // ------------ Settle ------------ //
    //     vm.warp(block.timestamp + 364 days);
    //     // vault price per share will increase from 0.425 -> ~1.7 (x4)
    //     newTotalAssets = 4_000_002 * 10 ** vault.underlyingDecimals();
    //     console.log("totalSupply before", vault.totalSupply());
    //     console.log("totalAssets before", vault.totalAssets());
    //     console.log("hwm before", vault.highWaterMark());
    //     updateAndSettle(newTotalAssets);
    //     console.log("totalSupply after", vault.totalSupply());
    //     console.log("totalAssets after", vault.totalAssets());
    //     console.log("hwm after", vault.highWaterMark());

    //     // We expect the price per share to do be equal to:
    //     //
    //     //      mFees = avg(previousTA, totalAssets) * 0.1                                   (~250_000.125$)
    //     //      newPps = (totalAssets - mFees) / totalSupply                                 (~1.59375$/share)
    //     //      pFees = (newPps - hwm) * totalSupply * 0.2                                   (~279_412$)
    //     //      newShares = (mFees + pFees) * (totalSupply / (totalAssets - (mFees + pFees)))  (~358_923 shares)
    //     //
    //     //      pps = (totalAssets - totalFees) / totalSupply (~1.475)
    //     //
    //     assertApproxEqAbs(
    //         pricePerShare(),
    //         1475 * 10 ** (vault.underlyingDecimals() - 3),
    //         5, // rounding approximation
    //         "Price per share didn't increased as expected"
    //     );

    //     // We expect the highWaterMark to be equal to the price per share
    //     assertApproxEqAbs(
    //         vault.highWaterMark(),
    //         vault.pricePerShare(),
    //         5, // rounding approximation
    //         "Highwater mark shoudn't have been raised"
    //     );

    //     uint256 user1ShareBalance = vault.balanceOf(user1.addr);
    //     uint256 user2ShareBalance = vault.balanceOf(user2.addr);

    //     // ------------ Settle ------------ //

    //     console.log("======");
    //     console.log("totalSupply        :", vault.totalSupply());
    //     console.log("totalAssets        :", vault.totalAssets());
    //     console.log("price per share    :", vault.pricePerShare());
    //     console.log("------");
    //     console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
    //     console.log("shares user1       :", vault.balanceOf(user1.addr));
    //     console.log("shares user2       :", vault.balanceOf(user2.addr));
    //     console.log("------");
    //     console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
    //     console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
    //     console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
    //     console.log("======");

    //     requestRedeem(user1ShareBalance, user1.addr);
    //     requestRedeem(user2ShareBalance, user2.addr);

    //     vm.warp(block.timestamp + 364 days);
    //     updateAndSettle(newTotalAssets);
    //     console.log("======");
    //     console.log("totalSupply        :", vault.totalSupply());
    //     console.log("totalAssets        :", vault.totalAssets());
    //     console.log("price per share    :", vault.pricePerShare());
    //     console.log("------");
    //     console.log("shares feeReceiver :", vault.balanceOf(vault.feeReceiver()));
    //     console.log("shares user1       :", vault.balanceOf(user1.addr));
    //     console.log("shares user2       :", vault.balanceOf(user2.addr));
    //     console.log("------");
    //     console.log("assets feeReceiver :", vault.convertToAssets(vault.balanceOf(vault.feeReceiver())));
    //     console.log("assets user1       :", vault.convertToAssets(vault.balanceOf(user1.addr)));
    //     console.log("assets user2       :", vault.convertToAssets(vault.balanceOf(user2.addr)));
    //     console.log("======");

    //     uint256 user1AssetBefore = assetBalance(user1.addr);
    //     uint256 user2AssetBefore = assetBalance(user2.addr);

    //     uint256 user1AssetAfter = redeem(user1ShareBalance, user1.addr);
    //     // uint256 user2AssetAfter = redeem(user2ShareBalance, user2.addr);
    //     uint40 user2LastRequestId = vault.lastRedeemRequestId(user2.addr);
    //     uint256 user2AssetsToWithdraw = vault.convertToAssets(user2ShareBalance, user2LastRequestId);

    //     user2AssetsToWithdraw -= FeeLib.computeFee(
    //         user2AssetsToWithdraw, vault.getSettlementExitFeeRate(user2LastRequestId)
    //     );
    //     uint256 shares = withdraw(user2AssetsToWithdraw, user2.addr);
    //     uint256 user2AssetAfter = vault.convertToAssets(shares, user2LastRequestId);

    //     assetBalance(user1.addr);
    //     assetBalance(user2.addr);

    //     uint256 user1Profit = (user1AssetAfter - user1AssetBefore) - user1InitialDeposit;
    //     uint256 user2Profit = (user2AssetAfter - user2AssetBefore) - user2InitialDeposit;

    //     // User Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════════════════════════
    //     // Initial deposit                    1.000000
    //     // Entry fees (10%)                  -0.100000  →  0.900000
    //     // -- 1 year gap --
    //     // Management fees (10%)             -0.067500  →  0.382500  (avg(1, 0.5)*0.1*0.9 = 0.067500)
    //     // -- 1 year gap --
    //     // Management fees (10%)             -0.095625  →  1.434375  (avg(1M+0.5, 4M+2)*0.1*user1_share)
    //     // Performance fees (20%)            -0.106875  →  1.327500  ((1.59375-1.0)*totalSupply*0.2*user1_share)
    //     // -- 1 year gap --
    //     // Management fees (10%)             -0.132750  →  1.194750  (avg=same since prevTA=curTA=4M+2)
    //     // Exit fees (10%)                   -0.119475  →  1.075275  (1.194750 * 0.1 = 0.119475)
    //     //
    // ════════════════════════════════════════════════════════════════════════════════════════
    //     // Final Position: 1.075275
    //     uint256 expectedUser1Profit = 75_275 * 10 ** (vault.underlyingDecimals() - 6);

    //     assertApproxEqAbs(user1Profit, expectedUser1Profit, 5, "user1 expected profit is wrong");

    //     // User Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════════════════════════
    //     // Initial deposit                    1,000,000
    //     // Entry fees (10%)                    -100,000  →    900,000
    //     // -- 1 year gap --
    //     // Management fees (10%)               -225,000  →  3,375,000  (avg(1M+0.5,4M+2)*0.1*user2_share)
    //     // Performance fees (20%)              -251,471  →  3,123,529  ((1.59375-1.0)*totalSupply*0.2*user2_share)
    //     // -- 1 year gap --
    //     // Management fees (10%)               -312,353  →  2,811,176  (avg=same since prevTA=curTA=4M+2)
    //     // Exit fees (10%)                     -281,118  →  2,530,059  (2,811,176 * 0.1 = 281,118)
    //     //
    // ════════════════════════════════════════════════════════════════════════════════════════
    //     // Final Position: 2,530,059
    //     uint256 expectedUser2Profit = 1_530_059 * 10 ** vault.underlyingDecimals();

    //     assertApproxEqAbs(
    //         user2Profit, expectedUser2Profit, 10 ** (vault.underlyingDecimals() + 1), "user2 expected profit is
    // wrong" );

    //     // expectedTotalFees = (totalAssets - (deposit1 + profit1 + deposit2 + profit2)) * (1 - exitFees)
    //     //                   = (4_000_002 - (1 + 0.075275 + 1_000_000 + 1_530_059)) * 0.9
    //     //                   = ~1_469_942$ * 0.9
    //     //                   = ~1_322_948$
    //     uint256 expectedTotalFees = 1_322_948_000 * 10 ** (vault.underlyingDecimals() - 3);

    //     address feeReceiver = vault.feeReceiver();
    //     address dao = vault.protocolFeeReceiver();

    //     uint256 feeReceiverShareBalance = vault.balanceOf(feeReceiver);
    //     uint256 daoShareBalance = vault.balanceOf(dao);

    //     assertApproxEqAbs(
    //         pricePerShare(),
    //         13_275 * 10 ** (vault.underlyingDecimals() - 4),
    //         5, // rounding approximation
    //         "Price per share didn't decreased as expected"
    //     );

    //     requestRedeem(feeReceiverShareBalance, feeReceiver);
    //     requestRedeem(daoShareBalance, dao);

    //     // ------------ Settle ------------ //
    //     vm.warp(block.timestamp + 1);
    //     updateNewTotalAssets(vault.totalAssets());
    //     settle();
    //     // vm.warp(block.timestamp + 1);

    //     uint256 feeReceiverAssetAfter = redeem(feeReceiverShareBalance, feeReceiver);
    //     uint256 daoAssetAfter = redeem(daoShareBalance, dao);

    //     uint256 totalFees = feeReceiverAssetAfter + daoAssetAfter;

    //     assertApproxEqAbs(totalFees, expectedTotalFees, 5 * 10 ** vault.underlyingDecimals(), "wrong total Fees");
    // }

    // function test_SettleRedeemTakesCorrectAmountOfFees() public {
    //     // setup
    //     dealAndApprove(user1.addr);
    //     dealAndApprove(user2.addr);
    //     uint256 balance1Before = assetBalance(user1.addr);
    //     uint256 balance2Before = assetBalance(user2.addr);

    //     uint256 balance = assetBalance(user1.addr);

    //     requestDeposit(balance, user1.addr);
    //     requestDeposit(balance, user2.addr);

    //     updateAndSettle(0);

    //     deposit(balance, user1.addr);
    //     uint40 user2LastRequestId = vault.lastDepositRequestId(user1.addr);
    //     console.log("-----user1LastRequestId", user2LastRequestId);
    //     console.log("-----historical entryFeeRate", vault.getSettlementEntryFeeRate(user2LastRequestId));
    //     console.log("-----current entryFeeRate", vault.entryRate());
    //     uint256 shares = vault.convertToShares(
    //         balance - FeeLib.computeFee(balance, vault.getSettlementEntryFeeRate(user2LastRequestId))
    //     );
    //     mint(shares, user2.addr);
    //     ////

    //     uint256 user1Shares = vault.balanceOf(user1.addr);
    //     uint256 user2Shares = vault.balanceOf(user2.addr);

    //     requestRedeem(user1Shares, user1.addr);
    //     requestRedeem(user2Shares, user2.addr);

    //     vm.warp(block.timestamp + 364 days);
    //     updateAndSettleRedeem(4 * balance);

    //     redeem(user1Shares, user1.addr);
    //     redeem(user2Shares, user2.addr);

    //     uint256 balance1After = assetBalance(user1.addr);
    //     uint256 balance2After = assetBalance(user2.addr);
    //     uint256 amSharesBalance = vault.balanceOf(feeReceiver.addr);
    //     uint256 daoSharesBalance = vault.balanceOf(dao.addr);

    //     // User Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Initial Investment      100.0
    //     // Entry Fees (10%)       -10.0   →   90.0
    //     // Valorisation (2x)       90.0   →  180.0
    //     // Management Fees (10%)  -13.5   →  166.5   (avg(200_000, 400_000) * 0.1 = 30_000, user share = 13_500)
    //     // Performance Fees (20%) -15.3   →  151.2   ((1.85 - 1.0) * 200_000 * 0.2 = 34_000, user share = 15_300)
    //     // Exit Fees (10%)        -15.12  →  136.08
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Final Position: 136.08
    //     uint256 user1Profit = 36_080 * 10 ** vault.underlyingDecimals();
    //     uint256 user2Profit = 36_080 * 10 ** vault.underlyingDecimals();

    //     // AM Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Initial Investment      0
    //     // User's Fees            +127.84  →  127.84
    //     // Protocol Fees (10%)    -12.784  →  115.056
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Final Position: 115.056
    //     uint256 amProfit = vault.convertToShares(115_056 * 10 ** vault.underlyingDecimals());
    //     // Protocol Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Initial Investment      0
    //     // Protocol Fees (10%)    +12.784  →  12.784
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Final Position: 12.784
    //     uint256 daoProfit = vault.convertToShares(12_784 * 10 ** vault.underlyingDecimals());

    //     assertApproxEqAbs(balance1After - balance1Before, user1Profit, 100_000, "unexpected balance 1");
    //     assertApproxEqAbs(balance2After - balance2Before, user2Profit, 100_000, "unexpected balance 2");
    //     assertApproxEqAbs(amSharesBalance, amProfit, vault.convertToShares(100_000), "am: wrong profits");
    //     assertApproxEqAbs(daoSharesBalance, daoProfit, vault.convertToShares(100_000), "dao: wrong profits");
    // }

    // function test_CloseTakesCorrectAmountOfFees() public {
    //     // setup
    //     dealAndApprove(user1.addr);
    //     dealAndApprove(user2.addr);
    //     uint256 balance1Before = assetBalance(user1.addr);
    //     uint256 balance2Before = assetBalance(user2.addr);

    //     uint256 balance = assetBalance(user1.addr);

    //     requestDeposit(balance, user1.addr);
    //     requestDeposit(balance, user2.addr);

    //     updateAndSettle(0);

    //     deposit(balance, user1.addr);
    //     deposit(balance, user2.addr);
    //     ////

    //     uint256 user1Shares = vault.balanceOf(user1.addr);
    //     uint256 user2Shares = vault.balanceOf(user2.addr);

    //     vm.warp(block.timestamp + 364 days);
    //     vm.prank(vault.owner());
    //     vault.initiateClosing();
    //     updateAndClose(4 * balance);

    //     redeem(user1Shares, user1.addr);
    //     // use maxWithdraw which accounts for exit fees taken during sync withdraw
    //     uint256 user2AssetsToWithdraw = vault.maxWithdraw(user2.addr);
    //     withdraw(user2AssetsToWithdraw, user2.addr);

    //     uint256 balance1After = assetBalance(user1.addr);
    //     uint256 balance2After = assetBalance(user2.addr);
    //     uint256 amSharesBalance = vault.balanceOf(feeReceiver.addr);
    //     uint256 daoSharesBalance = vault.balanceOf(dao.addr);

    //     // User Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Initial Investment      100.0
    //     // Entry Fees (10%)       -10.0   →   90.0
    //     // Valorisation (2x)       90.0   →  180.0
    //     // Management Fees (10%)  -13.5   →  166.5   (avg(200_000, 400_000) * 0.1 = 30_000, user share = 13_500)
    //     // Performance Fees (20%) -15.3   →  151.2   ((1.85 - 1.0) * 200_000 * 0.2 = 34_000, user share = 15_300)
    //     // Exit Fees (10%)        -15.12  →  136.08
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Final Position: 136.08
    //     uint256 user1Profit = 36_080 * 10 ** vault.underlyingDecimals();
    //     uint256 user2Profit = 36_080 * 10 ** vault.underlyingDecimals();

    //     // AM Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Initial Investment      0
    //     // User's Fees            +127.84  →  127.84
    //     // Protocol Fees (10%)    -12.784  →  115.056
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Final Position: 115.056
    //     uint256 amProfit = vault.convertToShares(115_056 * 10 ** vault.underlyingDecimals());
    //     // Protocol Position Evolution:
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Initial Investment      0
    //     // Protocol Fees (10%)    +12.784  →  12.784
    //     //
    // ════════════════════════════════════════════════════════════════════
    //     // Final Position: 12.784
    //     uint256 daoProfit = vault.convertToShares(12_784 * 10 ** vault.underlyingDecimals());

    //     assertApproxEqAbs(
    //         assetBalance(address(vault)),
    //         127_840 * 10 ** vault.underlyingDecimals(),
    //         100_000,
    //         "wrong vault asset balance"
    //     );

    //     assertApproxEqAbs(balance1After - balance1Before, user1Profit, 100_000, "user1: wrong profits");
    //     assertApproxEqAbs(balance2After - balance2Before, user2Profit, 100_000, "user2: wrong profits");
    //     assertApproxEqAbs(amSharesBalance, amProfit, vault.convertToShares(100_000), "am: wrong profits");
    //     assertApproxEqAbs(daoSharesBalance, daoProfit, vault.convertToShares(100_000), "dao: wrong profits");
    // }

    function test_NoFeesAreTakenDuringFreeRide() public {
        Rates memory rates =
            Rates({managementRate: 0, performanceRate: 2000, entryRate: 0, exitRate: 0, haircutRate: 0});
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
        vm.warp(block.timestamp + 1);
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
        vm.warp(block.timestamp + 1);
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
        vm.warp(block.timestamp + 1);
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
            exitRate: 0,
            haircutRate: 0
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
            exitRate: 0,
            haircutRate: 0
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

    // ********************* HIGH WATER MARK RESET TESTS ********************* //

    function test_resetHighWaterMark_whenFlagEnabled_resetsToCurrentPricePerShare() public {
        // Deploy a new vault with allowHighWaterMarkReset enabled
        InitStruct memory initStruct = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: managementFee,
            performanceRate: performanceFee,
            accessMode: AccessMode.Blacklist,
            entryRate: entryFee,
            exitRate: exitFee,
            haircutRate: 0,
            securityCouncil: admin.addr,
            externalSanctionsList: address(0),
            initialTotalAssets: 0,
            superOperator: superOperator.addr,
            allowHighWaterMarkReset: true
        });

        VaultHelper newVault = new VaultHelper(false);
        newVault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);
        vault = newVault;

        // Make some deposits and settlements to increase the high water mark
        // First, deal assets and approve
        uint256 depositAmount = _10K;
        dealAmountAndApprove(user1.addr, depositAmount);

        // Request deposit
        vm.prank(user1.addr);
        newVault.requestDeposit(depositAmount, user1.addr, user1.addr);

        // Update total assets and settle (use a higher value to create performance)
        uint256 newTotalAssets = _20M;
        vm.prank(newVault.valuationManager());
        newVault.updateNewTotalAssets(newTotalAssets);
        vm.warp(block.timestamp + 1 days);
        vm.prank(newVault.safe());
        newVault.settleDeposit(newTotalAssets);

        uint256 hwmBefore = newVault.highWaterMark();
        uint256 currentPps = newVault.convertToAssets(10 ** newVault.decimals());

        vm.prank(newVault.valuationManager());
        newVault.updateNewTotalAssets(newTotalAssets / 2);
        vm.warp(block.timestamp + 1 days);
        vm.prank(newVault.safe());
        newVault.settleDeposit(newTotalAssets / 2);

        assertNotEq(newVault.highWaterMark(), newVault.pricePerShare(), "hwm should not be equal to pps");

        // Reset the high water mark
        vm.prank(newVault.safe());
        newVault.resetHighWaterMark();

        // High water mark should now equal current price per share
        assertEq(newVault.highWaterMark(), newVault.pricePerShare(), "HWM should equal current PPS after reset");
    }

    function test_resetHighWaterMark_whenFlagDisabled_reverts() public {
        // Default vault has allowHighWaterMarkReset: false
        uint256 hwmBefore = vault.highWaterMark();

        // Attempt to reset should revert
        vm.prank(vault.safe());
        vm.expectRevert(HighWaterMarkResetNotAllowed.selector);
        vault.resetHighWaterMark();

        // High water mark should remain unchanged
        assertEq(vault.highWaterMark(), hwmBefore, "HWM should remain unchanged");
    }

    function test_resetHighWaterMark_whenNotCalledBySafe_reverts() public {
        // Attempt to reset from non-safe address should revert
        vm.prank(admin.addr);
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, safe.addr));
        vault.resetHighWaterMark();

        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, safe.addr));
        vault.resetHighWaterMark();

        vm.prank(valuationManager.addr);
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, safe.addr));
        vault.resetHighWaterMark();
    }

    function test_resetHighWaterMark_emitsHighWaterMarkUpdatedEvent() public {
        // Deploy a new vault with allowHighWaterMarkReset enabled
        InitStruct memory initStruct = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: managementFee,
            performanceRate: performanceFee,
            accessMode: AccessMode.Blacklist,
            entryRate: entryFee,
            exitRate: exitFee,
            haircutRate: 0,
            securityCouncil: admin.addr,
            externalSanctionsList: address(0),
            initialTotalAssets: 0,
            superOperator: superOperator.addr,
            allowHighWaterMarkReset: true
        });

        VaultHelper newVault = new VaultHelper(false);
        newVault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);
        vault = newVault;

        // Make some deposits and settlements to increase the high water mark
        // First, deal assets and approve
        uint256 depositAmount = _10K;
        dealAmountAndApprove(user1.addr, depositAmount);

        // Request deposit
        vm.prank(user1.addr);
        newVault.requestDeposit(depositAmount, user1.addr, user1.addr);

        // Update total assets and settle (use a higher value to create performance)
        uint256 newTotalAssets = _20M;
        vm.prank(newVault.valuationManager());
        newVault.updateNewTotalAssets(newTotalAssets);
        vm.warp(block.timestamp + 1 days);
        vm.prank(newVault.safe());
        newVault.settleDeposit(newTotalAssets);

        uint256 hwmBefore = newVault.highWaterMark();
        uint256 currentPps = newVault.convertToAssets(10 ** newVault.decimals());

        // Expect the HighWaterMarkUpdated event
        vm.expectEmit(true, true, true, true);
        emit HighWaterMarkUpdated(hwmBefore, currentPps);

        // Reset the high water mark
        vm.prank(newVault.safe());
        newVault.resetHighWaterMark();
    }

    function test_resetHighWaterMark_whenPricePerShareEqualsHighWaterMark_stillResets() public {
        // Deploy a new vault with allowHighWaterMarkReset enabled
        InitStruct memory initStruct = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: 0, // No fees to keep it simple
            performanceRate: 0,
            accessMode: AccessMode.Blacklist,
            entryRate: 0,
            exitRate: 0,
            haircutRate: 0,
            securityCouncil: admin.addr,
            externalSanctionsList: address(0),
            initialTotalAssets: 0,
            superOperator: superOperator.addr,
            allowHighWaterMarkReset: true
        });

        VaultHelper newVault = new VaultHelper(false);
        newVault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);

        uint256 hwmBefore = newVault.highWaterMark();
        uint256 currentPps = newVault.convertToAssets(10 ** newVault.decimals());

        // Initially, HWM should equal current PPS
        assertEq(hwmBefore, currentPps, "HWM should equal current PPS initially");

        // Reset should still work even when they're equal
        vm.prank(newVault.safe());
        newVault.resetHighWaterMark();

        // HWM should still equal current PPS
        uint256 hwmAfter = newVault.highWaterMark();
        assertEq(hwmAfter, currentPps, "HWM should still equal current PPS after reset");
        assertEq(hwmAfter, hwmBefore, "HWM should remain the same when already equal to PPS");
    }
}
