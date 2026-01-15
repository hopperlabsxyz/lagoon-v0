// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {Vault} from "../src/v0.5.0/Vault.sol";
import {BeaconProxyFactory, InitStruct} from "../src/protocol-v1/BeaconProxyFactory.sol";
import {FeeRegistry} from "../src/protocol-v1/FeeRegistry.sol";

/**
 * @title Deploy BUNN Vault 1 (USDC) to Base Sepolia Testnet
 * @notice Deploys a complete Lagoon v0.5.0 vault setup for BUNN protocol - USDC vault
 * @dev Deployment sequence:
 *      1. Deploy FeeRegistry
 *      2. Deploy Vault Implementation (v0.5.0)
 *      3. Deploy BeaconProxyFactory
 *      4. Create BUNN Vault 1 Proxy (vsUSDC)
 */
contract DeployVault1_USDC is Script {
    // ==================== BASE SEPOLIA CONSTANTS ====================

    // Base Sepolia USDC (Circle testnet USDC)
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    // Base Sepolia WETH (or native ETH wrapper if exists)
    // Note: If no WETH on Base Sepolia, use zero address or deploy minimal WETH
    address constant WETH = address(0); // Update if WETH exists on Base Sepolia

    // ==================== BUNN VAULT PARAMETERS ====================

    // Admin address (controls all roles initially)
    address constant ADMIN = 0xe5BefEB20b7Cd906a833B2265DCf22f495E29214;

    // Vault token details
    string constant VAULT_NAME = "Vault Shares USDC";
    string constant VAULT_SYMBOL = "vsUSDC";

    // Fee parameters (0% for both)
    uint16 constant MANAGEMENT_RATE = 0;  // 0 bps = 0%
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
        console.log("DEPLOYING BUNN VAULT TO BASE SEPOLIA TESTNET");
        console.log("================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("USDC:", USDC);
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

        // ==================== STEP 4: CREATE BUNN VAULT PROXY ====================
        console.log("Step 4: Creating BUNN Vault Proxy...");

        // Prepare initialization struct
        InitStruct memory initStruct = InitStruct({
            underlying: USDC,  // Use address directly, not IERC20
            name: VAULT_NAME,
            symbol: VAULT_SYMBOL,
            safe: ADMIN,                    // Gnosis Safe (or admin for testing)
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
        bytes32 salt = keccak256("BUNN_VAULT_V1");

        address vaultProxy = factory.createVaultProxy(
            initStruct,
            salt
        );

        console.log("BUNN Vault Proxy:", vaultProxy);
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
        console.log("BUNN Vault:       ", vaultProxy);
        console.log("");
        console.log("VAULT CONFIGURATION:");
        console.log("--------------------");
        console.log("Name:", VAULT_NAME);
        console.log("Symbol:", VAULT_SYMBOL);
        console.log("Underlying:", USDC);
        console.log("Admin:", ADMIN);
        console.log("Management Fee: 0%");
        console.log("Performance Fee: 0%");
        console.log("Whitelist: Disabled");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("-----------");
        console.log("1. Update BUNN Fee Splitter with vault address:");
        console.log("   ", vaultProxy);
        console.log("2. Test deposit flow with small USDC amount");
        console.log("3. See DEPLOY_BUNN_SEPOLIA.md for verification");
        console.log("================================================");
    }
}
