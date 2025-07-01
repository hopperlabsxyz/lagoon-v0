// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";

import {Options, Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

// import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ProtocolRegistry} from "@src/protocol-v0.2.0/ProtocolRegistry.sol";

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {InitStruct as ProxyInitStruct, OptinProxyFactory} from "@src/protocol-v0.2.0/OptinProxyFactory.sol";

contract Constants is Test {
    // ERC20 tokens
    ERC20 immutable underlying = ERC20(vm.envAddress("ASSET"));
    address immutable WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");
    bool underlyingIsNativeToken = address(underlying) == WRAPPED_NATIVE_TOKEN;

    bool proxy = vm.envBool("PROXY");
    OptinProxyFactory factory;

    uint8 decimalsOffset = 0;
    VaultHelper vault;
    ProtocolRegistry protocolRegistry;
    string vaultName = "vault_name";
    string vaultSymbol = "vault_symbol";
    uint256 rateUpdateCooldown = 1 days;

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

    VmSafe.Wallet[] users;

    address[] whitelistInit = new address[](0);
    bool enableWhitelist = true;

    // Wallet
    VmSafe.Wallet address0 = VmSafe.Wallet({addr: address(0), publicKeyX: 0, publicKeyY: 0, privateKey: 0});

    int256 immutable bipsDividerSigned = 10_000;
    address implementation;

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
    }

    function setUpVault(uint16 _protocolRate, uint16 _managementRate, uint16 _performanceRate) internal {
        protocolRegistry = new ProtocolRegistry(false);
        protocolRegistry.initialize(dao.addr, dao.addr);

        vm.prank(dao.addr);
        protocolRegistry.updateDefaultRate(_protocolRate);

        Options memory opts;
        bool disableImplementationInit = proxy;
        opts.constructorData = abi.encode(disableImplementationInit);
        implementation = address(new VaultHelper(disableImplementationInit));

        // First we deploy the factory and initialize it
        factory = new OptinProxyFactory();
        factory.initialize(address(protocolRegistry), WRAPPED_NATIVE_TOKEN, dao.addr);

        // we add an implementation
        vm.prank(dao.addr);
        protocolRegistry.updateDefaultLogic(implementation);
        ProxyInitStruct memory initStruct = ProxyInitStruct({
            underlying: address(underlying),
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: _managementRate,
            performanceRate: _performanceRate,
            rateUpdateCooldown: rateUpdateCooldown,
            enableWhitelist: enableWhitelist
        });
        if (proxy) {
            address vaultHelper = factory.createVaultProxy(address(0), initStruct.admin, initStruct, keccak256("42"));
            vault = VaultHelper(vaultHelper);
        } else {
            vault = VaultHelper(implementation);
            vault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);
        }

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
