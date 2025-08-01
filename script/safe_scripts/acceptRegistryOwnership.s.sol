// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BatchScript} from "../tools/BatchScript.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract AcceptRegistryOwnership is BatchScript {
    address registry;
    address defaultLogic;

    function run() external virtual isBatch(vm.envAddress("SAFE_ADDRESS")) {
        registry = vm.envAddress("REGISTRY");
        acceptOwnership(registry);
        executeBatch(true);
    }

    function acceptOwnership(
        address _registry
    ) internal {
        bytes memory txn = abi.encodeWithSelector(Ownable2StepUpgradeable.acceptOwnership.selector);
        addToBatch(_registry, 0, txn);
    }
}
