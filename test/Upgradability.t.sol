// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {IVersion} from "./IVersion.sol";

import {Options, Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {Vault} from "@src/v0.1.0/Vault.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract Upgradable is Test {
    // ERC20 tokens
    string network = vm.envString("NETWORK");
    ERC20Permit immutable USDC =
        ERC20Permit(vm.envAddress(string.concat("USDC_", network)));
    ERC20 immutable WETH =
        ERC20(vm.envAddress(string.concat("WETH_", network)));
    address immutable WRAPPED_NATIVE_TOKEN =
        vm.envAddress(string.concat("WRAPPED_NATIVE_TOKEN_", network));
    ERC20 immutable WBTC =
        ERC20(vm.envAddress(string.concat("WBTC_", network)));
    ERC20 immutable ETH = ERC20(vm.envAddress(string.concat("ETH_", network)));

    uint8 decimalsOffset = 0;

    string underlyingName = vm.envString("UNDERLYING_NAME");

    FeeRegistry feeRegistry;
    string vaultName = "vault_";
    string vaultSymbol = "hop_vault_";
    uint256 rateUpdateCooldown = 1 days;

    //Underlying
    ERC20 underlying =
        ERC20(vm.envAddress(string.concat(underlyingName, "_", network)));
    ERC20Permit immutable underlyingPermit;

    // Users
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
    VmSafe.Wallet address0 =
        VmSafe.Wallet({
            addr: address(0),
            publicKeyX: 0,
            publicKeyY: 0,
            privateKey: 0
        });

    int256 immutable bipsDividerSigned = 10_000;

    constructor() {
        vaultName = string.concat(vaultName, underlyingName);
        vaultSymbol = string.concat(vaultSymbol, underlyingName);
    }

    function _beaconDeploy(
        string memory contractName,
        address _owner,
        Options memory opts
    ) internal returns (UpgradeableBeacon) {
        return
            UpgradeableBeacon(
                Upgrades.deployBeacon(contractName, _owner, opts)
            );
    }

    function _proxyDeploy(
        UpgradeableBeacon beacon,
        Vault.InitStruct memory v
    ) internal returns (address) {
        BeaconProxy proxy = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(Vault.initialize, v)
                )
            )
        );

        return address(proxy);
    }

    function test_upgradeable() public {
        feeRegistry = new FeeRegistry(false);
        feeRegistry.initialize(dao.addr, dao.addr);

        vm.prank(dao.addr);
        feeRegistry.updateDefaultRate(50);

        UpgradeableBeacon beacon;
        Vault.InitStruct memory v = Vault.InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            feeRegistry: address(feeRegistry),
            managementRate: 200,
            performanceRate: 2000,
            wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
            rateUpdateCooldown: rateUpdateCooldown,
            enableWhitelist: enableWhitelist
        });

        Options memory opts;
        opts.constructorData = abi.encode(true);
        beacon = _beaconDeploy("v0.1.0/Vault.sol:Vault", owner.addr, opts);
        address vault = _proxyDeploy(beacon, v);

        opts.constructorData = abi.encode(false);
        vm.startPrank(owner.addr);
        Upgrades.upgradeBeacon(address(beacon), "v0.2.0/Vault.sol:Vault", opts);
        Upgrades.upgradeBeacon(address(beacon), "v0.3.0/Vault.sol:Vault", opts);
        assertEq(
            keccak256(abi.encode(IVersion(vault).version())),
            keccak256(abi.encode("v0.3.0"))
        );
        Upgrades.upgradeBeacon(address(beacon), "v0.4.0/Vault.sol:Vault", opts);
        assertEq(
            keccak256(abi.encode(IVersion(vault).version())),
            keccak256(abi.encode("v0.4.0"))
        );
        Upgrades.upgradeBeacon(address(beacon), "v0.5.0/Vault.sol:Vault", opts);
        assertEq(
            keccak256(abi.encode(IVersion(vault).version())),
            keccak256(abi.encode("v0.5.0"))
        );
        vm.stopPrank();
    }
}
