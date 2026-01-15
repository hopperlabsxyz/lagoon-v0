// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {VaultMigration} from "../src/VaultMigration.sol";

/**
 * @title Deploy Migration Contract
 * @notice Deploys VaultMigration contract for migrating from Vault 1 (USDC) to Vault 2 (USDT)
 */
contract DeployMigration is Script {
    // Base Sepolia addresses
    address constant VAULT1 = 0xDce2a7AE1AB9F7c0D14F7c3816a47975323F202d; // USDC vault
    address constant VAULT2 = 0xE5b84b78bf434c1D85b3f685C0889eEa84a2617c; // USDT vault
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant USDT = 0x4DBD49a3aE90Aa5F13091ccD29A896cbb5B171EB;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("================================================");
        console.log("DEPLOYING MIGRATION CONTRACT");
        console.log("================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");
        console.log("Vault 1 (USDC):", VAULT1);
        console.log("Vault 2 (USDT):", VAULT2);
        console.log("USDC:", USDC);
        console.log("USDT:", USDT);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        VaultMigration migration = new VaultMigration(
            VAULT1,
            VAULT2,
            USDC,
            USDT
        );

        console.log("Migration Contract deployed:", address(migration));
        console.log("");

        vm.stopBroadcast();

        // ==================== DEPLOYMENT SUMMARY ====================
        console.log("================================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("================================================");
        console.log("");
        console.log("CONTRACT ADDRESS:");
        console.log("-----------------");
        console.log("VaultMigration:", address(migration));
        console.log("");
        console.log("CONNECTED TO:");
        console.log("-------------");
        console.log("Vault 1 (USDC):", VAULT1);
        console.log("Vault 2 (USDT):", VAULT2);
        console.log("");
        console.log("MIGRATION WORKFLOW:");
        console.log("-------------------");
        console.log("1. Register users:");
        console.log("   migration.registerUser(userAddress)");
        console.log("   or migration.registerUsers([addr1, addr2, ...])");
        console.log("");
        console.log("2. Deposit USDT liquidity:");
        console.log("   usdt.approve(migrationAddress, amount)");
        console.log("   migration.depositUSDT(amount)");
        console.log("");
        console.log("3. Check liquidity:");
        console.log("   migration.checkUSDTLiquidity()");
        console.log("");
        console.log("4. Start migration:");
        console.log("   migration.startMigration()");
        console.log("");
        console.log("5. Execute migration:");
        console.log("   migration.migrateBatch(100)");
        console.log("   or migration.migrateUser(userAddress)");
        console.log("");
        console.log("6. Complete migration:");
        console.log("   migration.completeMigration()");
        console.log("");
        console.log("Explorer: https://sepolia.basescan.org/address/", address(migration));
        console.log("================================================");
    }
}
