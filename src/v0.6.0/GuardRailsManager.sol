// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Roles} from "./Roles.sol";
import {GuardrailsLib} from "./libraries/GuardrailsLib.sol";
import {RolesLib} from "./libraries/RolesLib.sol";
import {Guardrails} from "./primitives/Struct.sol";
using Math for uint256;

abstract contract GuardrailsManager is Roles {
    /// @custom:storage-definition erc7201:hopper.storage.GuardrailsManager
    /// @param guardrails The current guardrails.
    struct GuardrailsManagerStorage {
        Guardrails guardrails;
        bool activated;
    }

    /**
     * @notice Checks if a price-per-share (PPS) update is compliant with the current guardrails.
     * @param currentPps The current price-per-share.
     * @param nextPps The proposed new price-per-share.
     * @param _timePast The time elapsed since the last update.
     * @return bool True if the update is compliant, false otherwise.
     */
    function isCompliant(
        uint256 currentPps,
        uint256 nextPps,
        uint256 _timePast
    ) public view returns (bool) {
        GuardrailsManager.GuardrailsManagerStorage storage $ = GuardrailsLib._getGuardrailsManagerStorage();
        if (!$.activated) {
            return true;
        }

        Guardrails memory guardrails = $.guardrails;
        return GuardrailsLib.isCompliant({
            currentPps: currentPps, nextPps: nextPps, _timePast: _timePast, _guardrails: guardrails
        });
    }

    /// @notice Updates the current guardrails policy with a new one.
    /// @param guardrails_ The new guardrails to be set.
    function updateGuardrails(
        Guardrails calldata guardrails_
    ) external onlySecurityCouncil {
        GuardrailsLib.updateGuardrails(guardrails_);
    }

    /// @notice Updates the active status of the guardrails.
    /// @param activated_ The new activated status.
    function updateActivated(
        bool activated_
    ) external onlySecurityCouncil {
        GuardrailsLib.updateActivated(activated_);
    }
}
