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

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployOptinProxyFactory is Script {
    address registry;
    uint256 deploymentPk;
    address wrappedNativeToken;
    address DAO;

    function run() external virtual {
        registry = vm.envAddress("REGISTRY");
        wrappedNativeToken = vm.envAddress("WRAPPED_NATIVE");
        DAO = vm.envAddress("DAO");

        deploymentPk = vm.envUint("PK");

        vm.startBroadcast(deploymentPk);
        deployOptinFactory(registry, wrappedNativeToken, DAO);
        vm.stopBroadcast();
    }

    function deployOptinFactory(address _registry, address _wrappedNativeToken, address _DAO) public {
        Options memory opts;
        opts.constructorData = abi.encode(true);
        bytes memory init =
            abi.encodeWithSelector(OptinProxyFactory.initialize.selector, _registry, _wrappedNativeToken, _DAO);
        Upgrades.deployTransparentProxy("OptinProxyFactory.sol:OptinProxyFactory", _DAO, init, opts);
    }
}
