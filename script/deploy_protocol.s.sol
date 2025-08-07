// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";

import {DeployOptinProxyFactory} from "./deploy_factory.s.sol";
import {DeployImplementation} from "./deploy_implementation.s.sol";
import {DeployRegistry} from "./deploy_registry.s.sol";
import {BatchScript} from "./tools/BatchScript.sol";

contract DeployProtocol is DeployImplementation, DeployRegistry, DeployOptinProxyFactory {
    string tag = vm.envString("VERSION_TAG");
    address DAO = vm.envAddress("DAO");
    address WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");

    function run() external virtual override(DeployImplementation, DeployRegistry, DeployOptinProxyFactory) {
        vm.startBroadcast();
        address implementation = deployImplementation(tag);
        // we deploy the registry but temporaly the owner is the deployment address.
        ProtocolRegistry registry =
            ProtocolRegistry(deployProtocolRegistry({_dao: msg.sender, _protocolFeeReceiver: DAO, _proxyAdmin: DAO}));

        // we update the default logic
        registry.updateDefaultLogic(implementation);

        // we give back ownership, it need to be verified.
        registry.transferOwnership(DAO);

        // we deploy the optin factory
        deployOptinFactory({_registry: address(registry), _wrappedNativeToken: WRAPPED_NATIVE_TOKEN, _DAO: DAO});
        vm.stopBroadcast();
    }
}
