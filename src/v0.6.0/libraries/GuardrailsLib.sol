// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LowerRateCannotBeInt256Min} from "../primitives/Errors.sol";
import {GuardrailsUpdated} from "../primitives/Events.sol";
import {Guardrails} from "../primitives/Struct.sol";
using Math for uint256;

library GuardrailsLib {
    // one year in seconds
    uint256 public constant ONE_YEAR = 31_556_952 seconds;
    // scale to avoid loss of precision
    uint256 public constant SCALE = 1e18;

    /// @custom:storage-definition erc7201:hopper.storage.FeeManager
    /// @param guardrails The current guardrails.
    struct GuardrailsManagerStorage {
        Guardrails guardrails;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.GuardrailsManager")) - 1)) & ~bytes32(uint256(0xff));
    /// @custom:storage-location erc7201:hopper.storage.GuardrailsManager
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant guardrailsManagerStorage =
        0xd851cf94ad565ef91472fd51daf3f5f2311d4c6801bf4d880e94a7f28b854800;

    /// @dev Returns the storage struct of the guardrails manager.
    /// @return _guardrailsManagerStorage The storage struct of the guardrails manager.
    function _getGuardrailsManagerStorage()
        internal
        pure
        returns (GuardrailsManagerStorage storage _guardrailsManagerStorage)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _guardrailsManagerStorage.slot := guardrailsManagerStorage
        }
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
        uint256 _timePast,
        Guardrails calldata _guardrails
    ) public pure returns (bool) {
        // updating with a 0 second timepast will revert
        uint256 scaleToOneYear = ONE_YEAR / _timePast;
        int256 lowerRate = _guardrails.lowerRate;

        if (nextPps >= currentPps) {
            // we know that the variation is positive
            uint256 variation = (nextPps - currentPps) * scaleToOneYear * SCALE / currentPps;
            uint256 upperRate = _guardrails.upperRate;

            if (lowerRate < 0) {
                // if the lower rate is negative, we only need to check if the variation is greater than the upper rate
                return upperRate >= variation;
            }

            // if the lower rate is positive, we need to check if the variation is greater than the lower rate
            // and less than the upper rate
            return upperRate >= variation && variation >= uint256(lowerRate);
        } else {
            // we know that the variation is negative
            // the upper rate is always positive, no need to check if it's greater than the variation

            // if the policy doesn't accept decrease we can return false
            if (lowerRate >= 0) {
                return false;
            }

            // even if pps is decreasing, we compute the variation as a positive integer to avoid types conversions
            // errors. a - b / b <=> -(b - a) / b
            uint256 variation = (currentPps - nextPps) * scaleToOneYear * SCALE / currentPps;
            // since variation is > 0, we have to inverse the check.
            // -10 >= -15 <=> 10 <= 15
            return variation <= uint256(-lowerRate);
        }
    }

    /**
     * @notice Updates the current policy with a new one.
     * @param guardrails_ The new guardrails to be set.
     */
    function updateGuardrails(
        Guardrails memory guardrails_
    ) external {
        GuardrailsManagerStorage storage $ = _getGuardrailsManagerStorage();
        if (guardrails_.lowerRate == type(int256).min) {
            revert LowerRateCannotBeInt256Min();
        }
        emit GuardrailsUpdated($.guardrails, guardrails_);
        $.guardrails = guardrails_;
    }
}
