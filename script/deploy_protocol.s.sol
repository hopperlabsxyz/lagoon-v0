// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Vault0_2_1} from "@src/vault0.2.1/Vault0.2.1.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make protocol` to deploy this script
*/

contract DeployProtocol is Script {
    function deployFeeRegistry(
        address _dao,
        address _protocolFeeReceiver,
        address _proxyAdmin
    ) internal returns (address) {
        console.log("--- deployFeeRegistry() ---");

        Options memory opts;
        opts.constructorData = abi.encode(true);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(
                Upgrades.deployTransparentProxy(
                    "FeeRegistry.sol:FeeRegistry",
                    _proxyAdmin,
                    abi.encodeWithSelector(FeeRegistry.initialize.selector, _dao, _protocolFeeReceiver),
                    opts
                )
            )
        );
        console.log("FeeRegistry proxy address: ", address(proxy));

        return address(proxy);
    }

    function run() external virtual {
        address DAO = vm.envAddress("DAO");
        address PROTOCOL_FEE_RECEIVER = vm.envAddress("PROTOCOL_FEE_RECEIVER");
        address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");

        vm.startBroadcast();
        deployFeeRegistry(DAO, PROTOCOL_FEE_RECEIVER, PROXY_ADMIN);
        vm.stopBroadcast();
    }
}
