// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VaultMigration
 * @notice Migrates users from Vault 1 (USDC) to Vault 2 (USDT) with 1:1 conversion
 * @dev This contract handles the migration by:
 *      1. Taking snapshot of user shares in Vault 1
 *      2. Admin deposits USDT liquidity for 1:1 swap
 *      3. For each user: deposit USDT to Vault 2 on their behalf
 *      4. Users receive vsUSDT shares proportional to their vsUSDC shares
 */
interface ILagoonVault {
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function requestDeposit(uint256 assets, address controller, address owner) external payable returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
}

contract VaultMigration is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==================== STATE VARIABLES ====================

    // Vaults
    ILagoonVault public immutable vault1;  // USDC vault (source)
    ILagoonVault public immutable vault2;  // USDT vault (destination)

    // Tokens
    IERC20 public immutable usdc;
    IERC20 public immutable usdt;

    // Migration state
    bool public migrationStarted;
    bool public migrationCompleted;

    // Track users to migrate
    address[] public users;
    mapping(address => bool) public isRegistered;
    mapping(address => bool) public hasMigrated;
    mapping(address => uint256) public vault1SharesSnapshot;

    // ==================== EVENTS ====================

    event UserRegistered(address indexed user, uint256 shares);
    event UserMigrated(address indexed user, uint256 vault1Shares, uint256 usdtDeposited, uint256 requestId);
    event MigrationStarted(uint256 totalUsers);
    event MigrationCompleted(uint256 migratedUsers);
    event USDTDeposited(address indexed from, uint256 amount);
    event USDTWithdrawn(address indexed to, uint256 amount);

    // ==================== CONSTRUCTOR ====================

    constructor(
        address _vault1,
        address _vault2,
        address _usdc,
        address _usdt
    ) Ownable(msg.sender) {
        require(_vault1 != address(0), "Invalid vault1");
        require(_vault2 != address(0), "Invalid vault2");
        require(_usdc != address(0), "Invalid USDC");
        require(_usdt != address(0), "Invalid USDT");

        vault1 = ILagoonVault(_vault1);
        vault2 = ILagoonVault(_vault2);
        usdc = IERC20(_usdc);
        usdt = IERC20(_usdt);
    }

    // ==================== USER REGISTRATION ====================

    /**
     * @notice Register a user for migration
     * @dev Takes snapshot of user's Vault 1 shares
     * @param user Address to register
     */
    function registerUser(address user) external onlyOwner {
        require(!migrationStarted, "Migration already started");
        require(!isRegistered[user], "User already registered");

        uint256 shares = vault1.balanceOf(user);
        require(shares > 0, "User has no shares");

        users.push(user);
        isRegistered[user] = true;
        vault1SharesSnapshot[user] = shares;

        emit UserRegistered(user, shares);
    }

    /**
     * @notice Register multiple users at once
     * @param _users Array of addresses to register
     */
    function registerUsers(address[] calldata _users) external onlyOwner {
        require(!migrationStarted, "Migration already started");

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            if (!isRegistered[user]) {
                uint256 shares = vault1.balanceOf(user);
                if (shares > 0) {
                    users.push(user);
                    isRegistered[user] = true;
                    vault1SharesSnapshot[user] = shares;
                    emit UserRegistered(user, shares);
                }
            }
        }
    }

    // ==================== ADMIN: PREPARE MIGRATION ====================

    /**
     * @notice Admin deposits USDT for swap liquidity
     * @param amount Amount of USDT to deposit
     */
    function depositUSDT(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        usdt.safeTransferFrom(msg.sender, address(this), amount);
        emit USDTDeposited(msg.sender, amount);
    }

    /**
     * @notice Check if contract has enough USDT for migration
     * @return required Total USDT needed for all pending migrations
     * @return available Current USDT balance in contract
     * @return sufficient Whether we have enough USDT
     */
    function checkUSDTLiquidity() external view returns (uint256 required, uint256 available, bool sufficient) {
        required = getTotalUSDTRequired();
        available = usdt.balanceOf(address(this));
        sufficient = available >= required;
    }

    /**
     * @notice Get total USDT amount needed for migration
     * @dev Uses 1:1 conversion from USDC to USDT based on share snapshots
     */
    function getTotalUSDTRequired() public view returns (uint256 total) {
        for (uint256 i = 0; i < users.length; i++) {
            if (!hasMigrated[users[i]]) {
                uint256 shares = vault1SharesSnapshot[users[i]];
                uint256 usdcAmount = vault1.convertToAssets(shares);
                total += usdcAmount; // 1:1 USDC to USDT
            }
        }
    }

    // ==================== MIGRATION EXECUTION ====================

    /**
     * @notice Start the migration process
     * @dev Locks user registration
     */
    function startMigration() external onlyOwner {
        require(!migrationStarted, "Migration already started");
        require(users.length > 0, "No users registered");

        // Check if we have enough USDT
        uint256 required = getTotalUSDTRequired();
        uint256 available = usdt.balanceOf(address(this));
        require(available >= required, "Insufficient USDT liquidity");

        migrationStarted = true;
        emit MigrationStarted(users.length);
    }

    /**
     * @notice Migrate a batch of users
     * @dev Call multiple times if gas limit is reached
     * @param batchSize Number of users to migrate in this batch
     */
    function migrateBatch(uint256 batchSize) external onlyOwner nonReentrant {
        require(migrationStarted, "Migration not started");
        require(!migrationCompleted, "Migration already completed");
        require(batchSize > 0, "Batch size must be > 0");

        uint256 migrated = 0;

        for (uint256 i = 0; i < users.length && migrated < batchSize; i++) {
            address user = users[i];

            if (!hasMigrated[user]) {
                _migrateUser(user);
                migrated++;
            }
        }
    }

    /**
     * @notice Migrate a single user
     * @param user Address to migrate
     */
    function migrateUser(address user) external onlyOwner nonReentrant {
        require(migrationStarted, "Migration not started");
        require(isRegistered[user], "User not registered");
        require(!hasMigrated[user], "User already migrated");

        _migrateUser(user);
    }

    /**
     * @notice Internal migration logic for a single user
     * @dev Uses 1:1 conversion: 800 vsUSDC shares → 800 USDC worth of USDT → deposit to Vault 2
     * @param user Address to migrate
     */
    function _migrateUser(address user) internal {
        uint256 vault1Shares = vault1SharesSnapshot[user];

        // Calculate USDC amount based on shares
        uint256 usdcAmount = vault1.convertToAssets(vault1Shares);

        // 1:1 swap: same USDT amount as USDC
        uint256 usdtAmount = usdcAmount;

        // Ensure we have enough USDT
        require(usdt.balanceOf(address(this)) >= usdtAmount, "Insufficient USDT liquidity");

        // Approve Vault 2 to spend USDT
        usdt.forceApprove(address(vault2), usdtAmount);

        // Deposit USDT to Vault 2 for user using ERC-7540 requestDeposit
        // controller = this contract, owner = user (receives shares)
        uint256 requestId = vault2.requestDeposit(usdtAmount, address(this), user);

        // Mark as migrated
        hasMigrated[user] = true;

        emit UserMigrated(user, vault1Shares, usdtAmount, requestId);
    }

    /**
     * @notice Complete the migration
     * @dev Verifies all users have been migrated
     */
    function completeMigration() external onlyOwner {
        require(migrationStarted, "Migration not started");
        require(!migrationCompleted, "Migration already completed");

        uint256 migratedCount = 0;
        for (uint256 i = 0; i < users.length; i++) {
            if (hasMigrated[users[i]]) {
                migratedCount++;
            }
        }

        require(migratedCount == users.length, "Not all users migrated");

        migrationCompleted = true;
        emit MigrationCompleted(migratedCount);
    }

    // ==================== VIEW FUNCTIONS ====================

    /**
     * @notice Get total number of registered users
     */
    function getUserCount() external view returns (uint256) {
        return users.length;
    }

    /**
     * @notice Get comprehensive migration status
     */
    function getMigrationStatus() external view returns (
        bool started,
        bool completed,
        uint256 totalUsers,
        uint256 migratedUsers,
        uint256 pendingUsers
    ) {
        started = migrationStarted;
        completed = migrationCompleted;
        totalUsers = users.length;

        for (uint256 i = 0; i < users.length; i++) {
            if (hasMigrated[users[i]]) {
                migratedUsers++;
            }
        }

        pendingUsers = totalUsers - migratedUsers;
    }

    /**
     * @notice Get migration info for a specific user
     */
    function getUserMigrationInfo(address user) external view returns (
        bool registered,
        bool migrated,
        uint256 vault1Shares,
        uint256 expectedUSDTAmount
    ) {
        registered = isRegistered[user];
        migrated = hasMigrated[user];
        vault1Shares = vault1SharesSnapshot[user];

        if (vault1Shares > 0) {
            uint256 usdcAmount = vault1.convertToAssets(vault1Shares);
            expectedUSDTAmount = usdcAmount; // 1:1 conversion
        }
    }

    /**
     * @notice Get list of all registered users
     */
    function getAllUsers() external view returns (address[] memory) {
        return users;
    }

    /**
     * @notice Get paginated list of users
     */
    function getUsers(uint256 offset, uint256 limit) external view returns (address[] memory) {
        require(offset < users.length, "Offset out of bounds");

        uint256 end = offset + limit;
        if (end > users.length) {
            end = users.length;
        }

        address[] memory result = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = users[i];
        }

        return result;
    }

    // ==================== EMERGENCY FUNCTIONS ====================

    /**
     * @notice Withdraw stuck tokens
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token");
        IERC20(token).safeTransfer(owner(), amount);
        emit USDTWithdrawn(owner(), amount);
    }

    /**
     * @notice Withdraw all USDT from contract
     */
    function withdrawAllUSDT() external onlyOwner {
        uint256 balance = usdt.balanceOf(address(this));
        require(balance > 0, "No USDT to withdraw");
        usdt.safeTransfer(owner(), balance);
        emit USDTWithdrawn(owner(), balance);
    }

    /**
     * @notice Cancel migration and return to initial state
     * @dev Can only cancel if migration hasn't been completed
     */
    function cancelMigration() external onlyOwner {
        require(!migrationCompleted, "Migration already completed");
        migrationStarted = false;

        // Return USDT to admin
        uint256 usdtBalance = usdt.balanceOf(address(this));
        if (usdtBalance > 0) {
            usdt.safeTransfer(owner(), usdtBalance);
            emit USDTWithdrawn(owner(), usdtBalance);
        }
    }
}
