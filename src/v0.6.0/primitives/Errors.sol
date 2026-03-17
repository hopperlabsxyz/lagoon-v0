// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FeeType, State} from "./Enums.sol";

// ********************* VAULT ********************* //

/// @notice Indicates that the vault is not Open. It's either Closing or Closed.
/// @param currentState The current state of the vault.
error NotOpen(State currentState);

/// @notice Indicates that the vault is not in the process of closing. It's either Open or Closed.
/// @param currentState The current state of the vault.
error NotClosing(State currentState);

/// @notice Indicates that the vault is Closed.
error Closed();

/// @notice No new valuation proposition is allowed
error ValuationUpdateNotAllowed();

/// @notice Indicates that the vault initialization failed.
error VaultInitializationFailed();

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

/// @notice Indicates that totalAssets value is outdated and that synchronous deposits are not allowed.
error OnlyAsyncDepositAllowed();

/// @notice Indicates that deposit can only happen via the synchronous path.
error OnlySyncDepositAllowed();

/// @notice Indicates that the max cap is reached.
error MaxCapReached();

/// @notice Indicates that sync redeem is not allowed.
error SyncRedeemNotAllowed();

/// @notice Only asynchronous operations are allowed.
error AsyncOnly();

/// @notice Indicates that the redeemed assets are below the minimum requested.
/// @param assets The actual assets after fees.
/// @param minimumAssets The minimum assets requested by the caller.
error BelowMinimumAssets(uint256 assets, uint256 minimumAssets);

/// @notice Indicates that the controller is invalid.
/// @param controller The address of the controller.
error InvalidController(address controller);

/// @notice Indicates that the receiver is invalid.
/// @param receiver The address of the receiver.
error InvalidReceiver(address receiver);

// ********************* FEE MANAGER ********************* //

/// @notice Indicates that the provided rate exceeds the maximum allowed rate.
/// @param maxRate The maximum allowable rate.
error AboveMaxRate(uint256 maxRate);

/// @notice Indicates that the fee rate cannot be increased and must only decrease.
/// @param currentRate The current entry or exit fee rate in basis points.
/// @param newRate The new entry or exit fee rate in basis points.
/// @param feeType The type of fee rate that cannot be increased.
error RateCanOnlyDecrease(uint256 currentRate, uint256 newRate, FeeType feeType);

/// @notice Indicates that high water mark reset is not allowed for this vault.
error HighWaterMarkResetNotAllowed();

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

/// @notice Indicates that the safe upgradeability has been given up..
error SafeUpgradeabilityNotAllowed();

/// @notice Indicates that the caller is not the security council.
/// @param securityCouncil The address of the security council.
error OnlySecurityCouncil(address securityCouncil);

// ********************* WHITELISTABLE ********************* //

/// @notice Indicates that the address is not allowed to do the operation.
/// @param _address The address that is not allowed to do the operation.
error AddressNotAllowed(address _address);

// ********************* GUARDRAILS ********************* //

/// @notice Indicates that the new total assets value is not compliant with the guardrails.
error GuardrailsViolation();

/// @notice Indicates that the lower rate cannot be set to the minimum value of int256.
error LowerRateCannotBeInt256Min();
