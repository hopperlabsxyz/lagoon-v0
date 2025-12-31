// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {State} from "./Enums.sol";
import {Rates} from "./Struct.sol";

// ********************* VAULT ********************* //

/// @notice Emitted when a referral is made.
/// @param referral The address of the referral.
/// @param owner The address of the owner making the referral.
/// @param requestId The ID of the associated request.
/// @param assets The amount of assets involved in the referral.
event Referral(address indexed referral, address indexed owner, uint256 indexed requestId, uint256 assets);

/// @notice Emitted when the state of the vault is updated.
/// @param state The new state of the vault. Either Open, Closing or Close.
event StateUpdated(State state);

event SettleDeposit(
    uint40 indexed epochId,
    uint40 indexed settledId,
    uint256 totalAssets,
    uint256 totalSupply,
    uint256 assetsDeposited,
    uint256 sharesMinted
);

event SettleRedeem(
    uint40 indexed epochId,
    uint40 indexed settledId,
    uint256 totalAssets,
    uint256 totalSupply,
    uint256 assetsWithdrawed,
    uint256 sharesBurned
);

// ********************* WHITELISTABLE ********************* //

/// @notice Emitted when the Merkle tree root is updated.
/// @param root The new Merkle tree root.
event RootUpdated(bytes32 indexed root);

/// @notice Emitted when a whitelist entry is updated.
/// @param account The address of the account being updated.
/// @param authorized Indicates whether the account is authorized (true) or not (false).
event WhitelistUpdated(address indexed account, bool authorized);

/// @notice Emitted when the whitelist is disabled.
event WhitelistDisabled();

// ********************* ROLES ********************* //

/// @notice Emitted when the whitelist manager role is updated.
/// @param oldManager The address of the old whitelist manager.
/// @param newManager The address of the new whitelist manager.
event WhitelistManagerUpdated(address oldManager, address newManager);

/// @notice Emitted when the fee receiver role is updated.
/// @param oldReceiver The address of the old fee receiver.
/// @param newReceiver The address of the new fee receiver.
event FeeReceiverUpdated(address oldReceiver, address newReceiver);

/// @notice Emitted when the Valuation manager role is updated.
/// @param oldManager The address of the old Valuation manager.
/// @param newManager The address of the new Valuation manager.
event ValuationManagerUpdated(address oldManager, address newManager);

/// @notice Emitted when the safe role is updated.
/// @param oldSafe The address of the old safe.
/// @param newSafe The address of the new safe.
event SafeUpdated(address oldSafe, address newSafe);

/// @notice Emitted when the safe upgradeability is given up.
event SafeUpgradeabilityGivenUp();

// ********************* FEE_MANAGER ********************* //

/// @notice Emitted when the rates are updated.
/// @param oldRates The new rates.
/// @param newRate The new rates.
/// @param timestamp The timestamp at which the update will take effect.
event RatesUpdated(Rates oldRates, Rates newRate, uint256 timestamp);

/// @notice Emitted when the highWaterMark is updated.
/// @param oldHighWaterMark The old highWaterMark.
/// @param newHighWaterMark The new highWaterMark.
event HighWaterMarkUpdated(uint256 oldHighWaterMark, uint256 newHighWaterMark);

// ********************* ERC7540 ********************* //
/// @notice Emitted when the totalAssets variable is updated.
/// @param totalAssets The new total assets value.
event TotalAssetsUpdated(uint256 totalAssets);

/// @notice Emitted when the newTotalAssets variable is updated.
/// @param totalAssets The new newTotalAssets value.
event NewTotalAssetsUpdated(uint256 totalAssets);

/// @notice Emitted when a deposit request is canceled.
/// @param requestId The ID of the canceled request.
/// @param controller The address of the controller of the canceled request.
event DepositRequestCanceled(uint256 indexed requestId, address indexed controller);

/// @notice Emitted when the lifespan is updated.
/// @param oldLifespan The old lifespan.
/// @param newLifespan The new lifespan.
event TotalAssetsLifespanUpdated(uint128 oldLifespan, uint128 newLifespan);

/// @notice Same as a 4626 Deposit event
/// @param sender The address who gave its assets
/// @param owner The receiver of the shares
/// @param assets Amount of assets deposit
/// @param shares Amount of shares minted to owner
event DepositSync(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

/// @notice Emitted when the max cap is updated.
/// @param previousMaxCap The previous max cap.
/// @param maxCap The new max cap.
event MaxCapUpdated(uint256 previousMaxCap, uint256 maxCap);

/// @notice Emitted when the operator privileges are given up.
event GaveUpOperatorPrivileges();
