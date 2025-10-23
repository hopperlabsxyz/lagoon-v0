// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Constant} from "./Constant.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

library PausableLib {
    function version() public pure returns (string memory) {
        return Constant.version();
    }

    /// @dev Throws if the contract is paused.
    function requireNotPaused() internal view {
        if (PausableUpgradeable(address(this)).paused()) {
            revert PausableUpgradeable.EnforcedPause();
        }
    }
}
