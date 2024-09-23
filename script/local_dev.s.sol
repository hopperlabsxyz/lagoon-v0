// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "../src/vault/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DefenderOptions} from "openzeppelin-foundry-upgrades/Options.sol";

contract LocalDeploy is Script {
    // Env variable loading
    address USDC_MAINNET = vm.envAddress("USDC_MAINNET");

    address DAO = vm.envAddress("DAO");
    address SAFE = vm.envAddress("SAFE");
    address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");
    address FEE_RECEIVER = vm.envAddress("FEE_RECEIVER");
    address USER0 = vm.envAddress("USER0");
    address USER1 = vm.envAddress("USER1");
    address USER2 = vm.envAddress("USER2");
    address USER3 = vm.envAddress("USER3");

    string VAULT_NAME = vm.envString("VAULT_NAME");
    string VAULT_SYMBOL = vm.envString("VAULT_SYMBOL");

    IERC20 underlying = IERC20(USDC_MAINNET);

    address[] whitelist = [USER0, USER1, USER2, USER3];

    address admin = DAO;
    address whitelistManager = DAO;
    address navManager = DAO;
    uint16 _managementRate = 0;
    uint16 _performanceRate = 0;
    bool enableWhitelist = true;

    string network = vm.envString("NETWORK");

    address immutable WRAPPED_NATIVE_TOKEN =
        vm.envAddress(string.concat("WRAPPED_NATIVE_TOKEN_", network));

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        FeeRegistry feeRegistry = new FeeRegistry();
        feeRegistry.initialize(DAO, DAO);

        Vault.InitStruct memory v = Vault.InitStruct({
            underlying: underlying,
            name: VAULT_NAME,
            symbol: VAULT_SYMBOL,
            safe: SAFE,
            whitelistManager: whitelistManager,
            navManager: navManager,
            admin: admin,
            feeReceiver: FEE_RECEIVER,
            feeRegistry: address(feeRegistry),
            managementRate: _managementRate,
            performanceRate: _performanceRate,
            wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
            enableWhitelist: enableWhitelist,
            rateUpdateCooldown: 1 days,
            whitelist: whitelist
        });

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(
                Upgrades.deployTransparentProxy(
                    "Vault.sol:Vault",
                    PROXY_ADMIN,
                    abi.encodeCall(Vault.initialize, v)
                )
            )
        );

        console.log("Vault USDC proxy address: ", address(proxy));

        vm.stopBroadcast();
    }
}
