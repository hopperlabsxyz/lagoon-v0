// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// ********************* VAULT ********************* //

enum State {
    Open, // The vault is open for deposits and withdrawals.
    Closing, // The vault is in the process of closing; no NEW deposit (settlement) are accepted into the vault
    Closed // The vault is closed; settlement are locked; withdrawals are guaranteed at fixed price per share
}

// ********************* WHITELISTABLE ********************* //
enum WhitelistState {
    Blacklist,
    Whitelist,
    Deactivated
}
