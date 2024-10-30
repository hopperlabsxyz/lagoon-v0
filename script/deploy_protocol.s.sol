// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Vault} from "../src/vault/Vault.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*

> How to deploy this script:

source .env && \
forge clean && \
forge script script/deploy_protocol.s.sol \
  --chain-id $CHAIN_ID \
  --rpc-url $RPC_URL \
  --tc DeployProtocol \
  --account defaultKey \
  --etherscan-api-key $ETHERSCAN_API_KEY

*/

contract DeployProtocol is Script {
    address DAO = vm.envAddress("DAO");
    address PROTOCOL_FEE_RECEIVER = vm.envAddress("PROTOCOL_FEE_RECEIVER");
    address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");

    function run() external {
        vm.startBroadcast();

        Options memory opts;
        opts.constructorData = abi.encode(true);

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(
                Upgrades.deployTransparentProxy(
                    "FeeRegistry.sol:FeeRegistry",
                    PROXY_ADMIN,
                    abi.encodeWithSelector(FeeRegistry.initialize.selector, DAO, PROTOCOL_FEE_RECEIVER),
                    opts
                )
            )
        );
        console.log("FeeRegistry proxy address: ", address(proxy));
        vm.stopBroadcast();
    }
}
