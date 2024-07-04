// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, ASSET_MANAGER_ROLE, VALORIZATION_ROLE, HOPPER_ROLE} from "@src/Vault.sol";
import {IERC4626, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseTest} from "./Base.sol";

contract TestFeeManager is BaseTest {
    using Math for uint256;
    uint256 _1K;
    uint256 _10K;
    uint256 _100K;
    uint256 _1M;
    uint256 _10M;
    uint256 _100M;

    function setUp() public {
        _1K = 1_000 * 10 ** vault.underlyingDecimals();
        _10K = 10_000 * 10 ** vault.underlyingDecimals();
        _100K = 100_000 * 10 ** vault.underlyingDecimals();
        _1M = 1_000_000 * 10 ** vault.underlyingDecimals();
        _10M = 10_000_000 * 10 ** vault.underlyingDecimals();
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

        assertEq(vault.balanceOf(assetManager), 0);
        assertEq(vault.balanceOf(hopperDao), 0);
        assertEq(vault.highWaterMark(), 0);
        assertEq(vault.totalSupply(), 0);

        uint256 userBalance = assetBalance(user1.addr);
        assertEq(userBalance, _10M);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);

        assertEq(vault.balanceOf(assetManager), 0);
        assertEq(vault.balanceOf(hopperDao), 0);
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
        uint256 expectedManagerNewShares = expectedTotalNewShares -
            expectedProtocolNewShares;

        updateAndSettle(_100M);

        assertEq(vault.balanceOf(address(vault.claimableSilo())), userBalance);
        assertEq(vault.balanceOf(assetManager), expectedManagerNewShares);
        assertEq(vault.balanceOf(hopperDao), expectedProtocolNewShares);
    }
}
