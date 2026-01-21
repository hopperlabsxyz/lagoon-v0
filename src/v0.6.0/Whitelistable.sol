// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "./Roles.sol";
import {RolesLib} from "./libraries/RolesLib.sol";
import {WhitelistableLib} from "./libraries/WhitelistableLib.sol";
import {WhitelistState} from "./primitives/Enums.sol";

abstract contract Whitelistable is Roles {
    /// @custom:storage-definition erc7201:hopper.storage.Whitelistable
    /// @param isWhitelisted The mapping of whitelisted addresses.
    /// @param isActivated The flag to check if the whitelist is activated.
    struct WhitelistableStorage {
        mapping(address => bool) isWhitelisted;
        // in v0.6.0, we replace the bool isActivated with a enum WhitelistState
        // bool isActivated; --> WhitelistState whitelistState;
        WhitelistState whitelistState;
        // added in v0.6.0
        mapping(address => bool) isBlacklisted;
    }

    /// @dev Initializes the whitelist.
    /// @param whitelistState the state of the whitelist.
    // solhint-disable-next-line func-name-mixedcase
    function __Whitelistable_init(
        WhitelistState whitelistState
    ) internal onlyInitializing {
        WhitelistableLib.switchWhitelistMode(whitelistState);
    }

    function switchWhitelistMode(
        WhitelistState newMode
    ) public onlyOwner {
        WhitelistableLib.switchWhitelistMode(newMode);
    }

    /// @notice Checks if an account is whitelisted or blacklisted
    /// @dev In v0.6.0, this function is extended to also enforce blacklist checks.
    /// @param account The address of the account to check
    /// @return True if the account is whitelisted or not blacklisted, false otherwise
    function isWhitelisted(
        address account
    ) public view returns (bool) {
        WhitelistableStorage storage $ = WhitelistableLib._getWhitelistableStorage();
        WhitelistState _whitelistState = $.whitelistState;

        if (RolesLib._getRolesStorage().feeRegistry.protocolFeeReceiver() == account) {
            // if the account is the protocol fee receiver, it is always whitelisted
            return true;
        }
        if (_whitelistState == WhitelistState.Deactivated) {
            // if the whitelist is deactivated, all accounts are whitelisted
            return true;
        }
        // if the whitelist is active, we check if the account is whitelisted
        // if the whitelist is in blacklist mode and the account is blacklisted we return false
        return _whitelistState == WhitelistState.Whitelist ? $.isWhitelisted[account] : !$.isBlacklisted[account];
    }

    /// @notice Adds multiple accounts to the whitelist
    function addToWhitelist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        WhitelistableLib.addToWhitelist(accounts);
    }

    /// @notice Removes multiple accounts from the whitelist
    /// @param accounts The addresses of the accounts to remove
    function revokeFromWhitelist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        WhitelistableLib.revokeFromWhitelist(accounts);
    }

    /// @notice Adds multiple accounts to the blacklist
    function addToBlacklist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        WhitelistableLib.addToBlacklist(accounts);
    }

    /// @notice Removes multiple accounts from the blacklist
    function revokeFromBlacklist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        WhitelistableLib.revokeFromBlacklist(accounts);
    }
}

// v0.6.0 storage layout changes:

// ==================== ORIGINAL STORAGE LAYOUT ====================
// slot 0: isWhitelisted (mapping pointer)
// Type: mapping(address => bool)
// Description: Pointer to the mapping of whitelisted addresses
// Visual representation (bytes32):
// 0x0000000000000000000000000000000000000000000000000000000000000000
//   |                           32 bytes                            |

// slot 1: isActivated
// Type: bool
// Description: Activation flag (only 1 byte used, right-aligned)
// Visual representation (bytes32):
//                                                          isActivated
// 0x0000000000000000000000000000000000000000000000000000000000000000
//   |                      31 bytes unused                      |xx|
//                                                               (1 byte)

// ==================== NEW STORAGE LAYOUT ====================
// slot 0: isWhitelisted (mapping pointer)
// Type: mapping(address => bool)
// Description: Pointer to the mapping of whitelisted addresses
// Visual representation (bytes32):
// 0x0000000000000000000000000000000000000000000000000000000000000000
//   |                           32 bytes                            |
// Note: The actual mapping data is stored at keccak256(key . slot)

// slot 1: whitelistState
// Type: enum WhitelistState (uint8)
// Description: Whitelist state enum value (only 1 byte used, right-aligned)
// Possible values: 0x00 (BlacklistMode), 0x01 (WhitelistMode), 0x02 (Deactivated), etc.
// Visual representation (bytes32):
//                                                          whitelistState
// 0x0000000000000000000000000000000000000000000000000000000000000001
//   |                      31 bytes unused                      |xx|
//                                                               (1 byte)

// slot 2: isBlacklisted (mapping pointer)
// Type: mapping(address => bool)
// Description: Pointer to the mapping of blacklisted addresses
// Visual representation (bytes32):
// 0x0000000000000000000000000000000000000000000000000000000000000000
//   |                           32 bytes                            |
// Note: The actual mapping data is stored at keccak256(key . slot)

// Upgrades scenario:
// we upgrade the whitelistable contract from v0.5.0 to v0.6.0
// 1) isActivated is 0 (deactivated)
//   1.1) whitelistState is 0 (blacklist)
// --> vault remains as accessible as before the upgrade
//     if the admin wants to disable the blacklist, he can call the disableWhitelist function
// 2) isActivated is 1 (activated)
//   2.1) whitelistState is 1 (whitelist)
// --> vault remains in whitelist mode
//     if the admin wants to disable the whitelist, he can call the disableWhitelist function
