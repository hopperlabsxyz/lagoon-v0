// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make protocol` to deploy this script
*/

contract DeployProtocol is Script {
    function run() external virtual {
        address DAO = vm.envAddress("DAO");

        vm.startBroadcast();
        deployProtocolRegistry(DAO, DAO, DAO);
        vm.stopBroadcast();
    }

    function deployProtocolRegistry(
        address _dao,
        address _protocolFeeReceiver,
        address _proxyAdmin
    ) internal returns (address) {
        console.log("--- deployProtocolRegistry() ---");

        Options memory opts;
        opts.constructorData = abi.encode(true);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(
                Upgrades.deployTransparentProxy(
                    "ProtocolRegistry.sol:ProtocolRegistry",
                    _proxyAdmin,
                    abi.encodeWithSelector(ProtocolRegistry.initialize.selector, _dao, _protocolFeeReceiver),
                    opts
                )
            )
        );
        console.log("ProtocolRegistry proxy address: ", address(proxy));

        return address(proxy);
    }
}
