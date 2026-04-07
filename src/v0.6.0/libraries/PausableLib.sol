// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title PausableLib - Library for pausability checks
/// @notice Provides a guard function to revert when the contract is paused
library PausableLib {
    /// @notice Reverts with EnforcedPause if the contract is paused
    function requireNotPaused() internal view {
        if (PausableUpgradeable(address(this)).paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
    }
}
