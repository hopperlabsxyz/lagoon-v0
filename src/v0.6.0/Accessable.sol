// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "./Roles.sol";
import {SanctionsList} from "./interfaces/SanctionsList.sol";
import {AccessableLib} from "./libraries/AccessableLib.sol";
import {RolesLib} from "./libraries/RolesLib.sol";
import {AccessMode} from "./primitives/Enums.sol";

abstract contract Accessable is Roles {
    /// @custom:storage-location erc7201:hopper.storage.Whitelistable
    /// @param isWhitelisted The mapping of whitelisted addresses.
    /// @param accessMode The current access mode (whitelist or blacklist).
    /// @param isBlacklisted The mapping of blacklisted addresses.
    /// @param externalSanctionList The external sanctions list.
    struct AccessableStorage {
        mapping(address => bool) isWhitelisted;
        // in v0.6.0, we replace the bool isActivated with a enum AccessMode
        // bool isActivated; --> AccessMode accessMode;
        AccessMode accessMode;
        // added in v0.6.0
        mapping(address => bool) isBlacklisted;
        SanctionsList externalSanctionList;
    }

    /// @dev Initializes the whitelist.
    /// @param accessMode the access mode of the whitelist.
    // solhint-disable-next-line func-name-mixedcase
    function __Accessable_init(
        AccessMode accessMode,
        address externalSanctionsList
    ) internal onlyInitializing {
        AccessableLib.switchAccessMode(accessMode);
        AccessableLib.setExternalSanctionsList(SanctionsList(externalSanctionsList));
    }

    function switchAccessMode(
        AccessMode newMode
    ) public onlyOwner {
        AccessableLib.switchAccessMode(newMode);
    }

    /// @notice Checks if an account is whitelisted or blacklisted
    /// @dev In v0.6.0, this function is extended to also enforce blacklist checks.
    /// @param account The address of the account to check
    /// @return True if the account is whitelisted or not blacklisted, false otherwise
    function isAllowed(
        address account
    ) public view virtual returns (bool) {
        return AccessableLib.isAllowed(account);
    }

    /// @notice Adds multiple accounts to the whitelist
    function addToWhitelist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        AccessableLib.addToWhitelist(accounts);
    }

    /// @notice Removes multiple accounts from the whitelist
    /// @param accounts The addresses of the accounts to remove
    function revokeFromWhitelist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        AccessableLib.revokeFromWhitelist(accounts);
    }

    /// @notice Adds multiple accounts to the blacklist
    function addToBlacklist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        AccessableLib.addToBlacklist(accounts);
    }

    /// @notice Removes multiple accounts from the blacklist
    function revokeFromBlacklist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        AccessableLib.revokeFromBlacklist(accounts);
    }

    /// @notice Sets the external sanctions list
    function setExternalSanctionsList(
        SanctionsList sanctionsList
    ) external onlyWhitelistManager {
        AccessableLib.setExternalSanctionsList(sanctionsList);
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

// slot 1: accessMode
// Type: enum AccessMode (uint8)
// Description: Access mode enum value (only 1 byte used, right-aligned)
// Possible values: 0x00 (BlacklistMode), 0x01 (WhitelistMode), 0x02 (Deactivated), etc.
// Visual representation (bytes32):
//                                                          accessMode
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
// we upgrade the whitelistable contract from <v0.6.0 to v0.6.0
// 1) isActivated is 0 (deactivated)
//   1.1) accessMode is 0 (blacklist)
// --> vault remains as accessible as before the upgrade
// 2) isActivated is 1 (activated)
//   2.1) accessMode is 1 (whitelist)
// --> vault remains in whitelist mode
