// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Whitelistable} from "../Whitelistable.sol";
import {WhitelistDisabled, WhitelistUpdated} from "../primitives/Events.sol";
import {Constant} from "./Constant.sol";

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

    function version() public pure returns (string memory) {
        return Constant.version();
    }

    function addToWhitelist(
        address[] memory accounts
    ) public {
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
        for (uint256 i = 0; i < accounts.length; i++) {
            $.isWhitelisted[accounts[i]] = true;
            emit WhitelistUpdated(accounts[i], true);
        }
    }

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

    function disableWhitelist() public {
        Whitelistable.WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.isActivated = false;
        emit WhitelistDisabled();
    }
}
