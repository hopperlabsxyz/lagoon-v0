// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Roles} from "./Roles.sol";
import {GuardrailsLib} from "./libraries/GuardrailsLib.sol";
import {RolesLib} from "./libraries/RolesLib.sol";
import {Guardrails} from "./primitives/Struct.sol";
using Math for uint256;

abstract contract GuardrailsManager is Roles {
    /// @custom:storage-definition erc7201:hopper.storage.FeeManager
    /// @param guardrails The current guardrails.
    struct GuardrailsManagerStorage {
        Guardrails guardrails;
    }

    function __GuardrailsManager_init(
        Guardrails memory guardrails_
    ) internal onlyInitializing {
        GuardrailsLib.updateGuardrails(guardrails_);
    }

    /**
     * @notice Checks if a price-per-share (PPS) update is compliant with the current guardrails.
     * @param currentTargetPps The current price-per-share.
     * @param nextTargetPps The proposed new price-per-share.
     * @param _timePast The time elapsed since the last update.
     * @return bool True if the update is compliant, false otherwise.
     */
    function isCompliant(
        uint256 currentTargetPps,
        uint256 nextTargetPps,
        uint256 _timePast
    ) public view returns (bool) {
        return GuardrailsLib.isCompliant(
            currentTargetPps, nextTargetPps, _timePast, GuardrailsLib._getGuardrailsManagerStorage().guardrails
        );
    }

    // @inheritdoc GuardrailsLib
    function updateGuardrails(
        Guardrails calldata guardrails_
    ) external onlySecurityCouncil {
        GuardrailsLib.updateGuardrails(guardrails_);
    }
}
