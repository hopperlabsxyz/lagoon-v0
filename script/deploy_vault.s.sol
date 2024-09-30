// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Vault} from "../src/vault/Vault.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*

> How to deploy this script:

source .env && \
forge clean && \
forge script script/deploy_vault.s.sol \
  --chain-id $CHAIN_ID \
  --rpc-url $RPC_URL \
  --tc DeployVault \
  --account defaultKey \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify

*/

contract DeployVault is Script {
    address UNDERLYING = vm.envAddress("UNDERLYING");
    address WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");

    address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");

    address DAO = vm.envAddress("DAO");
    address SAFE = vm.envAddress("SAFE");
    address FEE_RECEIVER = vm.envAddress("FEE_RECEIVER");
    address FEE_REGISTRY = vm.envAddress("FEE_REGISTRY");

    string VAULT_NAME = vm.envString("VAULT_NAME");
    string VAULT_SYMBOL = vm.envString("VAULT_SYMBOL");

    function run() external {
        vm.startBroadcast();

        Vault.InitStruct memory v = Vault.InitStruct({
            underlying: IERC20(UNDERLYING),
            name: VAULT_NAME,
            symbol: VAULT_SYMBOL,
            safe: SAFE,
            whitelistManager: DAO,
            navManager: DAO,
            admin: DAO,
            feeReceiver: FEE_RECEIVER,
            feeRegistry: FEE_REGISTRY,
            managementRate: 0,
            performanceRate: 2000,
            wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
            enableWhitelist: true,
            rateUpdateCooldown: 1 days
        });

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(
                Upgrades.deployTransparentProxy(
                    "Vault.sol:Vault", PROXY_ADMIN, abi.encodeWithSelector(Vault.initialize.selector, v)
                )
            )
        );

        // todo
        // whitelist the following addresses:
        // - feeReceiver
        // - protocolFeeReceiver
        // - safe
        // - pendingSilo

        console.log("Vault proxy address: ", address(proxy));

        vm.stopBroadcast();
    }
}
