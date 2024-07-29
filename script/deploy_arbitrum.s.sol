// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DefenderOptions} from "openzeppelin-foundry-upgrades/Options.sol";
// struct Options {
//     string referenceContract;
//     bytes constructorData;
//     string unsafeAllow;
//     bool unsafeAllowRenames;
//     bool unsafeSkipStorageCheck;
//     bool unsafeSkipAllChecks;
//     DefenderOptions defender;
// }
struct InitStruct {
    IERC20 underlying;
    string name;
    string symbol;
    address dao;
    address assetManager;
    address valorization;
    address admin;
    address feeReceiver;
    uint256 managementFee;
    uint256 performanceFee;
    uint256 protocolFee;
    uint256 cooldown;
    bool enableWhitelist;
    address[] whitelist;
}

contract Test {}

contract Deploy is Script {
    IERC20 arbitrum_usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    string name = "MVP_HOPPER_USDC";
    string symbol = "MVP_USDC";
    address dao = 0xd4E674882bC827b6995D717C5e79a58E27BBf700; // dao
    address safe = 0xEffD8b7C73aB0Fbe0EF300D6f8b676e7923500f4; // safe
    address valorization = safe;
    address proxyAdmin = 0x54b750adb6758CC0569F3C32C3B6ce0f2F7be689; // proxy admin
    address user = 0xeee5d7D6734037f38b115c7A2315A0C8206672C2; // mvp user
    address[] whitelist = [user];

    address admin = dao; // admin
    address feeReceiver = 0x30860aef227B865472d9951A1b3AFB279b417150; // Remi EOA
    uint256 managementFee = 200; // 2%
    uint256 performanceFee = 2000; // 20%
    uint256 protocolFee = 100; // 1%
    uint256 cooldown = 1 hours;
    bool enableWhitelist = true;

    function run() external {
        vm.startBroadcast();

        Vault.InitStruct memory v = Vault.InitStruct(
            arbitrum_usdc,
            name,
            symbol,
            dao,
            safe,
            valorization,
            admin,
            feeReceiver,
            managementFee,
            performanceFee,
            protocolFee,
            cooldown,
            enableWhitelist,
            whitelist
        );

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(
                Upgrades.deployTransparentProxy(
                    "Vault.sol:Vault",
                    proxyAdmin,
                    abi.encodeCall(Vault.initialize, v)
                )
            )
        );

        console.log("Vault USDC proxy address: ", address(proxy));

        vm.stopBroadcast();

        // Mainnet
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id 1 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
        // Sepolia
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id 534351 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL_SEPOLIA} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
    }
}
