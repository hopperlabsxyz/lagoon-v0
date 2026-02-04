// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {
    ITransparentUpgradeableProxy,
    ProxyAdmin
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {LogicRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";

// import {Vault} from "../src/v0.5.0/Vault.sol";

import {BatchScript} from "../tools/BatchScript.sol";

contract UpgradeProtocolRegistry is BatchScript {
    address registry;
    address defaultLogic;

    function run() external virtual isBatch(vm.envAddress("SAFE_ADDRESS")) {
        registry = vm.envAddress("REGISTRY");
        defaultLogic = vm.envAddress("DEFAULT_LOGIC");
        addDefaultLogic(defaultLogic, registry);
        executeBatch(true);
    }

    function addDefaultLogic(
        address logic,
        address _registry
    ) internal {
        bytes memory txn = abi.encodeWithSelector(LogicRegistry.updateDefaultLogic.selector, logic);
        addToBatch(_registry, 0, txn);
    }
}
