// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {VaultHelper as VaultHelper_v0_5_0} from "../v0.5.0-opt-inProxy/VaultHelper.sol";
import {VaultHelper as VaultHelper_v0_6_0} from "../v0.6.0/VaultHelper.sol";
import {BaseTest} from "./Base.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    InitStruct as InitStruct_v0_5_0,
    OptinProxyFactory as OptinProxyFactory_v0_5_0
} from "@src/protocol-v2/OptinProxyFactory.sol";

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {DelayProxyAdmin} from "@src/proxy/DelayProxyAdmin.sol";

contract TestStorageCollision is BaseTest {
    uint16 public constant _managementRate = 1;
    uint16 public constant _performanceRate = 2;
    uint16 public constant _entryRate = 3;
    uint16 public constant _exitRate = 5;
    DelayProxyAdmin public delayProxyAdmin;
    VaultHelper_v0_5_0 public _vault;
    // address of vault pointing to the v0.6.0
    VaultHelper_v0_6_0 public proxyV0_6_0;

    function setUp() public {
        vm.startPrank(dao.addr);
        protocolRegistry.updateDefaultLogic(address(vault_v0_5_0));
        vm.stopPrank();

        // setup the factory
        OptinProxyFactory_v0_5_0 factory = new OptinProxyFactory_v0_5_0(false);

        factory.initialize(address(protocolRegistry), WRAPPED_NATIVE_TOKEN, dao.addr);

        InitStruct_v0_5_0 memory initStruct = InitStruct_v0_5_0({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            enableWhitelist: enableWhitelist,
            managementRate: _managementRate,
            performanceRate: _performanceRate,
            rateUpdateCooldown: 1 days
        });

        _vault = VaultHelper_v0_5_0(
            OptinProxyFactory_v0_5_0(address(factory))
                .createVaultProxy({
                    _logic: address(0),
                    _initialOwner: initStruct.admin,
                    _initialDelay: 86_400,
                    _init: initStruct,
                    salt: keccak256("42")
                })
        );
        proxyV0_6_0 = VaultHelper_v0_6_0(address(_vault));
        assertEq(_vault.version(), "v0.5.0");
        delayProxyAdmin = DelayProxyAdmin(vm.computeCreateAddress(address(_vault), 2));

        assertEq(delayProxyAdmin.owner(), initStruct.admin);
    }

    // we update the vault from v0.5.0 to v0.6.0 and assess fees storage health
    function test_storageCollision() public {
        address owner = delayProxyAdmin.owner();

        vm.prank(owner);
        delayProxyAdmin.submitImplementation(address(vault_v0_6_0));

        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        delayProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_vault)), address(vault_v0_6_0), "");
        assertEq(_vault.version(), "v0.6.0", "vault should be upgraded to v0.6.0");

        // asserting all fees rates are the same
        assertEq(proxyV0_6_0.feeRates().managementRate, _managementRate);
        assertEq(proxyV0_6_0.feeRates().performanceRate, _performanceRate);
        assertEq(proxyV0_6_0.feeRates().entryRate, 0);
        assertEq(proxyV0_6_0.feeRates().exitRate, 0);

        // we update the fees rates
        vm.prank(owner);
        proxyV0_6_0.updateRates(Rates({managementRate: 10, performanceRate: 11, entryRate: 12, exitRate: 13}));

        vm.warp(block.timestamp + 1 days + 1);

        assertEq(proxyV0_6_0.feeRates().managementRate, 10);
        assertEq(proxyV0_6_0.feeRates().performanceRate, 11);
        assertEq(proxyV0_6_0.feeRates().entryRate, 12);
        assertEq(proxyV0_6_0.feeRates().exitRate, 13);
    }
}
