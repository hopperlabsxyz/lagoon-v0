// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OptinProxy} from "@src/proxy/OptinProxy.sol";

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make protocol` to deploy this script
*/

contract MockLogicRegistry {
    function canUseLogic(
        address,
        address
    ) public pure returns (bool) {
        return true;
    }
}

contract DeployOptinProxyForVerification is Script {
    function run() external virtual {
        vm.startBroadcast();
        deployEmptyOptinProxyForVerification();
        vm.stopBroadcast();
    }

    function deployEmptyOptinProxyForVerification() internal returns (address) {
        console.log("--- deployOptinProxy() ---");

        MockLogicRegistry mockLogicRegistry = new MockLogicRegistry();
        OptinProxy optinProxy = new OptinProxy({
            _logic: address(mockLogicRegistry), // we do not care about the logic used here
            _logicRegistry: address(mockLogicRegistry),
            _initialOwner: address(mockLogicRegistry), // can't be zero
            _initialDelay: 2 days, // must be > 1 days as defined in DelayProxyAdmin
            _data: ""
        });
        console.log("OptinProxy address: ", address(optinProxy));

        return address(optinProxy);
    }
}
