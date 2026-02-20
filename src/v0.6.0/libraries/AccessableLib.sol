// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Accessable} from "../Accessable.sol";
import {SanctionsList} from "../interfaces/SanctionsList.sol";
import {AccessMode} from "../primitives/Enums.sol";
import {
    AccessModeUpdated,
    BlacklistUpdated,
    ExternalSanctionsListUpdated,
    WhitelistDisabled,
    WhitelistUpdated
} from "../primitives/Events.sol";
import {RolesLib} from "./RolesLib.sol";

library AccessableLib {
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Whitelistable")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:storage-location erc7201:hopper.storage.Whitelistable
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant accessableStorage = 0x083cc98ab296d1a1f01854b5f7a2f47df4425a56ba7b35f7faa3a336067e4800;

    /// @dev Returns the storage struct of the whitelist.
    /// @return _accessableStorage The storage struct of the accessable.
    function _getAccessableStorage() internal pure returns (Accessable.AccessableStorage storage _accessableStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _accessableStorage.slot := accessableStorage
        }
    }

    /// @notice Adds multiple accounts to the whitelist
    function addToWhitelist(
        address[] memory accounts
    ) public {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();
        uint256 i = 0;
        for (; i < accounts.length;) {
            $.isWhitelisted[accounts[i]] = true;
            emit WhitelistUpdated(accounts[i], true);
            // solhint-disable-next-line no-inline-assembly
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Removes multiple accounts from the whitelist
    function revokeFromWhitelist(
        address[] memory accounts
    ) public {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();
        uint256 i = 0;
        for (; i < accounts.length;) {
            $.isWhitelisted[accounts[i]] = false;
            emit WhitelistUpdated(accounts[i], false);
            // solhint-disable-next-line no-inline-assembly
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Adds multiple accounts to the blacklist
    function addToBlacklist(
        address[] memory accounts
    ) public {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();
        uint256 i = 0;
        for (; i < accounts.length;) {
            $.isBlacklisted[accounts[i]] = true;
            emit BlacklistUpdated(accounts[i], true);
            // solhint-disable-next-line no-inline-assembly
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Removes multiple accounts from the blacklist
    function revokeFromBlacklist(
        address[] memory accounts
    ) public {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();
        uint256 i = 0;
        for (; i < accounts.length;) {
            $.isBlacklisted[accounts[i]] = false;
            emit BlacklistUpdated(accounts[i], false);
            // solhint-disable-next-line no-inline-assembly
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Switches the access mode
    /// @param newMode The new access mode
    /// @dev Emits an AccessModeUpdated event with the new mode
    function switchAccessMode(
        AccessMode newMode
    ) public {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();

        $.accessMode = newMode;
        emit AccessModeUpdated(newMode);
    }

    /// @notice Sets the external sanctions list
    function setExternalSanctionsList(
        SanctionsList externalSanctionList
    ) public {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();
        emit ExternalSanctionsListUpdated(address($.externalSanctionList), address(externalSanctionList));
        $.externalSanctionList = externalSanctionList;
    }

    /// @notice Returns true if the blacklist is active, false otherwise
    function isBlacklistMode() public view returns (bool) {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();
        return $.accessMode == AccessMode.Blacklist;
    }

    /// @notice Checks if an account is whitelisted or blacklisted
    /// @dev In v0.6.0, this function is extended to also enforce blacklist checks.
    /// @param account The address of the account to check
    /// @return True if the account is whitelisted or not blacklisted, false otherwise
    function isAllowed(
        address account
    ) public view returns (bool) {
        Accessable.AccessableStorage storage $ = _getAccessableStorage();

        if (RolesLib._getRolesStorage().feeRegistry.protocolFeeReceiver() == account) {
            // if the account is the protocol fee receiver, it is always whitelisted
            return true;
        }

        if (RolesLib.isSuperOperator(msg.sender)) {
            // if the account is the super operator, it is always whitelisted
            return true;
        }

        // if the whitelist is active, we check if the account is whitelisted
        // if the whitelist is in blacklist mode and the account is blacklisted we return false
        bool internalListApproval =
            $.accessMode == AccessMode.Whitelist ? $.isWhitelisted[account] : !$.isBlacklisted[account];

        // by default, we consider that the external sanctions list is not set
        // so we set the external approval to true
        bool externalListApproval = true;

        // if the external sanctions list is defined, we check if the account is not sanctioned
        if ($.externalSanctionList != SanctionsList(address(0))) {
            externalListApproval = !$.externalSanctionList.isSanctioned(account);
        }

        // if the account is approved internally and externally, we return true
        return internalListApproval && externalListApproval;
    }
}
