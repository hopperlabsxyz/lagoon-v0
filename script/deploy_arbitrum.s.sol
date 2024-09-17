// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {FeeRegistry} from "@src/FeeRegistry.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DefenderOptions} from "openzeppelin-foundry-upgrades/Options.sol";

contract Deploy is Script {
    address USDC_ARBITRUM = vm.envAddress("USDC_ARBITRUM");
    address WETH_ARBITRUM = vm.envAddress("WETH_ARBITRUM");

    address DAO = vm.envAddress("DAO");
    address SAFE = vm.envAddress("SAFE");
    address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");
    address FEE_RECEIVER = vm.envAddress("FEE_RECEIVER");

    string VAULT_NAME = vm.envString("VAULT_NAME");
    string VAULT_SYMBOL = vm.envString("VAULT_SYMBOL");

    IERC20 underlying = IERC20(USDC_ARBITRUM);

    address valorization = SAFE;
    address[] whitelist = new address[](0);

    address admin = DAO;
    address whitelistManager = DAO;
    address valorizator = SAFE;
    uint256 _managementRate = 0;
    uint256 _performanceRate = 2_000;
    uint256 protocolFee = 100;
    bool enableWhitelist = true;

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
            valorization: valorizator,
            admin: admin,
            feeReceiver: FEE_RECEIVER,
            feeRegistry: address(feeRegistry),
            managementRate: _managementRate,
            performanceRate: _performanceRate,
            wrappedNativeToken: WETH_ARBITRUM,
            enableWhitelist: enableWhitelist,
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

        // Mainnet
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id 1 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
        // Sepolia
        // source .env && forge clean && forge script script/mainnet_deploy.s.sol:MAINNET_DeployAmphor --ffi --chain-id 534351 --optimizer-runs 10000 --verifier-url ${VERIFIER_URL_SEPOLIA} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify #--broadcast
    }
}
