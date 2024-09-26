// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {State} from "./Enums.sol";
import {Rates} from "./FeeManager.sol";

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

/// @notice Emitted when the total assets of the vault are updated.
/// @param totalAssets The new total assets value.
event TotalAssetsUpdated(uint256 totalAssets);

/// @notice Emitted when the total assets are updated with a new value.
/// @param totalAssets The updated total assets value.
event UpdateTotalAssets(uint256 totalAssets);

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

/// @notice Emitted when the NAV manager role is updated.
/// @param oldManager The address of the old NAV manager.
/// @param newManager The address of the new NAV manager.
event NavManagerUpdated(address oldManager, address newManager);

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
