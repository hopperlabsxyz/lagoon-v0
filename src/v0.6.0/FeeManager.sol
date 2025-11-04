// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FeeLib} from "./libraries/FeeLib.sol";
import {AboveMaxRate} from "./primitives/Errors.sol";
import {HighWaterMarkUpdated, RatesUpdated} from "./primitives/Events.sol";
import {Rates} from "./primitives/Struct.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";

abstract contract FeeManager is Ownable2StepUpgradeable {
    using Math for uint256;

    uint16 public constant MAX_MANAGEMENT_RATE = FeeLib.MAX_MANAGEMENT_RATE;
    uint16 public constant MAX_PERFORMANCE_RATE = FeeLib.MAX_PERFORMANCE_RATE;
    uint16 public constant MAX_PROTOCOL_RATE = FeeLib.MAX_PROTOCOL_RATE;

    /// @custom:storage-definition erc7201:hopper.storage.FeeManager
    /// @param newRatesTimestamp the timestamp at which the new rates will be applied
    /// @param lastFeeTime the timestamp of the last fee calculation, it is used to compute management fees
    /// @param highWaterMark the highest price per share ever reached, performance fees are taken when the price per
    /// share is above this value
    /// @param cooldown the time to wait before applying new rates
    /// @param rates the current fee rates
    /// @param oldRates the previous fee rates, they are used during the cooldown period when new rates are set
    /// @param feeRegistry the fee registry contract, it is used to read the protocol rate
    struct FeeManagerStorage {
        FeeRegistry feeRegistry;
        uint256 newRatesTimestamp;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        uint256 cooldown;
        Rates rates;
        Rates oldRates;
    }

    /// @notice Initialize the FeeManager contract
    /// @param _registry the address of the fee registry contract
    /// @param _managementRate the management rate, expressed in BPS
    /// @param _performanceRate the performance rate, expressed in BPS
    /// @param _decimals the number of decimals of the shares
    /// @param _cooldown the time to wait before applying new rates
    // solhint-disable-next-line func-name-mixedcase
    function __FeeManager_init(
        address _registry,
        uint16 _managementRate,
        uint16 _performanceRate,
        uint256 _decimals,
        uint256 _cooldown
    ) internal onlyInitializing {
        if (_managementRate > MAX_MANAGEMENT_RATE) {
            revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        }
        if (_performanceRate > MAX_PERFORMANCE_RATE) {
            revert AboveMaxRate(MAX_PERFORMANCE_RATE);
        }

        FeeManagerStorage storage $ = FeeLib._getFeeManagerStorage();

        $.newRatesTimestamp = block.timestamp;

        $.cooldown = _cooldown;

        $.feeRegistry = FeeRegistry(_registry);
        $.highWaterMark = 10 ** _decimals;

        $.rates.managementRate = _managementRate;
        $.rates.performanceRate = _performanceRate;
    }

    /// @notice update the fee rates, the new rates will be applied after the cooldown period
    /// @param newRates the new fee rates
    function updateRates(
        Rates memory newRates
    ) external onlyOwner {
        FeeLib.updateRates(FeeLib._getFeeManagerStorage(), newRates);
    }

    /// @dev Since we have a cooldown period and to avoid a double call
    /// to update the feeRates, this function returns a different rate
    /// following the timestamp
    /// @notice the current fee rates
    function feeRates() public view returns (Rates memory) {
        return FeeLib.feeRates();
    }
}
