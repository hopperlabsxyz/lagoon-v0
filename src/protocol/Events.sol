// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

/// @notice Emitted when the protocol fee receiver is updated.
/// @param oldReceiver The old protocol fee receiver address.
/// @param newReceiver The new protocol fee receiver address.
event ProtocolFeeReceiverUpdated(address oldReceiver, address newReceiver);

/// @notice Emitted when the protocol fee rate is updated.
/// @param oldRate The old protocol fee rate.
/// @param newRate The new protocol fee rate.
event ProtocolRateUpdated(uint256 oldRate, uint256 newRate);

/// @notice Emitted when a custom fee rate is updated for a specific vault.
/// @param vault The address of the vault.
/// @param rate The new custom fee rate for the vault.
/// @param isActivated A boolean indicating whether the custom rate is activated.
event CustomRateUpdated(address vault, uint16 rate, bool isActivated);
