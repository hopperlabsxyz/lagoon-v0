// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {Vault} from "../src/v0.5.0/Vault.sol";
import {
    BeaconProxyFactory,
    InitStruct
} from "../src/protocol-v1/BeaconProxyFactory.sol";
import {FeeRegistry} from "../src/protocol-v1/FeeRegistry.sol";

/**
 * @title Deploy BUNN Vault 2 (USDT) to Base Sepolia Testnet
 * @notice Deploys a complete Lagoon v0.5.0 vault setup for USDT
 * @dev Deployment sequence:
 *      1. Deploy FeeRegistry
 *      2. Deploy Vault Implementation (v0.5.0)
 *      3. Deploy BeaconProxyFactory
 *      4. Create BUNN Vault 2 Proxy (USDT)
 */
contract DeployVault2_USDT is Script {
    // ==================== BASE SEPOLIA CONSTANTS ====================

    // Base Sepolia MockUSDT (Our deployed token)
    address constant USDT = 0x05A97D6b84cFEa96e27912e2350650D204E93D5C;

    // Base Sepolia WETH (or native ETH wrapper if exists)
    address constant WETH = address(0); // Update if WETH exists on Base Sepolia

    // ==================== VAULT 2 PARAMETERS ====================

    // Admin address (controls all roles initially)
    address constant ADMIN = 0xe5BefEB20b7Cd906a833B2265DCf22f495E29214;

    // Vault token details
    string constant VAULT_NAME = "BUNN-USDT";
    string constant VAULT_SYMBOL = "vsUSDT";

    // Fee parameters (0% for both)
    uint16 constant MANAGEMENT_RATE = 0; // 0 bps = 0%
    uint16 constant PERFORMANCE_RATE = 0; // 0 bps = 0%
    uint256 constant RATE_UPDATE_COOLDOWN = 1 days;

    // Whitelist disabled (anyone can deposit)
    bool constant ENABLE_WHITELIST = false;

    // ==================== PROTOCOL PARAMETERS ====================

    // Protocol fee receiver
    address constant PROTOCOL_FEE_RECEIVER = ADMIN;

    // Default protocol rates (can be 0 for testing)
    uint16 constant PROTOCOL_MANAGEMENT_RATE = 0;
    uint16 constant PROTOCOL_PERFORMANCE_RATE = 0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("================================================");
        console.log("DEPLOYING VAULT 2 (USDT) TO BASE SEPOLIA TESTNET");
        console.log("================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("USDT:", USDT);
        console.log("Admin:", ADMIN);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // ==================== STEP 1: DEPLOY FEE REGISTRY ====================
        console.log("Step 1: Deploying FeeRegistry...");

        FeeRegistry feeRegistry = new FeeRegistry(false);
        feeRegistry.initialize(deployer, PROTOCOL_FEE_RECEIVER);

        console.log("FeeRegistry deployed:", address(feeRegistry));
        console.log("");

        // ==================== STEP 2: DEPLOY VAULT IMPLEMENTATION ====================
        console.log("Step 2: Deploying Vault Implementation (v0.5.0)...");

        Vault vaultImplementation = new Vault(false);

        console.log("Vault Implementation:", address(vaultImplementation));
        console.log("");

        // ==================== STEP 3: DEPLOY BEACON PROXY FACTORY ====================
        console.log("Step 3: Deploying BeaconProxyFactory...");

        address wrappedNativeToken = WETH != address(0) ? WETH : address(0);

        BeaconProxyFactory factory = new BeaconProxyFactory(
            address(feeRegistry),
            address(vaultImplementation),
            deployer, // beacon owner (can upgrade implementation)
            wrappedNativeToken
        );

        console.log("BeaconProxyFactory:", address(factory));
        console.log("Beacon (Factory itself):", address(factory));
        console.log("");

        // ==================== STEP 4: CREATE VAULT 2 PROXY ====================
        console.log("Step 4: Creating BUNN Vault 2 Proxy (USDT)...");

        // Prepare initialization struct
        InitStruct memory initStruct = InitStruct({
            underlying: USDT, // Use USDT address
            name: VAULT_NAME,
            symbol: VAULT_SYMBOL,
            safe: ADMIN, // Gnosis Safe (or admin for testing)
            whitelistManager: ADMIN,
            valuationManager: ADMIN,
            admin: ADMIN,
            feeReceiver: ADMIN,
            managementRate: MANAGEMENT_RATE,
            performanceRate: PERFORMANCE_RATE,
            enableWhitelist: ENABLE_WHITELIST,
            rateUpdateCooldown: RATE_UPDATE_COOLDOWN
        });

        // Create vault proxy with salt for deterministic address
        bytes32 salt = keccak256("BUNN_VAULT_V2_MOCKUSDT_V2");

        address vaultProxy = factory.createVaultProxy(initStruct, salt);

        console.log("BUNN Vault 2 Proxy:", vaultProxy);
        console.log("");

        vm.stopBroadcast();

        // ==================== DEPLOYMENT SUMMARY ====================
        console.log("================================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("================================================");
        console.log("");
        console.log("CONTRACT ADDRESSES:");
        console.log("-------------------");
        console.log("FeeRegistry:      ", address(feeRegistry));
        console.log("Implementation:   ", address(vaultImplementation));
        console.log("Factory/Beacon:   ", address(factory));
        console.log("BUNN Vault 2:     ", vaultProxy);
        console.log("");
        console.log("VAULT CONFIGURATION:");
        console.log("--------------------");
        console.log("Name:", VAULT_NAME);
        console.log("Symbol:", VAULT_SYMBOL);
        console.log("Underlying:", USDT);
        console.log("Admin:", ADMIN);
        console.log("Management Fee: 0%");
        console.log("Performance Fee: 0%");
        console.log("Whitelist: Disabled");
        console.log("");
        console.log("BOTH VAULTS NOW DEPLOYED:");
        console.log("-------------------------");
        console.log(
            "Vault 1 (USDC): 0xDce2a7AE1AB9F7c0D14F7c3816a47975323F202d"
        );
        console.log("Vault 2 (USDT):", vaultProxy);
        console.log("");
        console.log("NEXT STEPS:");
        console.log("-----------");
        console.log(
            "1. Build swap/migration contract to move funds from Vault 1 -> Vault 2"
        );
        console.log("2. Test deposit flow with small USDT amount");
        console.log("3. See DEPLOY_BUNN_SEPOLIA.md for verification");
        console.log("================================================");
    }
}
