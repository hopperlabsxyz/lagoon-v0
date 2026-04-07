// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";

import {BaseTest} from "./Base.sol";

contract testRateUpdates is BaseTest {
    uint16 public constant MAX_MANAGEMENT_RATE = FeeLib.MAX_MANAGEMENT_RATE;
    uint16 public constant MAX_PERFORMANCE_RATE = FeeLib.MAX_PERFORMANCE_RATE;
    uint16 public constant MAX_ENTRY_RATE = FeeLib.MAX_ENTRY_RATE;
    uint16 public constant MAX_EXIT_RATE = FeeLib.MAX_EXIT_RATE;
    uint16 public constant MAX_HAIRCUT_RATE = FeeLib.MAX_HAIRCUT_RATE;

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

    function test_updateRatesShouldBeAppliedImmediately() public {
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

        assertEq(MAX_PERFORMANCE_RATE, vault.feeRates().performanceRate, "performance rate after update");
        assertEq(MAX_MANAGEMENT_RATE, vault.feeRates().managementRate, "management rate after update");
    }

    function test_updateRatesShouldBeAppliedImmediately_VerifyThroughASettle() public {
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
        // Note: fees ARE taken here because rates are applied immediately and time has passed
        vm.warp(block.timestamp + 1);
        updateAndSettle(4000); // +100%

        assertNotEq(vault.balanceOf(feeReceiver), 0, "fee receiver should have shares");
    }

    function test_updateRates_shouldWorkWhenClosing() public {
        setUpVault(100, 200, 200);

        vm.prank(vault.owner());
        vault.initiateClosing();
        assertEq(uint256(vault.state()), uint256(State.Closing), "vault should be in Closing state");

        Rates memory newRates =
            Rates({managementRate: 300, performanceRate: 300, entryRate: 0, exitRate: 0, haircutRate: 0});
        vm.prank(vault.owner());
        vault.updateRates(newRates);
    }

    function test_updateRates_shouldRevertWhenClosed() public {
        setUpVault(100, 200, 200);
        dealAndApproveAndWhitelist(user1.addr);

        // Need some activity to close properly
        requestDeposit(1000, user1.addr);
        updateAndSettle(0);
        deposit(1000, user1.addr);

        // Initiate closing then close
        vm.prank(vault.owner());
        vault.initiateClosing();

        updateAndClose(1000);
        assertEq(uint256(vault.state()), uint256(State.Closed), "vault should be in Closed state");

        // Update rates should revert in Closed state
        Rates memory newRates =
            Rates({managementRate: 300, performanceRate: 300, entryRate: 0, exitRate: 0, haircutRate: 0});
        vm.prank(vault.owner());
        vm.expectRevert(Closed.selector);
        vault.updateRates(newRates);
    }

    function test_updateRatesOverMaxEntryRateShouldRevert() public {
        setUpVault(100, 200, 2000);

        Rates memory newRates =
            Rates({managementRate: 0, performanceRate: 0, entryRate: MAX_ENTRY_RATE + 1, exitRate: 0, haircutRate: 0});
        vm.startPrank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_ENTRY_RATE));
        vault.updateRates(newRates);
    }

    function test_updateRatesOverMaxExitRateShouldRevert() public {
        setUpVault(100, 200, 2000);

        Rates memory newRates =
            Rates({managementRate: 0, performanceRate: 0, entryRate: 0, exitRate: MAX_EXIT_RATE + 1, haircutRate: 0});
        vm.startPrank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_EXIT_RATE));
        vault.updateRates(newRates);
    }

    function test_updateRatesOverMaxHaircutRateShouldRevert() public {
        setUpVault(100, 200, 2000);

        Rates memory newRates = Rates({
            managementRate: 0, performanceRate: 0, entryRate: 0, exitRate: 0, haircutRate: MAX_HAIRCUT_RATE + 1
        });
        vm.startPrank(vault.owner());
        vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_HAIRCUT_RATE));
        vault.updateRates(newRates);
    }
}
