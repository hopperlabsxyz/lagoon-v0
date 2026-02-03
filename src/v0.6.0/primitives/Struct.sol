// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// ********************* ERC7540 ********************* //

/// @dev Holds management and performance rates for the vault.
/// @param managementRate Management fee rate in basis points.
/// @param performanceRate Performance fee rate in basis points.
/// @param entryRate Entry fee rate in basis points.
/// @param exitRate Exit fee rate in basis points.
struct Rates {
    uint16 managementRate;
    uint16 performanceRate;
    // added in v0.6.0
    // The new two 16-bit values for entry and exit rates will be packed here
    // into the same 32-byte slot currently used for the management and performance rates
    uint16 entryRate;
    uint16 exitRate;
}

/// @dev Holds data for a specific epoch.
/// @param settleId Unique identifier for the related settlement data.
/// @param depositRequest Records deposit requests by address.
/// @param redeemRequest Records redeem requests by address.
struct EpochData {
    uint40 settleId;
    mapping(address => uint256) depositRequest;
    mapping(address => uint256) redeemRequest;
}

/// @dev Holds settlement data for the vault.
/// @param totalSupply Total number of shares for this settlement.
/// @param totalAssets Total value of assets managed by the vault for this settlement.
/// @param pendingAssets The amount of assets that were pending to be settled.
/// @param pendingShares The amount of shares that were pending to be settled.
/// @param entryFeeRate The entry fee rate for this settlement, expressed in basis points.
/// @param exitFeeRate The exit fee rate for this settlement, expressed in basis points.
struct SettleData {
    uint256 totalSupply;
    uint256 totalAssets;
    uint256 pendingAssets;
    uint256 pendingShares;
    // new variables introduced with v0.6.0
    uint16 entryFeeRate;
    uint16 exitFeeRate;
}
