// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

library PausableLib {
    /// @dev Throws if the contract is paused.
    function requireNotPaused() internal view {
        if (PausableUpgradeable(address(this)).paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
    }
}
