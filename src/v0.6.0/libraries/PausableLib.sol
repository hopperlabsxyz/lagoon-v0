// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

library PausableLib {
    /// @dev Throws if the contract is paused.
    function requireNotPaused(
        PausableUpgradeable.PausableStorage storage self
    ) internal view {
        if (self._paused) {
            revert PausableUpgradeable.EnforcedPause();
        }
    }

    /// @dev Throws if the contract is paused.
    function requireNotPaused(
        bool paused
    ) internal pure {
        if (paused) {
            revert PausableUpgradeable.EnforcedPause();
        }
    }
}
