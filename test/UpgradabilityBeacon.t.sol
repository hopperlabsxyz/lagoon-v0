// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {IVersion} from "./IVersion.sol";

import {Options, Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {InitStruct, Vault} from "@src/v0.5.0/Vault.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract Upgradable is Test {
    // ERC20 tokens
    ERC20 immutable underlying = ERC20(vm.envAddress("ASSET"));
    address immutable WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");
    bool underlyingIsNativeToken = address(underlying) == WRAPPED_NATIVE_TOKEN;

    uint8 decimalsOffset = 0;

    FeeRegistry feeRegistry;
    string vaultName = "vault_name";
    string vaultSymbol = "vault_symbol";
    uint256 rateUpdateCooldown = 1 days;

    //Underlying

    // Users
    VmSafe.Wallet owner = vm.createWallet("owner");
    VmSafe.Wallet safe = vm.createWallet("safe");
    VmSafe.Wallet valuationManager = vm.createWallet("valuationManager");
    VmSafe.Wallet admin = vm.createWallet("admin");
    VmSafe.Wallet feeReceiver = vm.createWallet("feeReceiver");
    VmSafe.Wallet dao = vm.createWallet("dao");
    VmSafe.Wallet whitelistManager = vm.createWallet("whitelistManager");
    bool doProxy = vm.envBool("PROXY");

    VmSafe.Wallet[] users;

    address[] whitelistInit = new address[](0);
    bool enableWhitelist = true;

    // Wallet
    VmSafe.Wallet address0 = VmSafe.Wallet({addr: address(0), publicKeyX: 0, publicKeyY: 0, privateKey: 0});

    int256 immutable bipsDividerSigned = 10_000;

    function test_upgradeable() public {
        if (!doProxy) return;
        feeRegistry = new FeeRegistry(false);
        feeRegistry.initialize(dao.addr, dao.addr);

        vm.prank(dao.addr);
        feeRegistry.updateDefaultRate(50);

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
            managementRate: 200,
            performanceRate: 2000,
            rateUpdateCooldown: rateUpdateCooldown,
            enableWhitelist: enableWhitelist
        });

        Options memory opts;
        opts.constructorData = abi.encode(true);
        beacon = _beaconDeploy("v0.5.0/Vault.sol:Vault", owner.addr, opts);
        address vault = _proxyDeploy(beacon, v);

        opts.constructorData = abi.encode(false);
        vm.startPrank(owner.addr);
        Upgrades.upgradeBeacon(address(beacon), "v0.6.0/Vault.sol:Vault", opts);
        assertEq(keccak256(abi.encode(IVersion(vault).version())), keccak256(abi.encode("v0.6.0")));
        vm.stopPrank();
    }

    function _beaconDeploy(
        string memory contractName,
        address _owner,
        Options memory opts
    ) internal returns (UpgradeableBeacon) {
        return UpgradeableBeacon(Upgrades.deployBeacon(contractName, _owner, opts));
    }

    function _proxyDeploy(UpgradeableBeacon beacon, InitStruct memory v) internal returns (address) {
        BeaconProxy _proxy = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(Vault.initialize, (abi.encode(v), address(feeRegistry), WRAPPED_NATIVE_TOKEN))
                )
            )
        );

        return address(_proxy);
    }
}
