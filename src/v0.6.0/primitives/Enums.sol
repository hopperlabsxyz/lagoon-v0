// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// ********************* VAULT ********************* //

/// @notice Represents the lifecycle state of the vault
enum State {
    /// @notice The vault is open for deposits and withdrawals
    Open,
    /// @notice The vault is in the process of closing
    Closing,
    /// @notice The vault is closed; settlements are locked; withdrawals are guaranteed at fixed price per share
    Closed
}

// ********************* FEE MANAGER ********************* //

/// @notice Types of fees that can be applied by the vault
enum FeeType {
    /// @notice Ongoing management fee charged over time
    Management,
    /// @notice Fee charged on positive performance above the high water mark
    Performance,
    /// @notice Fee charged on deposits
    Entry,
    /// @notice Fee charged on redemptions
    Exit
}

// ********************* WHITELISTABLE ********************* //

/// @notice Access control mode for the vault
enum AccessMode {
    /// @notice Blacklist mode: all addresses allowed except blacklisted ones
    Blacklist,
    /// @notice Whitelist mode: only whitelisted addresses are allowed
    Whitelist
}

// ********************* ERC7540 ********************* //

/// @notice Controls which synchronous operations are enabled on the vault
enum SyncMode {
    /// @notice Both sync deposit and sync redeem are allowed (default)
    Both,
    /// @notice Only sync deposit is allowed
    SyncDeposit,
    /// @notice Only sync redeem is allowed
    SyncRedeem,
    /// @notice No sync operations are allowed (async only)
    None
}
