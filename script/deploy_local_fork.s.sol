// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InitStruct, Vault0_2_1} from "@src/vault0.2.1/Vault0.2.1.sol";

import {DeployBeacon} from "./deploy_beacon.s.sol";
import {DeployProtocol} from "./deploy_protocol.s.sol";
import {DeployVault} from "./deploy_vault.s.sol";
import {Script, console} from "forge-std/Script.sol";

/*
  run `make protocol` to deploy this script
*/

contract DeployFull is DeployProtocol, DeployBeacon, DeployVault {
    // fee registry
    address DAO = vm.envAddress("DAO");
    address PROTOCOL_FEE_RECEIVER = vm.envAddress("PROTOCOL_FEE_RECEIVER");
    address PROXY_ADMIN = vm.envAddress("PROXY_ADMIN");

    // vault beacon
    address BEACON_OWNER = vm.envAddress("BEACON_OWNER");

    // vault proxy
    address UNDERLYING = vm.envAddress("UNDERLYING");
    address WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");
    string NAME = vm.envString("NAME");
    string SYMBOL = vm.envString("SYMBOL");
    bool ENABLE_WHITELIST = vm.envBool("ENABLE_WHITELIST");

    uint16 MANAGEMENT_RATE = uint16(vm.envUint("MANAGEMENT_RATE"));
    uint16 PERFORMANCE_RATE = uint16(vm.envUint("PERFORMANCE_RATE"));
    uint256 RATE_UPDATE_COOLDOWN = vm.envUint("RATE_UPDATE_COOLDOWN");

    address SAFE = vm.envAddress("SAFE");
    address FEE_RECEIVER = vm.envAddress("FEE_RECEIVER");
    address ADMIN = vm.envAddress("ADMIN");
    address WHITELIST_MANAGER = vm.envAddress("WHITELIST_MANAGER");
    address VALUATION_MANAGER = vm.envAddress("VALUATION_MANAGER");

    function run() external override(DeployProtocol, DeployBeacon, DeployVault) {
        vm.startBroadcast();
        address feeRegistry = deployFeeRegistry(DAO, PROTOCOL_FEE_RECEIVER, PROXY_ADMIN);
        address beacon = deployBeacon(BEACON_OWNER);
        InitStruct memory v = InitStruct({
            underlying: IERC20(UNDERLYING),
            name: NAME,
            symbol: SYMBOL,
            safe: SAFE,
            whitelistManager: WHITELIST_MANAGER,
            valuationManager: VALUATION_MANAGER,
            admin: ADMIN,
            feeReceiver: FEE_RECEIVER,
            feeRegistry: feeRegistry,
            managementRate: MANAGEMENT_RATE,
            performanceRate: PERFORMANCE_RATE,
            wrappedNativeToken: WRAPPED_NATIVE_TOKEN,
            enableWhitelist: ENABLE_WHITELIST,
            rateUpdateCooldown: RATE_UPDATE_COOLDOWN
        });
        deployVault(v, beacon);

        vm.stopBroadcast();
    }
}
