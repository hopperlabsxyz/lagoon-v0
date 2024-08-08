// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, ASSET_MANAGER_ROLE, FEE_RECEIVER, VALORIZATION_ROLE, HOPPER_ROLE} from "@src/Vault.sol";
import {IERC4626, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseTest} from "./Base.sol";
import {FeeManager} from "@src/FeeManager.sol";

// contract MockVault is FeeManager {
//     function initialize(
//         address _feeModule,
//         uint256 _protocolFee
//     ) public initializer {
//         __FeeManager_init(_feeModule, _protocolFee);
//     }
// }

contract TestFeeManager is BaseTest {
    using Math for uint256;
    uint256 _1K;
    uint256 _10K;
    uint256 _100K;
    uint256 _1M;
    uint256 _10M;
    uint256 _20M;
    uint256 _50M;
    uint256 _100M;

    function setUp() public {
        setUpVault(100, 200, 2_000);
        _1K = 1_000 * 10 ** vault.underlyingDecimals();
        _10K = 10_000 * 10 ** vault.underlyingDecimals();
        _100K = 100_000 * 10 ** vault.underlyingDecimals();
        _1M = 1_000_000 * 10 ** vault.underlyingDecimals();
        _10M = 10_000_000 * 10 ** vault.underlyingDecimals();
        _20M = 20_000_000 * 10 ** vault.underlyingDecimals();
        _50M = 50_000_000 * 10 ** vault.underlyingDecimals();
        _100M = 100_000_000 * 10 ** vault.underlyingDecimals();
    }

    function test_collect_fees() public {
        dealAmountAndApproveAndWhitelist(user1.addr, 10_000_000);

        address assetManager = vault.getRoleMember(ASSET_MANAGER_ROLE, 0);
        address hopperDao = vault.getRoleMember(HOPPER_ROLE, 0);
        address vaultFeeReceiver = vault.getRoleMember(FEE_RECEIVER, 0);

        assertEq(vault.balanceOf(assetManager), 0);
        assertEq(vault.balanceOf(vaultFeeReceiver), 0);
        assertEq(vault.balanceOf(hopperDao), 0);
        assertEq(vault.highWaterMark(), 0);
        assertEq(vault.totalSupply(), 0);

        uint256 userBalance = assetBalance(user1.addr);
        assertEq(userBalance, _10M);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);

        assertEq(vault.balanceOf(assetManager), 0);
        assertEq(vault.balanceOf(hopperDao), 0);
        assertEq(vault.balanceOf(vaultFeeReceiver), 0);

        assertEq(vault.highWaterMark(), _10M); // The high water mark is raised so that the deposit is not subject to performance fees
        assertEq(vault.totalSupply(), 10_000_000 * 10 ** vault.decimals()); // Now user1 got 10M shares for his deposit

        // Fees over 1 year
        // /!\ 364 days because there is 1 days timelock period before settle is called
        vm.warp(vm.getBlockTimestamp() + 364 days);

        // Management Fees: 100 m * 2% = 2m
        // Perf       Fees: (90m - 2m) * 20% = 17,6m
        // Total      Fees: 19,6m
        uint256 expectedTotalFees = 19_600_000 *
            10 ** vault.underlyingDecimals(); // assets

        uint256 expectedTotalNewShares = expectedTotalFees.mulDiv(
            vault.totalSupply() + 1,
            _100M - expectedTotalFees + 1, // total assets
            Math.Rounding.Floor
        );

        uint256 expectedProtocolNewShares = expectedTotalNewShares / 100;
        uint256 expectedFeeReceiverNewShares = expectedTotalNewShares -
            expectedProtocolNewShares;
        uint256 totalSupplyBefore = vault.totalSupply();
        updateAndSettle(_100M);
        uint256 totalSupplyAfter = vault.totalSupply();

        assertEq(
            expectedTotalNewShares,
            totalSupplyAfter - totalSupplyBefore,
            "Amount of shares did not increase properly"
        );
        assertEq(
            vault.balanceOf(vault.claimableSilo()),
            userBalance,
            "Wrong amount of shares available in claimable silo"
        );
        assertEq(
            vault.balanceOf(vaultFeeReceiver),
            expectedFeeReceiverNewShares,
            "Vault Fee Receiver did not receive right amount"
        );
        assertEq(
            vault.balanceOf(hopperDao),
            expectedProtocolNewShares,
            "Hopper Dao did not receive expectedProtocolShares"
        );
    }

    // +======+=========+==========+======+=======+=========+========+======+===========+=========+
    // | year | deposit | withdraw | aum  | mfees | profits | pfees  | hwm  | totalFees |   net   |
    // +======+=========+==========+======+=======+=========+========+======+===========+=========+
    // |    0 | 10M     | 0        | 0    | 0     | 0       | 0      | 10M  | 0         | 0       |
    // +------+---------+----------+------+-------+---------+--------+------+-----------+---------+
    // |    1 | 0       | 0        | 10M  | 0.2M  | 0       | 0      | 10M  | 0.2M      | 9.8M    |
    // +------+---------+----------+------+-------+---------+--------+------+-----------+---------+
    // |    2 | 0       | 0        | 50M  | 1M    | 39M     | 7.8M   | 50M  | 8.8M      | 41.2M   |
    // +------+---------+----------+------+-------+---------+--------+------+-----------+---------+
    // |    3 | 0       | 0        | 19M  | 0.38M | 0       | 0      | 50M  | 0.38M     | 18.62M  |
    // +------+---------+----------+------+-------+---------+--------+------+-----------+---------+
    // |    4 | 0       | 0        | 30M  | 0.6M  | 0       | 0      | 50M  | 0.6M      | 29.4M   |
    // +------+---------+----------+------+-------+---------+--------+------+-----------+---------+
    // |    5 | 100M    | 0        | 61M  | 1.22M | 9.78M   | 1.956M | 161M | 3.176M    | 57.824M |
    // +------+---------+----------+------+-------+---------+--------+------+-----------+---------+

    function test_multiple_year() public {
        address feeReceiver = vault.getRoleMember(FEE_RECEIVER, 0);
        address hopperDao = vault.getRoleMember(HOPPER_ROLE, 0);

        uint256 managerShares = vault.balanceOf(feeReceiver);
        uint256 daoShares = vault.balanceOf(hopperDao);

        // ------------ Year 0 ------------ //
        uint256 newTotalAssets = 0;
        uint256 expectedHighWaterMark = _10M;
        uint256 expectedTotalFees = 0;
        uint256 expectedTotalNewShares = 0;
        uint256 expectedProtocolNewShares = 0;
        uint256 expectedManagerNewShares = 0;

        // new airdrop !
        dealAmountAndApproveAndWhitelist(user1.addr, 10_000_000);
        requestDeposit(_10M, user1.addr);

        // settlement
        updateAndSettle(newTotalAssets);

        assertEq(vault.highWaterMark(), expectedHighWaterMark);
        assertEq(vault.totalSupply(), 10_000_000 * 10 ** vault.decimals());
        assertEq(
            vault.balanceOf(feeReceiver) - managerShares,
            expectedManagerNewShares
        );
        assertEq(
            vault.balanceOf(hopperDao) - daoShares,
            expectedProtocolNewShares
        );
        assertEq(vault.lastFeeTime(), block.timestamp);

        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // ------------ Year 1 ------------ //
        vm.warp(vm.getBlockTimestamp() + 364 days);

        // expectations
        newTotalAssets = _10M;
        expectedHighWaterMark = _10M;
        expectedTotalFees = 200_000 * 10 ** vault.underlyingDecimals();
        expectedTotalNewShares = expectedTotalFees.mulDiv(
            vault.totalSupply() + 1,
            (newTotalAssets - expectedTotalFees) + 1,
            Math.Rounding.Floor
        );
        expectedProtocolNewShares = expectedTotalNewShares / 100;
        expectedManagerNewShares =
            expectedTotalNewShares -
            expectedProtocolNewShares;

        // settlement
        updateAndSettle(newTotalAssets);

        // verification
        assertEq(vault.highWaterMark(), expectedHighWaterMark);
        assertEq(
            vault.totalSupply() -
                vault.balanceOf(vault.claimableSilo()) -
                managerShares -
                daoShares,
            expectedTotalNewShares
        );
        assertEq(
            vault.balanceOf(feeReceiver) - managerShares,
            expectedManagerNewShares
        );
        assertEq(
            vault.balanceOf(hopperDao) - daoShares,
            expectedProtocolNewShares
        );
        assertEq(vault.lastFeeTime(), block.timestamp);

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // // ------------ Year 2 ------------ //
        vm.warp(vm.getBlockTimestamp() + 364 days);

        // expectations
        newTotalAssets = _50M;
        expectedHighWaterMark = _50M;
        expectedTotalFees = 8_800_000 * 10 ** vault.underlyingDecimals();
        expectedTotalNewShares = expectedTotalFees.mulDiv(
            vault.totalSupply() + 1,
            (newTotalAssets - expectedTotalFees) + 1,
            Math.Rounding.Floor
        );
        expectedProtocolNewShares = expectedTotalNewShares / 100;
        expectedManagerNewShares =
            expectedTotalNewShares -
            expectedProtocolNewShares;

        // settlement
        updateAndSettle(newTotalAssets);

        // verification
        assertEq(vault.highWaterMark(), expectedHighWaterMark);
        assertEq(
            vault.totalSupply() -
                vault.balanceOf(vault.claimableSilo()) -
                managerShares -
                daoShares,
            expectedTotalNewShares
        );
        assertEq(
            vault.balanceOf(feeReceiver) - managerShares,
            expectedManagerNewShares
        );
        assertEq(
            vault.balanceOf(hopperDao) - daoShares,
            expectedProtocolNewShares
        );
        assertEq(vault.lastFeeTime(), block.timestamp);

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // // ------------ Year 3 ------------ //
        vm.warp(vm.getBlockTimestamp() + 364 days);

        // expectations
        newTotalAssets = _20M - _1M;
        expectedHighWaterMark = _50M;
        expectedTotalFees = 380_000 * 10 ** vault.underlyingDecimals();
        expectedTotalNewShares = expectedTotalFees.mulDiv(
            vault.totalSupply() + 1,
            (newTotalAssets - expectedTotalFees) + 1,
            Math.Rounding.Floor
        );
        expectedProtocolNewShares = expectedTotalNewShares / 100;
        expectedManagerNewShares =
            expectedTotalNewShares -
            expectedProtocolNewShares;

        // settlement
        updateAndSettle(newTotalAssets);

        // verification
        assertEq(vault.highWaterMark(), expectedHighWaterMark);
        assertEq(
            vault.totalSupply() -
                vault.balanceOf(vault.claimableSilo()) -
                managerShares -
                daoShares,
            expectedTotalNewShares
        );
        assertEq(
            vault.balanceOf(feeReceiver) - managerShares,
            expectedManagerNewShares
        );
        assertEq(
            vault.balanceOf(hopperDao) - daoShares,
            expectedProtocolNewShares
        );
        assertEq(vault.lastFeeTime(), block.timestamp);

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // // ------------ Year 4 ------------ //
        vm.warp(vm.getBlockTimestamp() + 364 days);

        // expectations
        newTotalAssets = 3 * _10M;
        expectedHighWaterMark = _50M;
        expectedTotalFees = 600_000 * 10 ** vault.underlyingDecimals();
        expectedTotalNewShares = expectedTotalFees.mulDiv(
            vault.totalSupply() + 1,
            (newTotalAssets - expectedTotalFees) + 1,
            Math.Rounding.Floor
        );
        expectedProtocolNewShares = expectedTotalNewShares / 100;
        expectedManagerNewShares =
            expectedTotalNewShares -
            expectedProtocolNewShares;

        // settlement
        updateAndSettle(newTotalAssets);

        // verification
        assertEq(vault.highWaterMark(), expectedHighWaterMark);
        assertEq(
            vault.totalSupply() -
                vault.balanceOf(vault.claimableSilo()) -
                managerShares -
                daoShares,
            expectedTotalNewShares
        );
        assertEq(
            vault.balanceOf(feeReceiver) - managerShares,
            expectedManagerNewShares
        );
        assertEq(
            vault.balanceOf(hopperDao) - daoShares,
            expectedProtocolNewShares
        );
        assertEq(vault.lastFeeTime(), block.timestamp);

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // // ------------ Year 5 ------------ //
        vm.warp(vm.getBlockTimestamp() + 364 days);

        // new airdrop !
        dealAmountAndApproveAndWhitelist(user1.addr, 100_000_000);
        requestDeposit(_100M, user1.addr); // this will auto claim unclaimed shares

        // expectations
        newTotalAssets = _50M + _1M + _10M; // _61M
        expectedHighWaterMark = _100M + newTotalAssets; // _161M
        expectedTotalFees = 3_176_000 * 10 ** vault.underlyingDecimals();
        expectedTotalNewShares = expectedTotalFees.mulDiv(
            vault.totalSupply() + 1,
            (newTotalAssets - expectedTotalFees) + 1,
            Math.Rounding.Floor
        );
        expectedProtocolNewShares = expectedTotalNewShares / 100;
        expectedManagerNewShares =
            expectedTotalNewShares -
            expectedProtocolNewShares;

        // settlement
        updateAndSettle(newTotalAssets);

        // verification
        assertEq(vault.highWaterMark(), expectedHighWaterMark);
        assertEq(
            vault.totalSupply() -
                vault.balanceOf(vault.claimableSilo()) -
                vault.balanceOf(user1.addr) -
                managerShares -
                daoShares,
            expectedTotalNewShares
        );

        assertEq(
            vault.balanceOf(feeReceiver) - managerShares,
            expectedManagerNewShares
        );
        assertEq(
            vault.balanceOf(hopperDao) - daoShares,
            expectedProtocolNewShares
        );
        assertEq(vault.lastFeeTime(), block.timestamp);

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);
    }

    // function test_max_fee_errors() public {
    //     vm.prank(vault.hopperRole());
    //     vm.expectRevert(AboveMaxFee.selector);
    //     vault.updateProtocolFee(MAX_PROTOCOL_FEES + 1);

    //     vm.prank(vault.adminRole());
    //     vm.expectRevert(AboveMaxFee.selector);
    //     vault.updateManagementFee(MAX_MANAGEMENT_FEES + 1);

    //     vm.prank(vault.adminRole());
    //     vm.expectRevert(AboveMaxFee.selector);
    //     vault.updatePerformanceFee(MAX_PERFORMANCE_FEES + 1);
    // }

    // function test_initializer_errors() public {
    //     MockVault v;

    //     v = new MockVault();
    //     vm.expectRevert(AboveMaxFee.selector);
    //     v.initialize(MAX_MANAGEMENT_FEES + 1, 1, 1);

    //     v = new MockVault();
    //     vm.expectRevert(AboveMaxFee.selector);
    //     v.initialize(1, MAX_PERFORMANCE_FEES + 1, 1);

    //     v = new MockVault();
    //     vm.expectRevert(AboveMaxFee.selector);
    //     v.initialize(1, 1, MAX_PROTOCOL_FEES + 1);
    // }

    // function test_initializer() public {
    //     MockVault v;

    //     v = new MockVault();
    //     v.initialize(1, 2, 3);
    //     assertEq(v.managementFee(), 1);
    //     assertEq(v.performanceFee(), 2);
    //     assertEq(v.protocolFee(), 3);
    //     assertEq(v.lastFeeTime(), block.timestamp);
    //     assertEq(v.highWaterMark(), 0);
    // }
}
