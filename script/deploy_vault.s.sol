// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {BeaconProxyFactory, InitStruct} from "@src/protocol-v1/BeaconProxyFactory.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script, console} from "forge-std/Script.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/*
  run `make vault` to deploy this script
*/

contract DeployVault is Script {
    function _loadInitStructFromEnv() internal view returns (InitStruct memory v) {
        // General
        address UNDERLYING = vm.envAddress("UNDERLYING");
        string memory NAME = vm.envString("NAME");
        string memory SYMBOL = vm.envString("SYMBOL");
        bool ENABLE_WHITELIST = vm.envBool("ENABLE_WHITELIST");

        // Fees
        uint16 MANAGEMENT_RATE = uint16(vm.envUint("MANAGEMENT_RATE"));
        uint16 PERFORMANCE_RATE = uint16(vm.envUint("PERFORMANCE_RATE"));
        uint256 RATE_UPDATE_COOLDOWN = vm.envUint("RATE_UPDATE_COOLDOWN");

        // Roles
        address SAFE = vm.envAddress("SAFE");
        address FEE_RECEIVER = vm.envAddress("FEE_RECEIVER");
        address ADMIN = vm.envAddress("ADMIN");
        address WHITELIST_MANAGER = vm.envAddress("WHITELIST_MANAGER");
        address VALUATION_MANAGER = vm.envAddress("VALUATION_MANAGER");
        v = InitStruct({
            underlying: UNDERLYING,
            name: NAME,
            symbol: SYMBOL,
            safe: SAFE,
            whitelistManager: WHITELIST_MANAGER,
            valuationManager: VALUATION_MANAGER,
            admin: ADMIN,
            feeReceiver: FEE_RECEIVER,
            managementRate: MANAGEMENT_RATE,
            performanceRate: PERFORMANCE_RATE,
            enableWhitelist: ENABLE_WHITELIST,
            deprecatedRateUpdateCooldown: 0
        });
    }

    function run() external virtual {
        InitStruct memory init = _loadInitStructFromEnv();
        BeaconProxyFactory beacon = BeaconProxyFactory(vm.envAddress("BEACON"));

        console.log("--- deployVault() ---");

        console.log("Beacon:              ", address(beacon));
        console.log("Underlying:          ", address(init.underlying));
        console.log("Name:                ", init.name);
        console.log("Symbol:              ", init.symbol);
        console.log("Enable_whitelist:    ", init.enableWhitelist);
        console.log("Management_rate:     ", init.managementRate);
        console.log("Performance_rate:    ", init.performanceRate);
        console.log("Deprecated_cooldown: ", init.deprecatedRateUpdateCooldown);
        console.log("Safe:                ", init.safe);
        console.log("Fee_receiver:        ", init.feeReceiver);
        console.log("Admin:               ", init.admin);
        console.log("Whitelist_manager:   ", init.whitelistManager);
        console.log("Valuation_manager:   ", init.valuationManager);

        console.log(block.timestamp);
        bytes32 salt = keccak256(abi.encode(init.symbol, block.timestamp));
        console.log("Salt:   ");
        console.logBytes32(salt);

        vm.startBroadcast();
        address proxy = beacon.createBeaconProxy(abi.encode(init), salt);
        vm.stopBroadcast();

        console.log("Vault proxy address: ", proxy);
    }
}
