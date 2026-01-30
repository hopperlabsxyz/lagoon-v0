// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {VaultHelper as VaultHelper_v0_5_0} from "../v0.5.0-opt-inProxy/VaultHelper.sol";
import {VaultHelper as VaultHelper_v0_6_0} from "../v0.6.0/VaultHelper.sol";
import {VaultHelper} from "./VaultHelper.sol";

import {Options, Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {InitStruct, OptinProxyFactory as OptionProxyFactory_protocolV3} from "@src/protocol-v3/OptinProxyFactory.sol";

contract SetUp is Test {
    // ERC20 tokens
    ERC20 immutable underlying = ERC20(vm.envAddress("ASSET"));
    address immutable WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");
    bool underlyingIsNativeToken = address(underlying) == WRAPPED_NATIVE_TOKEN;

    bool proxy = vm.envBool("PROXY");
    OptionProxyFactory_protocolV3 factory;

    uint8 decimalsOffset;
    VaultHelper vault;
    ProtocolRegistry protocolRegistry;
    string vaultName = "vault_name";
    string vaultSymbol = "vault_symbol";
    uint256 rateUpdateCooldown = 0;

    // Users
    VmSafe.Wallet user1 = vm.createWallet("user1");
    VmSafe.Wallet user2 = vm.createWallet("user2");
    VmSafe.Wallet user3 = vm.createWallet("user3");
    VmSafe.Wallet user4 = vm.createWallet("user4");
    VmSafe.Wallet user5 = vm.createWallet("user5");
    VmSafe.Wallet user6 = vm.createWallet("user6");
    VmSafe.Wallet user7 = vm.createWallet("user7");
    VmSafe.Wallet user8 = vm.createWallet("user8");
    VmSafe.Wallet user9 = vm.createWallet("user9");
    VmSafe.Wallet user10 = vm.createWallet("user10");
    VmSafe.Wallet owner = vm.createWallet("owner");
    VmSafe.Wallet safe = vm.createWallet("safe");
    VmSafe.Wallet valuationManager = vm.createWallet("valuationManager");
    VmSafe.Wallet admin = vm.createWallet("admin");
    VmSafe.Wallet feeReceiver = vm.createWallet("feeReceiver");
    VmSafe.Wallet dao = vm.createWallet("dao");
    VmSafe.Wallet whitelistManager = vm.createWallet("whitelistManager");

    // Implementations
    VaultHelper_v0_5_0 vault_v0_5_0 = new VaultHelper_v0_5_0(false);
    VaultHelper_v0_6_0 vault_v0_6_0 = new VaultHelper_v0_6_0(false);

    VmSafe.Wallet[] users;

    address[] whitelistInit = new address[](0);
    bool enableWhitelist = true;

    // Wallet
    VmSafe.Wallet address0 = VmSafe.Wallet({addr: address(0), publicKeyX: 0, publicKeyY: 0, privateKey: 0});

    int256 immutable bipsDividerSigned = 10_000;

    constructor() {
        users.push(user1);
        users.push(user2);
        users.push(user3);
        users.push(user4);
        users.push(user5);
        users.push(user6);
        users.push(user7);
        users.push(user8);
        users.push(user9);
        users.push(user10);

        protocolRegistry = new ProtocolRegistry(false);
        protocolRegistry.initialize(dao.addr, dao.addr);

        // we update the default logic to the v0.6.0 vault helper
        vm.prank(dao.addr);
        protocolRegistry.updateDefaultLogic(address(vault_v0_6_0));

        factory = new OptionProxyFactory_protocolV3(false);
        factory.initialize(address(protocolRegistry), WRAPPED_NATIVE_TOKEN, dao.addr);
    }

    function setUpVault(
        uint16 _protocolRate,
        uint16 _managementRate,
        uint16 _performanceRate
    ) internal {
        return setUpVault(_protocolRate, _managementRate, _performanceRate, 0, 0);
    }

    function setUpVault(
        uint16 _protocolRate,
        uint16 _managementRate,
        uint16 _performanceRate,
        uint16 _entryRate,
        uint16 _exitRate
    ) internal {
        vm.prank(dao.addr);
        protocolRegistry.updateDefaultRate(_protocolRate);

        InitStruct memory initStruct = InitStruct({
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
            entryRate: _entryRate,
            exitRate: _exitRate
        });
        // if proxy is true, we use the factory to create the vault proxy
        if (proxy) {
            address vaultHelper = factory.createVaultProxy({
                _logic: address(0),
                _initialOwner: initStruct.admin,
                _initialDelay: 86_400,
                _init: initStruct,
                salt: keccak256("42")
            });
            vault = VaultHelper(vaultHelper);
        } else {
            // if proxy is false, we use the implementation directly
            vault = VaultHelper(new VaultHelper(false)); // we deploy a new vault helper
            vault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);
        }

        // if whitelist is enabled, we whitelist a set of addresses to ease the testing
        if (enableWhitelist) {
            whitelistInit.push(feeReceiver.addr);
            whitelistInit.push(dao.addr);
            whitelistInit.push(safe.addr);
            whitelistInit.push(vault.pendingSilo());
            whitelistInit.push(address(protocolRegistry));
            vm.prank(whitelistManager.addr);
            vault.addToWhitelist(whitelistInit);
        }

        vm.label(address(vault), vaultName);
        vm.label(vault.pendingSilo(), "vault.pendingSilo");
    }
}
