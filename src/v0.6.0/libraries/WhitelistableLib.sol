// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Whitelistable} from "../Whitelistable.sol";
import {WhitelistDisabled, WhitelistUpdated} from "../primitives/Events.sol";

library WhitelistableLib {
    function addToWhitelist(
        Whitelistable.WhitelistableStorage storage $,
        address[] memory accounts
    ) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            $.isWhitelisted[accounts[i]] = true;
            emit WhitelistUpdated(accounts[i], true);
        }
    }

    function revokeFromWhitelist(
        Whitelistable.WhitelistableStorage storage $,
        address[] memory accounts
    ) internal {
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

    function disableWhitelist(
        Whitelistable.WhitelistableStorage storage $
    ) internal {
        $.isActivated = false;
        emit WhitelistDisabled();
    }
}
