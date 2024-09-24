// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {State} from "./Enums.sol";

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
