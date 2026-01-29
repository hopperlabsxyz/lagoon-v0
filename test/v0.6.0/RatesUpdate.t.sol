// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";

import {BaseTest} from "./Base.sol";

contract testRateUpdates is BaseTest {
    uint16 public constant MAX_MANAGEMENT_RATE = 1000; // 10 %
    uint16 public constant MAX_PERFORMANCE_RATE = 5000; // 50 %
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30 %

    function test_ratesShouldMatchValuesAtInit() public {
        uint16 protocolRate = 100;
        uint16 managementRate = 200;
        uint16 performanceRate = 2000;
        setUpVault(protocolRate, managementRate, performanceRate);
        assertEq(vault.protocolRate(), protocolRate, "protocolRate");
        assertEq(vault.feeRates().performanceRate, performanceRate, "performanceRate");
        assertEq(vault.feeRates().managementRate, managementRate, "managementRate");
    }

    function test_updateRatesOverMaxPerformanceRateShouldRevert() public {
        setUpVault(100, 200, 2000);

        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE + 1, performanceRate: 0, entryRate: 0, exitRate: 0, haircutRate: 0
        });
        vm.startPrank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_MANAGEMENT_RATE));
        vault.updateRates(newRates);

        newRates.managementRate = 0;
        newRates.performanceRate = MAX_PERFORMANCE_RATE + 1;

        vm.startPrank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_PERFORMANCE_RATE));
        vault.updateRates(newRates);
    }

    function test_updateRatesShouldBeApplyed24HoursAfter() public {
        setUpVault(100, 200, 200);

        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE,
            performanceRate: MAX_PERFORMANCE_RATE,
            entryRate: 0,
            exitRate: 0,
            haircutRate: 0
        });
        assertNotEq(200, MAX_MANAGEMENT_RATE);
        assertNotEq(200, MAX_PERFORMANCE_RATE);
        vm.startPrank(vault.owner());
        vault.updateRates(newRates);

        assertEq(200, vault.feeRates().performanceRate, "performance rate after update");
        assertEq(200, vault.feeRates().managementRate, "management rate after update");

        vm.warp(block.timestamp + 1 days - 1);
        assertEq(200, vault.feeRates().performanceRate, "performance rate after 1st warp");
        assertEq(200, vault.feeRates().managementRate, "management rate after 1st warp");

        vm.warp(block.timestamp + 1 days);

        assertEq(MAX_PERFORMANCE_RATE, vault.feeRates().performanceRate, "performance rate after 2nd warp");
        assertEq(MAX_MANAGEMENT_RATE, vault.feeRates().managementRate, "management rate after 2nd warp");
    }

    function test_updateRatesShouldBeApplyed24HoursAfter_VerifyThroughASettle() public {
        setUpVault(100, 0, 0); // no fees will be taken
        address feeReceiver = vault.feeReceiver();
        assertEq(vault.balanceOf(feeReceiver), 0, "fee receiver should have 0 shares, init");
        dealAmountAndApproveAndWhitelist(user1.addr, 1000);
        requestDeposit(1000, user1.addr);
        updateAndSettle(0);
        vm.warp(block.timestamp + 1);
        assertEq(vault.balanceOf(feeReceiver), 0, "fee receiver should have 0 shares, first settle");
        updateNewTotalAssets(2000);
        vm.warp(block.timestamp + 1 days);
        // owner updates rates
        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE,
            performanceRate: MAX_PERFORMANCE_RATE,
            entryRate: 0,
            exitRate: 0,
            haircutRate: 0
        });

        vm.startPrank(vault.owner());

        vault.updateRates(newRates);
        vm.stopPrank();
        settle();
        assertEq(vault.balanceOf(feeReceiver), 0, "fee receiver should have 0 shares, 2nd settle");
        vm.warp(block.timestamp + 1);
        updateAndSettle(4000); // +100%
        assertNotEq(vault.balanceOf(feeReceiver), 0, "fee receiver should have shares");
    }
}
