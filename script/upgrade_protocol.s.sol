// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
    ITransparentUpgradeableProxy,
    ProxyAdmin
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {OptinProxyFactory} from "@src/protocol-v2/OptinProxyFactory.sol";
import {LogicRegistry, ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {BatchScript} from "./BatchScript.sol";
import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
/*
  run `make protocol` to deploy this script
*/

contract UpgradeProtocolRegistry is BatchScript {
    address REGISTRY = vm.envAddress("FEE_REGISTRY");
    address FEE_REGISTRY_ADMIN = vm.envAddress("FEE_REGISTRY_ADMIN");
    uint256 deploymentPk = vm.envUint("PK");
    address defaultLogic = vm.envAddress("DEFAULT_LOGIC");
    address DAO = vm.envAddress("DAO");
    address wrappedNativeToken = vm.envAddress("WRAPPED_NATIVE_TOKEN");

    function upgradeProtocolRegistry(address _proxy, address _FEE_REGISTRY_ADMIN, address _impl) internal {
        bytes memory txn =
            abi.encodeWithSelector(ProxyAdmin.upgradeAndCall.selector, ITransparentUpgradeableProxy(_proxy), _impl, "");
        addToBatch(_FEE_REGISTRY_ADMIN, 0, txn);
    }

    function addDefaultLogic(address logic, address registry) internal {
        bytes memory txn = abi.encodeWithSelector(LogicRegistry.updateDefaultLogic.selector, logic);
        addToBatch(registry, 0, txn);
    }

    function deployOptinFactory(address registry, address _wrappedNativeToken) public {
        Options memory opts;
        opts.constructorData = abi.encode(true);
        bytes memory init =
            abi.encodeWithSelector(OptinProxyFactory.initialize.selector, registry, _wrappedNativeToken, DAO);
        Upgrades.deployTransparentProxy("OptinProxyFactory.sol:OptinProxyFactory", DAO, init, opts);
    }

    function run() external virtual isBatch(vm.envAddress("SAFE_ADDRESS")) {
        // vm.isBroadcastable

        // vm.startBroadcast(deploymentPk);
        // address impl = address(new ProtocolRegistry(true));
        // vm.stopBroadcast();
        // upgradeProtocolRegistry(REGISTRY, FEE_REGISTRY_ADMIN, 0xd039Ee9e7d6B3cfEa29250A7D559A4dDB21B25E2);
        // addDefaultLogic(defaultLogic, REGISTRY);
        deployOptinFactory(REGISTRY, wrappedNativeToken);
        executeBatch(true);
    }
}
