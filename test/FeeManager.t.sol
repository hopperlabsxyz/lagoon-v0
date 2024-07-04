// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, ASSET_MANAGER_ROLE, FEE_RECEIVER, VALORIZATION_ROLE, HOPPER_ROLE} from "@src/Vault.sol";
import {IERC4626, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseTest} from "./Base.sol";
import {AboveMaxFee, CooldownNotOver, MAX_PROTOCOL_FEES, MAX_PERFORMANCE_FEES, MAX_MANAGEMENT_FEES} from "@src/FeeManager.sol";

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
        _1K = 1_000 * 10 ** vault.underlyingDecimals();
        _10K = 10_000 * 10 ** vault.underlyingDecimals();
        _100K = 100_000 * 10 ** vault.underlyingDecimals();
        _1M = 1_000_000 * 10 ** vault.underlyingDecimals();
        _10M = 10_000_000 * 10 ** vault.underlyingDecimals();
        _20M = 20_000_000 * 10 ** vault.underlyingDecimals();
        _50M = 50_000_000 * 10 ** vault.underlyingDecimals();
        _100M = 100_000_000 * 10 ** vault.underlyingDecimals();
    }

    function test_zero_bips() public view {
        assertEq(vault.managementFee(), 0);
        assertEq(vault.performanceFee(), 0);
        assertEq(vault.protocolFee(), 0);
    }

    function test_100_bips() public {
        setProtocolFee(100, vault.hopperRole());
        setPerformanceFee(100, vault.adminRole());
        setManagementFee(100, vault.adminRole());

        assertEq(vault.managementFee(), 100);
        assertEq(vault.performanceFee(), 100);
        assertEq(vault.protocolFee(), 100);
    }

    function test_with_no_fees() public view {
        // Manager's fees
        uint256 managementFees = vault.calculateManagementFee(_100M);
        uint256 performanceFees = vault.calculatePerformanceFee(_100M);

        assertEq(managementFees, 0);
        assertEq(performanceFees, 0);

        // Protocol fees taken on manager's fees
        uint256 totalFees = _1M;
        (uint256 managerFees, uint256 protocolFees) = vault
            .calculateProtocolFee(totalFees);

        assertEq(protocolFees, 0);
        assertEq(managerFees, totalFees);
    }

    function test_performance_fees() public {
        setPerformanceFee(100, vault.adminRole()); // 1% fees on net AUM if above high water mark

        assertEq(vault.calculatePerformanceFee(_100M), _1M);
        assertEq(vault.calculatePerformanceFee(_10M), _100K);
        assertEq(vault.calculatePerformanceFee(_1M), _10K);
        assertEq(vault.calculatePerformanceFee(_100K), _1K);
    }

    function test_management_fees() public {
        // takes 1 day to settle new fee schema
        setManagementFee(100, vault.adminRole()); // 1% fees on average AUM since last NAV

        // Fees over 1 year (364 days because there is 1 day of fee settlement in setManagementFees() above)
        vm.warp(vm.getBlockTimestamp() + 364 days);

        assertEq(vault.calculateManagementFee(_100M), _1M);
        assertEq(vault.calculateManagementFee(_10M), _100K);
        assertEq(vault.calculateManagementFee(_1M), _10K);
        assertEq(vault.calculateManagementFee(_100K), _1K);
    }

    function test_protocol_fees() public {
        setProtocolFee(100, vault.hopperRole()); // 1% fees on total fees collected

        (uint256 managerFees, uint256 protocolFees) = vault
            .calculateProtocolFee(_100M);
        assertEq(managerFees, _100M - _1M);
        assertEq(protocolFees, _1M);

        (managerFees, protocolFees) = vault.calculateProtocolFee(_10M);
        assertEq(managerFees, _10M - _100K);
        assertEq(protocolFees, _100K);
    }

    function test_collect_fees() public {
        dealAmountAndApproveAndWhitelist(user1.addr, 10_000_000);

        // 20% perf. fees / 2% management fees / 1% protocol fees
        setProtocolFee(100, vault.hopperRole());
        setPerformanceFee(2000, vault.adminRole());
        setManagementFee(200, vault.adminRole());

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

        uint256 expectedTotalFees = 19_600_000 *
            10 ** vault.underlyingDecimals();

        uint256 expectedTotalNewShares = vault.totalSupply().mulDiv(
            expectedTotalFees,
            _100M - expectedTotalFees,
            Math.Rounding.Floor
        );

        uint256 expectedProtocolNewShares = expectedTotalNewShares / 100;
        uint256 expectedFeeReceiverNewShares = expectedTotalNewShares -
            expectedProtocolNewShares;

        updateAndSettle(_100M);

        assertEq(vault.balanceOf(address(vault.claimableSilo())), userBalance);
        assertEq(
            vault.balanceOf(vaultFeeReceiver),
            expectedFeeReceiverNewShares
        );
        assertEq(vault.balanceOf(hopperDao), expectedProtocolNewShares);
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

        // 20% perf. fees / 2% management fees / 1% protocol fees
        setProtocolFee(100, vault.hopperRole());
        setPerformanceFee(2000, vault.adminRole());
        setManagementFee(200, vault.adminRole());

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

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // ------------ Year 2 ------------ //
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

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // ------------ Year 3 ------------ //
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

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // ------------ Year 4 ------------ //
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

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);

        // ------------ Year 5 ------------ //
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

        // save balances
        managerShares = vault.balanceOf(feeReceiver);
        daoShares = vault.balanceOf(hopperDao);
    }

    function test_max_fee_errors() public {
        vm.prank(vault.hopperRole());
        vm.expectRevert(AboveMaxFee.selector);
        vault.updateProtocolFee(MAX_PROTOCOL_FEES + 1);

        vm.prank(vault.adminRole());
        vm.expectRevert(AboveMaxFee.selector);
        vault.updateManagementFee(MAX_MANAGEMENT_FEES + 1);

        vm.prank(vault.adminRole());
        vm.expectRevert(AboveMaxFee.selector);
        vault.updatePerformanceFee(MAX_PERFORMANCE_FEES + 1);
    }

    function test_cooldown_errors() public {
        vm.startPrank(vault.hopperRole());
        vault.updateProtocolFee(1);
        vm.expectRevert(CooldownNotOver.selector);
        vault.setProtocolFee();
        vm.stopPrank();

        vm.startPrank(vault.adminRole());
        vault.updateManagementFee(1);
        vm.expectRevert(CooldownNotOver.selector);
        vault.setManagementFee();
        vm.stopPrank();

        vm.startPrank(vault.adminRole());
        vault.updatePerformanceFee(1);
        vm.expectRevert(CooldownNotOver.selector);
        vault.setPerformanceFee();
        vm.stopPrank();
    }
}
