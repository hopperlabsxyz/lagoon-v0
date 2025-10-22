// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Whitelistable} from "../Whitelistable.sol";
import {WhitelistDisabled, WhitelistUpdated} from "../primitives/Events.sol";
import {Constant} from "./constant.sol";

library WhitelistableLib {
    function version() public pure returns (string memory) {
        return Constant.version();
    }

    function addToWhitelist(
        Whitelistable.WhitelistableStorage storage self,
        address[] memory accounts
    ) public {
        for (uint256 i = 0; i < accounts.length; i++) {
            self.isWhitelisted[accounts[i]] = true;
            emit WhitelistUpdated(accounts[i], true);
        }
    }

    function revokeFromWhitelist(
        Whitelistable.WhitelistableStorage storage self,
        address[] memory accounts
    ) public {
        uint256 i = 0;
        for (; i < accounts.length;) {
            self.isWhitelisted[accounts[i]] = false;
            emit WhitelistUpdated(accounts[i], false);
            // solhint-disable-next-line no-inline-assembly
            unchecked {
                ++i;
            }
        }
    }

    function disableWhitelist(
        Whitelistable.WhitelistableStorage storage self
    ) public {
        self.isActivated = false;
        emit WhitelistDisabled();
    }
}
