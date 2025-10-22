// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {State} from "../primitives/Enums.sol";
import {StateUpdated} from "../primitives/Events.sol";
import {VaultStorage} from "../primitives/VaultStorage.sol";
import {ERC7540Lib} from "./ERC7540Lib.sol";

library VaultStateLib {
    using ERC7540Lib for ERC7540.ERC7540Storage;

    /// @notice Initiates the closing of the vault. Can only be called by the owner.
    /// @dev we make sure that initiate closing will make an epoch changement if the variable newTotalAssets is
    /// "defined"
    /// @dev (!= type(uint256).max). This guarantee that no userShares will be locked in a pending state.
    function initiateClosing(
        VaultStorage storage self,
        ERC7540.ERC7540Storage storage erc7540
    ) public {
        if (erc7540.newTotalAssets != type(uint256).max) {
            erc7540.updateNewTotalAssets(erc7540.newTotalAssets);
        }
        self.state = State.Closing;
        emit StateUpdated(State.Closing);
    }
}
