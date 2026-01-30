// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";

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

    // function test_ratesShouldRevertAtInitWhenToHigh() public {
    //     uint16 protocolRate = MAX_PROTOCOL_RATE + 1;
    //     uint16 managementRate = MAX_MANAGEMENT_RATE + 1;
    //     uint16 performanceRate = MAX_PERFORMANCE_RATE + 1;

    //     feeRegistry = new FeeRegistry(false);
    //     feeRegistry.initialize(dao.addr, dao.addr);

    //     vm.prank(dao.addr);
    //     feeRegistry.updateDefaultRate(protocolRate);
    //     vault = new VaultHelper(false);

    //     Vault.InitStruct memory v = Vault.InitStruct({
    //         underlying: underlying,
    //         name: vaultName,
    //         symbol: vaultSymbol,
    //         safe: safe.addr,
    //         whitelistManager: whitelistManager.addr,
    //         valuationManager: valuationManager.addr,
    //         admin: admin.addr,
    //         feeReceiver: feeReceiver.addr,
    //         feeRegistry: address(feeRegistry),
    //         managementRate: managementRate,
    //         performanceRate: performanceRate,
    //         wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
    //         rateUpdateCooldown: rateUpdateCooldown,
    //         enableWhitelist: enableWhitelist
    //     });
    //     vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_MANAGEMENT_RATE));

    //     vault.initialize(v);

    //     v.managementRate = MAX_MANAGEMENT_RATE;

    //     vm.expectRevert(abi.encodeWithSelector(AboveMaxRate.selector, MAX_PERFORMANCE_RATE));

    //     vault.initialize(v);
    //     v.performanceRate = MAX_PERFORMANCE_RATE;

    //     vault.initialize(v);
    //     assertEq(vault.protocolRate(), MAX_PROTOCOL_RATE, "protocol rate should be MAX_PROTOCOL_RATE");
    // }

    function test_updateRatesOverMaxPerformanceRateShouldRevert() public {
        setUpVault(100, 200, 2000);

        Rates memory newRates =
            Rates({managementRate: MAX_MANAGEMENT_RATE + 1, performanceRate: 0, entryRate: 0, exitRate: 0});
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
            managementRate: MAX_MANAGEMENT_RATE, performanceRate: MAX_PERFORMANCE_RATE, entryRate: 0, exitRate: 0
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
        assertEq(vault.balanceOf(feeReceiver), 0, "fee receiver should have 0 shares, first settle");
        updateNewTotalAssets(2000);
        vm.warp(block.timestamp + 1 days);
        // owner updates rates
        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE, performanceRate: MAX_PERFORMANCE_RATE, entryRate: 0, exitRate: 0
        });

        vm.startPrank(vault.owner());

        vault.updateRates(newRates);
        vm.stopPrank();
        settle();

        assertNotEq(vault.balanceOf(feeReceiver), 0, "fee receiver should have shares");
    }

    function test_updateRates_shouldWorkWhenClosing() public {
        setUpVault(100, 200, 200);

        vm.prank(vault.owner());
        vault.initiateClosing();
        assertEq(uint256(vault.state()), uint256(State.Closing), "vault should be in Closing state");

        Rates memory newRates = Rates({managementRate: 300, performanceRate: 300, entryRate: 0, exitRate: 0});
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
        Rates memory newRates = Rates({managementRate: 300, performanceRate: 300, entryRate: 0, exitRate: 0});
        vm.prank(vault.owner());
        vm.expectRevert(Closed.selector);
        vault.updateRates(newRates);
    }
}
