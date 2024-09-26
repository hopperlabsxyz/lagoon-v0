// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Vault} from "../src/vault/Vault.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*

> How to deploy this script:

source .env && \
forge clean && \
forge script script/deploy_protocol.s.sol \
  --chain-id $CHAIN_ID \
  --rpc-url $RPC_URL \
  --tc DeployProtocol \
  --account defaultKey \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify

*/

contract DeployProtocol is Script {
    address DAO = vm.envAddress("DAO");

    function run() external {
        address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");

        vm.startBroadcast();
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(
                Upgrades.deployTransparentProxy(
                    "FeeRegistry.sol:FeeRegistry",
                    PROXY_ADMIN,
                    abi.encodeWithSelector(
                        FeeRegistry.initialize.selector,
                        DAO,
                        DAO
                    )
                )
            )
        );
        console.log("FeeRegistry proxy address: ", address(proxy));
        vm.stopBroadcast();
    }
}
