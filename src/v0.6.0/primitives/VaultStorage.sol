// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {State} from "./Enums.sol";

/// @custom:storage-location erc7201:hopper.storage.vault
/// @param newTotalAssets The new total assets of the vault. It is used to update the totalAssets variable.
/// @param state The state of the vault. It can be Open, Closing, or Closed.
struct VaultStorage {
    State state;
}
