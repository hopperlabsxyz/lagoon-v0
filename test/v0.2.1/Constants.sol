// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/console.sol";

import {Options, Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

abstract contract Constants is Test {
    // ERC20 tokens
    string network = vm.envString("NETWORK");
    ERC20Permit immutable USDC = ERC20Permit(vm.envAddress(string.concat("USDC_", network)));
    ERC20 immutable WETH = ERC20(vm.envAddress(string.concat("WETH_", network)));
    address immutable WRAPPED_NATIVE_TOKEN = vm.envAddress(string.concat("WRAPPED_NATIVE_TOKEN_", network));
    ERC20 immutable WBTC = ERC20(vm.envAddress(string.concat("WBTC_", network)));
    ERC20 immutable ETH = ERC20(vm.envAddress(string.concat("ETH_", network)));

    uint8 decimalsOffset = 0;

    string underlyingName = vm.envString("UNDERLYING_NAME");

    VaultHelper vault;
    FeeRegistry feeRegistry;
    string vaultName = "vault_";
    string vaultSymbol = "hop_vault_";
    uint256 rateUpdateCooldown = 1 days;

    //Underlying
    ERC20 underlying = ERC20(vm.envAddress(string.concat(underlyingName, "_", network)));
    ERC20Permit immutable underlyingPermit;

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
        vaultName = string.concat(vaultName, underlyingName);
        vaultSymbol = string.concat(vaultSymbol, underlyingName);

        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(ETH), "ETH");
        vm.label(address(WBTC), "WBTC");

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

    function _beaconDeploy(
        string memory contractName,
        address _owner,
        Options memory opts
    ) internal returns (UpgradeableBeacon) {
        return UpgradeableBeacon(Upgrades.deployBeacon(contractName, _owner, opts));
    }

    function _proxyDeploy(UpgradeableBeacon beacon, InitStruct memory v) internal returns (VaultHelper) {
        BeaconProxy proxy =
            BeaconProxy(payable(Upgrades.deployBeaconProxy(address(beacon), abi.encodeCall(Vault0_2_1.initialize, v))));

        return VaultHelper(address(proxy));
    }

    function setUpVault(uint16 _protocolRate, uint16 _managementRate, uint16 _performanceRate) internal {
        bool proxy = vm.envBool("PROXY");

        feeRegistry = new FeeRegistry(false);
        feeRegistry.initialize(dao.addr, dao.addr);

        vm.prank(dao.addr);
        feeRegistry.updateDefaultRate(_protocolRate);

        UpgradeableBeacon beacon;
        InitStruct memory v = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            feeRegistry: address(feeRegistry),
            managementRate: _managementRate,
            performanceRate: _performanceRate,
            wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
            rateUpdateCooldown: rateUpdateCooldown,
            enableWhitelist: enableWhitelist
        });
        // function upgradeBeacon(address beacon, string memory contractName) internal {
        //         Options memory opts;
        //         Core.upgradeBeacon(beacon, contractName, opts);
        //     }

        if (proxy) {
            Options memory opts;
            opts.constructorData = abi.encode(true);
            beacon = _beaconDeploy("Vault0.2.1Helper.sol:Vault0_2_1Helper", owner.addr, opts);
            vault = _proxyDeploy(beacon, v);
            opts.constructorData = abi.encode(false);
            vm.startPrank(owner.addr);
            Upgrades.upgradeBeacon(address(beacon), "Vault0.3.0Helper.sol:Vault0_3_0Helper", opts);
            vm.stopPrank();
            VaultHelper(address(vault));
        } else {
            vm.startPrank(owner.addr);
            vault = new VaultHelper(false);
            vault.initialize(v);
            vm.stopPrank();
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

        // console.log(feeReceiver.addr);
        // console.log(dao.addr);
        // console.log(assetManager.addr);
        // console.log(whitelistManager.addr);
        // console.log(valuationManager.addr);
        // console.log(admin.addr);
        // console.log(vault.pendingSilo());
        // console.log(address(0));

        vm.label(address(vault), vaultName);
        vm.label(vault.pendingSilo(), "vault.pendingSilo");
        // vm.label(vault.claimableSilo(), "vault.claimableSilo");
    }
}
