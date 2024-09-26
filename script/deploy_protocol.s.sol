// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Vault} from "../src/vault/Vault.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";
import {Script, console} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract Deploy is Script {
    address DAO = vm.envAddress("DAO");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");

        vm.startBroadcast(deployerPrivateKey);

        FeeRegistry feeRegistry = new FeeRegistry();
        feeRegistry.initialize(DAO, DAO);

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

        // Mainnet
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id
        // 1 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify
        // #--broadcast
        // Sepolia
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id
        // 534351 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL_SEPOLIA} --etherscan-api-key ${ETHERSCAN_API_KEY}
        // --verify #--broadcast
    }
}
