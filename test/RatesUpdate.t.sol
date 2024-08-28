// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, ASSET_MANAGER_ROLE, FEE_RECEIVER, VALORIZATION_ROLE, HOPPER_ROLE} from "@src/Vault.sol";
import {IERC4626, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseTest} from "./Base.sol";
import {FeeManager, AboveMaxRate} from "@src/FeeManager.sol";
import {Rates} from "@src/FeeManager.sol";
import {VaultHelper} from "./VaultHelper.sol";
import {FeeRegistry} from "@src/FeeRegistry.sol";

contract testRateUpdates is BaseTest {
    uint256 public constant MAX_MANAGEMENT_RATE = 1_000; // 10 %
    uint256 public constant MAX_PERFORMANCE_RATE = 5_000; // 50 %
    uint256 public constant MAX_PROTOCOL_RATE = 3_000; // 30 %

    function test_ratesShouldMatchValuesAtInit() public {
        uint256 protocolRate = 100;
        uint256 managementRate = 200;
        uint256 performanceRate = 2000;
        setUpVault(protocolRate, managementRate, performanceRate);
        assertEq(vault.protocolRate(), protocolRate, "protocolRate");
        assertEq(
            vault.feeRates().performanceRate,
            performanceRate,
            "performanceRate"
        );
        assertEq(
            vault.feeRates().managementRate,
            managementRate,
            "managementRate"
        );
    }

    function test_ratesShouldRevertAtInitWhenToHigh() public {
        uint256 protocolRate = MAX_PROTOCOL_RATE + 1;
        uint256 managementRate = MAX_MANAGEMENT_RATE + 1;
        uint256 performanceRate = MAX_PERFORMANCE_RATE + 1;

        feeRegistry = new FeeRegistry();
        feeRegistry.initialize(dao.addr, dao.addr);

        vm.prank(dao.addr);
        feeRegistry.setProtocolRate(protocolRate);
        vault = new VaultHelper(false);

        Vault.InitStruct memory v = Vault.InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valorization: valorizator.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            feeRegistry: address(feeRegistry),
            managementRate: managementRate,
            performanceRate: performanceRate,
            wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
            cooldown: 1 days,
            enableWhitelist: enableWhitelist,
            whitelist: whitelistInit
        });
        vm.expectRevert(
            abi.encodeWithSelector(
                AboveMaxRate.selector,
                managementRate,
                MAX_MANAGEMENT_RATE
            )
        );

        vault.initialize(v);

        v.managementRate = MAX_MANAGEMENT_RATE;

        vm.expectRevert(
            abi.encodeWithSelector(
                AboveMaxRate.selector,
                performanceRate,
                MAX_PERFORMANCE_RATE
            )
        );

        vault.initialize(v);
        v.performanceRate = MAX_PERFORMANCE_RATE;

        vault.initialize(v);
        assertEq(
            vault.protocolRate(),
            MAX_PROTOCOL_RATE,
            "protocol rate should be MAX_PROTOCOL_RATE"
        );
    }

    function test_updateRatesOverMaxPerformanceRateShouldRevert() public {
        setUpVault(100, 200, 2_000);

        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE + 1,
            performanceRate: 0
        });
        vm.startPrank(vault.owner());
        vm.expectRevert(
            abi.encodeWithSelector(
                AboveMaxRate.selector,
                MAX_MANAGEMENT_RATE + 1,
                MAX_MANAGEMENT_RATE
            )
        );
        vault.updateRates(newRates);

        newRates.managementRate = 0;
        newRates.performanceRate = MAX_PERFORMANCE_RATE + 1;

        vm.startPrank(vault.owner());
        vm.expectRevert(
            abi.encodeWithSelector(
                AboveMaxRate.selector,
                MAX_PERFORMANCE_RATE + 1,
                MAX_PERFORMANCE_RATE
            )
        );
        vault.updateRates(newRates);
    }

    function test_updateRatesShouldBeApplyed24HoursAfter() public {
        setUpVault(100, 200, 200);

        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE,
            performanceRate: MAX_PERFORMANCE_RATE
        });
        assertNotEq(200, MAX_MANAGEMENT_RATE);
        assertNotEq(200, MAX_PERFORMANCE_RATE);
        vm.startPrank(vault.owner());
        vault.updateRates(newRates);

        assertEq(
            200,
            vault.feeRates().performanceRate,
            "performance rate after update"
        );
        assertEq(
            200,
            vault.feeRates().managementRate,
            "management rate after update"
        );

        vm.warp(block.timestamp + 1 days - 1);
        assertEq(
            200,
            vault.feeRates().performanceRate,
            "performance rate after 1st warp"
        );
        assertEq(
            200,
            vault.feeRates().managementRate,
            "management rate after 1st warp"
        );

        vm.warp(block.timestamp + 1 days);

        assertEq(
            MAX_PERFORMANCE_RATE,
            vault.feeRates().performanceRate,
            "performance rate after 2nd warp"
        );
        assertEq(
            MAX_MANAGEMENT_RATE,
            vault.feeRates().managementRate,
            "management rate after 2nd warp"
        );
    }

    function test_updateRatesShouldBeApplyed24HoursAfter_VerifyThroughASettle()
        public
    {
        setUpVault(100, 0, 0); // no fees will be taken
        address feeReceiver = vault.feeReceiver();
        assertEq(
            vault.balanceOf(feeReceiver),
            0,
            "fee receiver should have 0 shares, init"
        );
        dealAmountAndApproveAndWhitelist(user1.addr, 1000);
        requestDeposit(1000, user1.addr);
        updateAndSettle(0);
        assertEq(
            vault.balanceOf(feeReceiver),
            0,
            "fee receiver should have 0 shares, first settle"
        );
        updateTotalAssets(2000);
        vm.warp(block.timestamp + 1 days);
        // owner updates rates
        Rates memory newRates = Rates({
            managementRate: MAX_MANAGEMENT_RATE,
            performanceRate: MAX_PERFORMANCE_RATE
        });

        vm.startPrank(vault.owner());

        vault.updateRates(newRates);
        vm.stopPrank();
        settle();
        assertEq(
            vault.balanceOf(feeReceiver),
            0,
            "fee receiver should have 0 shares, 2nd settle"
        );

        updateAndSettle(4000); // +100%
        assertNotEq(
            vault.balanceOf(feeReceiver),
            0,
            "fee receiver should have shares"
        );
    }
}
