// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {State} from "./Enums.sol";

// ********************* VAULT ********************* //

/// @notice Indicates that the vault is not Open. It's either Closing or Close.
/// @param currentState The current state of the vault.
error NotOpen(State currentState);

/// @notice Indicates that the vault is not in the process of closing. It's either Open or Close.
/// @param currentState The current state of the vault.
error NotClosing(State currentState);

/// @notice Indicates that the vault is Closed.
error Closed();

// ********************* ERC7540 ********************* //

/// @notice Indicates that preview deposit is disabled.
error ERC7540PreviewDepositDisabled();

/// @notice Indicates that preview mint is disabled.
error ERC7540PreviewMintDisabled();

/// @notice Indicates that preview redeem is disabled.
error ERC7540PreviewRedeemDisabled();

/// @notice Indicates that preview withdraw is disabled.
error ERC7540PreviewWithdrawDisabled();

/// @notice Indicates that only one request is allowed per settlement period.
error OnlyOneRequestAllowed();

/// @notice Indicates that the specified request is not cancelable.
/// @param requestId The ID of the request that cannot be canceled.
error RequestNotCancelable(uint256 requestId);

/// @notice Indicates an invalid operator for ERC7540 operations.
error ERC7540InvalidOperator();

/// @notice Indicates that the specified request ID is not claimable.
error RequestIdNotClaimable();

/// @notice Indicates that depositing a native token is not allowed.
error CantDepositNativeToken();

/// @notice Indicates that a new total assets value was not provided by the valuation manager.
error NewTotalAssetsMissing();

/// @notice Indicates that the new total assets value is not the one expected.
error WrongNewTotalAssets();

/// @notice Indicates that the total assets are outdated and that synchronous deposits are not allowed.
error TotalAssetsExpired();

// ********************* FEE MANAGER ********************* //

/// @notice Indicates that the provided rate exceeds the maximum allowed rate.
/// @param maxRate The maximum allowable rate.
error AboveMaxRate(uint256 maxRate);

// ********************* ROLES ********************* //

/// @notice Indicates that the caller is not a safe address.
/// @param safe The address of the safe.
error OnlySafe(address safe);

/// @notice Indicates that the caller is not the whitelist manager.
/// @param whitelistManager The address of the whitelist manager.
error OnlyWhitelistManager(address whitelistManager);

/// @notice Indicates that the caller is not the valuation manager.
/// @param valuationManager The address of the valuation manager.
error OnlyValuationManager(address valuationManager);

// ********************* WHITELISTABLE ********************* //

/// @notice Indicates that the caller is not whitelisted.
error NotWhitelisted();
