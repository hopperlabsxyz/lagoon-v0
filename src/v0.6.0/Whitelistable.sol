// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Roles} from "./Roles.sol";
import {RolesLib} from "./libraries/RolesLib.sol";
import {WhitelistableLib} from "./libraries/WhitelistableLib.sol";

abstract contract Whitelistable is Roles {
    /// @custom:storage-definition erc7201:hopper.storage.Whitelistable
    /// @param isWhitelisted The mapping of whitelisted addresses.
    /// @param isActivated The flag to check if the whitelist is activated.
    struct WhitelistableStorage {
        mapping(address => bool) isWhitelisted;
        bool isActivated;
    }

    /// @dev Initializes the whitelist.
    /// @param activate if the whitelist should be activated.
    // solhint-disable-next-line func-name-mixedcase
    function __Whitelistable_init(
        bool activate
    ) internal onlyInitializing {
        if (activate) {
            WhitelistableStorage storage $ = WhitelistableLib._getWhitelistableStorage();
            $.isActivated = true;
        }
    }

    /// @notice Deactivates the whitelist
    function disableWhitelist() public onlyOwner {
        WhitelistableLib.disableWhitelist();
    }

    /// @notice Checks if an account is whitelisted
    /// @param account The address of the account to check
    /// @return True if the account is whitelisted, false otherwise
    function isWhitelisted(
        address account
    ) public view returns (bool) {
        WhitelistableStorage storage $ = WhitelistableLib._getWhitelistableStorage();
        if (RolesLib._getRolesStorage().feeRegistry.protocolFeeReceiver() == account) {
            return true;
        }
        return $.isActivated ? $.isWhitelisted[account] : true;
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
}
