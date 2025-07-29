// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
    ITransparentUpgradeableProxy,
    ProxyAdmin
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {BeaconProxyFactory} from "@src/protocol-v1/BeaconProxyFactory.sol";
import {OptinProxyFactory} from "@src/protocol-v2/OptinProxyFactory.sol";
import {LogicRegistry, ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Vault} from "../src/v0.5.0/Vault.sol";
import {UpdateDaoSigners} from "./safe_scripts/upgrade_daoSigners.s.sol";
import {BatchScript} from "./tools/BatchScript.sol";
import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
/*
 This script will deploy the OptinProxyFactory, propose safe txs to:
 - update the fee registry with the logicRegistry 
 - update the default implementation in the logic registry
 - upgrade the set of signers of the DAO multisig
*/

interface Safe {
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
}

contract UpgradeProtocolRegistry is UpdateDaoSigners {
    address registry;
    address FEE_REGISTRY_ADMIN = vm.envAddress("FEE_REGISTRY_ADMIN");
    uint256 deploymentPk = vm.envUint("PK");
    address defaultLogic;
    address wrappedNativeToken;
    BeaconProxyFactory beaconFactory = BeaconProxyFactory(vm.envAddress("BEACON_FACTORY"));

    function run() external virtual override isBatch(vm.envAddress("SAFE_ADDRESS")) {
        // vm.isBroadcastable
        registry = beaconFactory.REGISTRY();
        wrappedNativeToken = beaconFactory.WRAPPED_NATIVE();
        defaultLogic = beaconFactory.implementation();

        vm.startBroadcast(deploymentPk);
        // address impl = address(new ProtocolRegistry(true));
        deployOptinFactory(registry, wrappedNativeToken);
        vm.stopBroadcast();
    }

    function upgradeProtocolRegistry(address _registry, address _FEE_REGISTRY_ADMIN, address _impl) internal {
        bytes memory txn = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector, ITransparentUpgradeableProxy(_registry), _impl, ""
        );
        addToBatch(_FEE_REGISTRY_ADMIN, 0, txn);
    }

    function addDefaultLogic(address logic, address _registry) internal {
        bytes memory txn = abi.encodeWithSelector(LogicRegistry.updateDefaultLogic.selector, logic);
        addToBatch(_registry, 0, txn);
    }

    function deployOptinFactory(address _registry, address _wrappedNativeToken) public {
        Options memory opts;
        opts.constructorData = abi.encode(true);
        bytes memory init =
            abi.encodeWithSelector(OptinProxyFactory.initialize.selector, _registry, _wrappedNativeToken, DAO);
        Upgrades.deployTransparentProxy("OptinProxyFactory.sol:OptinProxyFactory", DAO, init, opts);
    }
}
