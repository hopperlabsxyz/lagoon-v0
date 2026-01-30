// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Whitelistable} from "../Whitelistable.sol";
import {SanctionsList} from "../interfaces/SanctionsList.sol";
import {WhitelistState} from "../primitives/Enums.sol";
import {AccessControlDisabled} from "../primitives/Errors.sol";
import {
    BlacklistActivated,
    BlacklistUpdated,
    ExternalSanctionsListUpdated,
    WhitelistActivated,
    WhitelistDisabled,
    WhitelistUpdated
} from "../primitives/Events.sol";
import {RolesLib} from "./RolesLib.sol";

library WhitelistableLib {
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Whitelistable")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:storage-location erc7201:hopper.storage.Whitelistable
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant whitelistableStorage = 0x083cc98ab296d1a1f01854b5f7a2f47df4425a56ba7b35f7faa3a336067e4800;

    /// @dev Returns the storage struct of the whitelist.
    /// @return _whitelistableStorage The storage struct of the whitelist.
    function _getWhitelistableStorage()
        internal
        pure
        returns (Whitelistable.WhitelistableStorage storage _whitelistableStorage)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _whitelistableStorage.slot := whitelistableStorage
        }
    }

    /// @notice Adds multiple accounts to the whitelist
    function addToWhitelist(
        address[] memory accounts
    ) public {
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
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
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
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
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
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
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
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

    /// @notice Switches the whitelist mode
    /// @param newMode The new whitelist mode
    /// @dev If the whitelist is switched to blacklist, it emits a BlacklistActivated event
    /// @dev If the whitelist is switched to whitelist, it emits a WhitelistActivated event
    /// event
    function switchWhitelistMode(
        WhitelistState newMode
    ) public {
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();

        $.whitelistState = newMode;
        if (newMode == WhitelistState.Blacklist) {
            emit BlacklistActivated();
        } else if (newMode == WhitelistState.Whitelist) {
            emit WhitelistActivated();
        }
    }

    /// @notice Sets the external sanctions list
    function setExternalSanctionsList(
        SanctionsList externalSanctionList
    ) public {
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
        emit ExternalSanctionsListUpdated(address($.externalSanctionList), address(externalSanctionList));
        $.externalSanctionList = externalSanctionList;
    }

    /// @notice Checks if an account is whitelisted or blacklisted
    /// @dev In v0.6.0, this function is extended to also enforce blacklist checks.
    /// @param account The address of the account to check
    /// @return True if the account is whitelisted or not blacklisted, false otherwise
    function isWhitelisted(
        address account
    ) public view returns (bool) {
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
        WhitelistState _whitelistState = $.whitelistState;

        if (RolesLib._getRolesStorage().feeRegistry.protocolFeeReceiver() == account) {
            // if the account is the protocol fee receiver, it is always whitelisted
            return true;
        }
        // if the whitelist is active, we check if the account is whitelisted
        // if the whitelist is in blacklist mode and the account is blacklisted we return false
        bool internalListApproval =
            _whitelistState == WhitelistState.Whitelist ? $.isWhitelisted[account] : !$.isBlacklisted[account];

        // by default, we consider that the external sanctions list is not set, so we set it to true
        bool externalListApproval = true;

        // if the external sanctions list is set, we check if the account is not sanctioned
        if ($.externalSanctionList != SanctionsList(address(0))) {
            externalListApproval = !$.externalSanctionList.isSanctioned(account);
        }

        // if the account is whitelisted and not sanctioned, we return true
        return internalListApproval && externalListApproval;
    }
}
