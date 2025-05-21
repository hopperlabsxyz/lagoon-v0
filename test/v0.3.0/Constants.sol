// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";

import {Options, Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {BeaconProxyFactory, InitStruct as BeaconProxyInitStruct} from "@src/BeaconProxyFactory.sol";

contract Constants is Test {
    // ERC20 tokens
    string network = vm.envString("NETWORK");
    ERC20 immutable underlying = ERC20(vm.envAddress("ASSET"));
    address immutable WRAPPED_NATIVE_TOKEN = vm.envAddress(string.concat("WRAPPED_NATIVE_TOKEN_", network));
    bool underlyingIsNativeToken = address(underlying) == WRAPPED_NATIVE_TOKEN;
    bool proxy = vm.envBool("PROXY");
    BeaconProxyFactory factory;

    uint8 decimalsOffset = 0;

    VaultHelper vault;
    FeeRegistry feeRegistry;
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
        feeRegistry = new FeeRegistry(false);
        feeRegistry.initialize(dao.addr, dao.addr);

        vm.prank(dao.addr);
        feeRegistry.updateDefaultRate(_protocolRate);

        Options memory opts;
        bool disableImplementationInit = proxy;
        opts.constructorData = abi.encode(disableImplementationInit);
        address implementation = address(new VaultHelper(disableImplementationInit));
        // Upgrades.deployImplementation("v0.3.0/VaultHelper.sol:VaultHelper", opts);

        factory = new BeaconProxyFactory(address(feeRegistry), implementation, dao.addr, WRAPPED_NATIVE_TOKEN);

        BeaconProxyInitStruct memory initStruct = BeaconProxyInitStruct({
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
            address vaultHelper = factory.createVaultProxy(initStruct, keccak256("42"));
            vault = VaultHelper(vaultHelper);
        } else {
            vault = VaultHelper(implementation);
            vault.initialize(abi.encode(initStruct), address(feeRegistry), WRAPPED_NATIVE_TOKEN);
        }

        if (enableWhitelist) {
            whitelistInit.push(feeReceiver.addr);
            whitelistInit.push(dao.addr);
            whitelistInit.push(safe.addr);
            whitelistInit.push(vault.pendingSilo());
            whitelistInit.push(address(feeRegistry));
            vm.prank(whitelistManager.addr);
            vault.addToWhitelist(whitelistInit);
        }

        vm.label(address(vault), vaultName);
        vm.label(vault.pendingSilo(), "vault.pendingSilo");
    }
}
