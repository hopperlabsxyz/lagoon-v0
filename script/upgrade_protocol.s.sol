// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
    ITransparentUpgradeableProxy,
    ProxyAdmin
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";
import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {BatchScript} from "./BatchScript.sol";
import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
/*
  run `make protocol` to deploy this script
*/

contract UpgradeProtocolRegistry is BatchScript {
    function upgradeProtocolRegistry(
        bool send,
        address _proxy,
        address FEE_REGISTRY_ADMIN
    ) internal returns (address) {
        console.log("--- deployProtocolRegistry() ---");

        Options memory opts;
        opts.constructorData = abi.encode(true);

        address impl = address(new ProtocolRegistry(true));

        // ProxyAdmin(FEE_REGISTRY_ADMIN).upgradeAndCall(ITransparentUpgradeableProxy(_proxy), impl, "");
        bytes memory txn =
            abi.encodeWithSelector(ProxyAdmin.upgradeAndCall.selector, ITransparentUpgradeableProxy(_proxy), impl, "");
        addToBatch(FEE_REGISTRY_ADMIN, 0, txn);
        executeBatch(send);
        return address(impl);
    }

    function run() external virtual {
        address REGISTRY = vm.envAddress("FEE_REGISTRY");
        address FEE_REGISTRY_ADMIN = vm.envAddress("FEE_REGISTRY_ADMIN");
        bool send = vm.envBool("BROADCAST");
        // vm.isBroadcastable
        vm.startBroadcast();
        upgradeProtocolRegistry(false, REGISTRY, FEE_REGISTRY_ADMIN);
        vm.stopBroadcast();
    }
}
