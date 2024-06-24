// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {BaseTest} from "./Base.t.sol";

contract TestFeeManager is BaseTest {
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
        setProtocolFee(100, vault.vaultAM());
        setPerformanceFee(100, vault.vaultAM());
        setManagementFee(100, vault.vaultHopper());

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
        setPerformanceFee(100, vault.vaultAM()); // 1% fees on net AUM if above high water mark

        assertEq(vault.calculatePerformanceFee(_100M), _1M);
        assertEq(vault.calculatePerformanceFee(_10M), _100K);
        assertEq(vault.calculatePerformanceFee(_1M), _10K);
        assertEq(vault.calculatePerformanceFee(_100K), _1K);
    }

    function test_management_fees() public {
        setManagementFee(100, vault.vaultAM()); // 1% fees on average AUM since last NAV

        vm.warp(vm.getBlockTimestamp() + 365 days);

        assertEq(vault.calculateManagementFee(_100M), _1M);
        assertEq(vault.calculateManagementFee(_10M), _100K);
        assertEq(vault.calculateManagementFee(_1M), _10K);
        assertEq(vault.calculateManagementFee(_100K), _1K);
    }

    function test_protocol_fees() public {
        setProtocolFee(100, vault.vaultAM()); // 1% fees on total fees collected

        (uint256 managerFees, uint256 protocolFees) = vault
            .calculateProtocolFee(_100M);
        assertEq(managerFees, _100M - _1M);
        assertEq(protocolFees, _1M);

        (managerFees, protocolFees) = vault.calculateProtocolFee(_10M);
        assertEq(managerFees, _10M - _100K);
        assertEq(protocolFees, _100K);
    }
}
