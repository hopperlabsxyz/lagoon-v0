# BUNN Vault Migration Guide (Vault 1 → Vault 2)

## Overview
This guide explains how to migrate users from Vault 1 (USDC) to Vault 2 (USDT) using the VaultMigration contract.

## Deployed Contracts (Base Sepolia)

| Contract | Address | Description |
|----------|---------|-------------|
| **Vault 1 (USDC)** | `0xDce2a7AE1AB9F7c0D14F7c3816a47975323F202d` | Source vault (vsUSDC shares) |
| **Vault 2 (USDT)** | `0xE5b84b78bf434c1D85b3f685C0889eEa84a2617c` | Destination vault (vsUSDT shares) |
| **Migration Contract** | `0x197796d375FD4944fCf36113799EDbB3133BEfFF` | Handles user migration |
| **USDC** | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | Base Sepolia USDC |
| **USDT** | `0x4DBD49a3aE90Aa5F13091ccD29A896cbb5B171EB` | Base Sepolia USDT |

**Explorer Links:**
- Migration Contract: https://sepolia.basescan.org/address/0x197796d375FD4944fCf36113799EDbB3133BEfFF
- Vault 1: https://sepolia.basescan.org/address/0xDce2a7AE1AB9F7c0D14F7c3816a47975323F202d
- Vault 2: https://sepolia.basescan.org/address/0xE5b84b78bf434c1D85b3f685C0889eEa84a2617c

## Migration Flow

### How It Works

1. **Snapshot**: Admin takes snapshot of all user shares in Vault 1
2. **1:1 Conversion**: 800 vsUSDC shares → 800 USDC worth of USDT → Deposit to Vault 2
3. **User Receives**: vsUSDT shares in Vault 2 (proportional to their vsUSDC)

**Example:**
- User has 1000 vsUSDC shares in Vault 1
- These shares = 1000 USDC worth of assets
- Admin deposits 1000 USDT to Vault 2 on behalf of user
- User receives vsUSDT shares in Vault 2

## Step-by-Step Migration Process

### Step 1: Register Users

Register all users who need to be migrated. This takes a snapshot of their Vault 1 shares.

```solidity
// Register single user
migration.registerUser(0x123...);

// Register multiple users (recommended)
address[] memory users = [
    0x123...,
    0x456...,
    0x789...
];
migration.registerUsers(users);
```

**View registered users:**
```solidity
migration.getUserCount()
migration.getAllUsers()
migration.getUsers(offset, limit) // Paginated
```

### Step 2: Deposit USDT Liquidity

Admin needs to deposit enough USDT to cover all migrations (1:1 with USDC).

```solidity
// First, approve USDT
usdt.approve(0x197796d375FD4944fCf36113799EDbB3133BEfFF, amount);

// Then deposit
migration.depositUSDT(amount);
```

**Check liquidity:**
```solidity
(uint256 required, uint256 available, bool sufficient) = migration.checkUSDTLiquidity();
// required: Total USDT needed for all pending migrations
// available: Current USDT in contract
// sufficient: true if available >= required
```

### Step 3: Start Migration

Once users are registered and USDT is deposited:

```solidity
migration.startMigration();
```

This locks user registration and verifies sufficient USDT liquidity.

### Step 4: Execute Migration

Migrate users in batches (or individually):

```solidity
// Migrate in batches of 100 users
migration.migrateBatch(100);

// Or migrate single user
migration.migrateUser(0x123...);
```

**For each user:**
1. Takes snapshot of their Vault 1 shares
2. Calculates equivalent USDC amount
3. Deposits equal amount of USDT to Vault 2 for user
4. User receives vsUSDT shares (async via ERC-7540)

### Step 5: Complete Migration

Once all users are migrated:

```solidity
migration.completeMigration();
```

## View Functions

### Migration Status

```solidity
(
    bool started,
    bool completed,
    uint256 totalUsers,
    uint256 migratedUsers,
    uint256 pendingUsers
) = migration.getMigrationStatus();
```

### User Info

```solidity
(
    bool registered,
    bool migrated,
    uint256 vault1Shares,
    uint256 expectedUSDTAmount
) = migration.getUserMigrationInfo(userAddress);
```

## Emergency Functions

### Cancel Migration

If something goes wrong before completion:

```solidity
migration.cancelMigration();
```

This:
- Resets migration state to `not started`
- Returns all USDT to admin

### Withdraw USDT

```solidity
// Withdraw all USDT
migration.withdrawAllUSDT();

// Withdraw specific token
migration.emergencyWithdraw(tokenAddress, amount);
```

## Important Notes

### ERC-7540 Async Deposits

Lagoon vaults use ERC-7540 (async deposit/redeem):

1. Migration calls `vault2.requestDeposit(usdtAmount, migrationContract, user)`
2. Deposit is **pending** until curator settles it
3. User receives vsUSDT shares after settlement

**Implication**: Users won't see Vault 2 shares immediately. The curator needs to settle deposits.

### User Approval NOT Required

Users do **NOT** need to approve the migration contract. The migration:
- Takes snapshot of Vault 1 shares (read-only)
- Deposits USDT to Vault 2 on behalf of user
- User receives shares directly in Vault 2

Users keep their Vault 1 shares. This is a **parallel** migration, not a redemption-based migration.

### 1:1 Conversion

The migration uses 1:1 USDC to USDT conversion:
- 1000 USDC worth of vsUSDC → 1000 USDT deposited to Vault 2

## Testing Migration

### Test Flow

1. **Setup**: Create test deposits in Vault 1
   ```bash
   # Get testnet USDC
   # Deposit to Vault 1
   # Note your vsUSDC shares
   ```

2. **Deploy Migration**: Already done ✅

3. **Register Test User**:
   ```solidity
   migration.registerUser(testUserAddress);
   ```

4. **Deposit USDT**:
   ```bash
   # Get testnet USDT
   usdt.approve(migrationAddress, amount);
   migration.depositUSDT(amount);
   ```

5. **Execute Migration**:
   ```solidity
   migration.startMigration();
   migration.migrateUser(testUserAddress);
   ```

6. **Verify**:
   - Check user's vsUSDT balance in Vault 2 (after curator settles)
   - Verify USDT was deposited to Vault 2

## Contract ABI

Key functions:

```solidity
// Registration
function registerUser(address user) external onlyOwner
function registerUsers(address[] calldata users) external onlyOwner

// Liquidity
function depositUSDT(uint256 amount) external onlyOwner
function checkUSDTLiquidity() external view returns (uint256, uint256, bool)

// Migration
function startMigration() external onlyOwner
function migrateBatch(uint256 batchSize) external onlyOwner
function migrateUser(address user) external onlyOwner
function completeMigration() external onlyOwner

// Views
function getMigrationStatus() external view returns (bool, bool, uint256, uint256, uint256)
function getUserMigrationInfo(address) external view returns (bool, bool, uint256, uint256)
function getAllUsers() external view returns (address[])

// Emergency
function cancelMigration() external onlyOwner
function withdrawAllUSDT() external onlyOwner
function emergencyWithdraw(address, uint256) external onlyOwner
```

## Security Considerations

1. **Only Owner**: All migration functions are `onlyOwner`
2. **ReentrancyGuard**: Protected against reentrancy attacks
3. **Liquidity Check**: Ensures enough USDT before starting
4. **No User Approval**: Users don't need to approve contract

## Next Steps

1. ✅ Vault 1 (USDC) deployed
2. ✅ Vault 2 (USDT) deployed
3. ✅ Migration contract deployed
4. ⏳ Test with sample user
5. ⏳ Register all users
6. ⏳ Execute full migration

## Support

For questions or issues:
- Check contract on Basescan: https://sepolia.basescan.org/address/0x197796d375FD4944fCf36113799EDbB3133BEfFF
- Review VaultMigration.sol source code
- Test on Base Sepolia before mainnet deployment
