// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Whitelistable} from "../Whitelistable.sol";
import {WhitelistState} from "../primitives/Enums.sol";
import {BlacklistActivated, BlacklistUpdated, WhitelistActivated, WhitelistUpdated} from "../primitives/Events.sol";

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
    /// @dev If the whitelist is deactivated, it reverts
    /// @dev If the whitelist is switched to blacklist, it emits a WhitelistModeSwitched event
    /// @dev If the whitelist is switched to whitelist, it emits a WhitelistModeSwitched event
    /// @dev If the whitelist is switched to deactivated, it emits a WhitelistModeSwitched event and a WhitelistDisabled
    /// event
    function switchWhitelistMode(
        WhitelistState newMode
    ) public {
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();

        $.whitelistState = newMode;
        // emit the appropriate event based on the new mode
        // for backward compatiblity we emit 3 different events for the 3 possible modes
        // instead of emitting a single event with the new mode
        if (newMode == WhitelistState.Blacklist) {
            emit BlacklistActivated();
        } else if (newMode == WhitelistState.Whitelist) {
            emit WhitelistActivated();
        }
    }
}
