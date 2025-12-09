// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// ********************* ERC7540 ********************* //

/// @dev Holds management and performance rates for the vault.
/// @param managementRate Management fee rate in basis points.
/// @param performanceRate Performance fee rate in basis points.
struct Rates {
    uint16 managementRate;
    uint16 performanceRate;
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
struct SettleData {
    uint256 totalSupply;
    uint256 totalAssets;
    uint256 pendingAssets;
    uint256 pendingShares;
}
