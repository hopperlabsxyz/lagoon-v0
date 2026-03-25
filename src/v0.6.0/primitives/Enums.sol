// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// ********************* VAULT ********************* //

enum State {
    Open, // The vault is open for deposits and withdrawals.
    Closing, // The vault is in the process of closing; no NEW deposit (settlement) are accepted into the vault
    Closed // The vault is closed; settlement are locked; withdrawals are guaranteed at fixed price per share
}

// ********************* FEE MANAGER ********************* //

enum FeeType {
    Management,
    Performance,
    Entry,
    Exit
}

// ********************* WHITELISTABLE ********************* //

enum AccessMode {
    Blacklist,
    Whitelist
}

// ********************* ERC7540 ********************* //

enum SyncMode {
    Both, // Both sync deposit and sync redeem are allowed (default)
    SyncDeposit, // Only sync deposit is allowed
    SyncRedeem, // Only sync redeem is allowed
    None // No sync operations are allowed
}
