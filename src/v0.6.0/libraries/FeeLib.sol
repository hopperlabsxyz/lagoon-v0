// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FeeManager} from "../FeeManager.sol";
import {AboveMaxRate} from "../primitives/Errors.sol";
import {RatesUpdated} from "../primitives/Events.sol";
import {Rates} from "../primitives/Struct.sol";
import {Constant} from "./constant.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library FeeLib {
    using Math for uint256;

    uint256 constant ONE_YEAR = 365 days;
    uint256 constant BPS_DIVIDER = 10_000; // 100 %

    uint16 constant MAX_MANAGEMENT_RATE = 1000; // 10 %
    uint16 constant MAX_PERFORMANCE_RATE = 5000; // 50 %
    uint16 constant MAX_PROTOCOL_RATE = 3000; // 30 %

    function version() public pure returns (string memory) {
        return Constant.version();
    }

    /// @dev Calculate the management fee
    /// @param assets the total assets under management
    /// @param annualRate the management rate, expressed in BPS and corresponding to the annual
    /// @param timeElapsed the time elapsed since the last fee calculation in seconds
    /// @return managementFee the management fee express in assets
    function calculateManagementFee(
        uint256 assets,
        uint256 annualRate,
        uint256 timeElapsed
    ) public pure returns (uint256 managementFee) {
        uint256 annualFee = assets.mulDiv(annualRate, BPS_DIVIDER, Math.Rounding.Ceil);
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR, Math.Rounding.Ceil);
    }

    /// @dev Calculate the performance fee
    /// @dev The performance is calculated as the difference between the current price per share and the high water mark
    /// @dev The performance fee is calculated as the product of the performance and the performance rate
    /// @param _rate the performance rate, expressed in BPS
    /// @param _totalSupply the total supply of shares
    /// @param _pricePerShare the current price per share
    /// @param _highWaterMark the highest price per share ever reached
    /// @param _decimals the number of decimals of the shares
    /// @return performanceFee the performance fee express in assets
    function calculatePerformanceFee(
        uint256 _rate,
        uint256 _totalSupply,
        uint256 _pricePerShare,
        uint256 _highWaterMark,
        uint256 _decimals
    ) public pure returns (uint256 performanceFee) {
        if (_pricePerShare > _highWaterMark) {
            uint256 profitPerShare;
            unchecked {
                profitPerShare = _pricePerShare - _highWaterMark;
            }
            uint256 profit = profitPerShare.mulDiv(_totalSupply, 10 ** _decimals, Math.Rounding.Ceil);
            performanceFee = profit.mulDiv(_rate, BPS_DIVIDER, Math.Rounding.Ceil);
        }
    }

    function doFeeRepartition(
        FeeManager.FeeManagerStorage storage self,
        uint256 totalFees,
        uint256 _totalSupply,
        uint256 _totalAssets,
        uint8 _decimalsOffset
    ) public view returns (uint256 managerShares, uint256 protocolShares) {
        // since we are minting shares without actually increasing the totalAssets, we need to compensate the future
        // dilution of price per share by virtually decreasing totalAssets in our computation
        uint256 totalShares =
            totalFees.mulDiv(_totalSupply + 10 ** _decimalsOffset, (_totalAssets - totalFees) + 1, Math.Rounding.Ceil);

        protocolShares = totalShares.mulDiv(protocolRate(self), BPS_DIVIDER, Math.Rounding.Ceil);
        managerShares = totalShares - protocolShares;
    }

    /// @dev Calculate and return the manager and protocol shares to be minted as fees
    /// @dev total fees are the sum of the management and performance fees
    /// @dev manager shares are the fees that go to the manager, it is the difference between the total fees and the
    /// protocol fees
    /// @dev protocol shares are the fees that go to the protocol
    /// @return managerShares the manager shares to be minted as fees
    /// @return protocolShares the protocol shares to be minted as fees
    function calculateFees(
        FeeManager.FeeManagerStorage storage self,
        uint256 _totalAssets,
        uint256 _totalSupply,
        uint8 _decimalsOffset,
        uint8 _decimals
    ) public view returns (uint256 managerShares, uint256 protocolShares) {
        /// Management fee computation ///

        Rates memory _rates = feeRates(self);
        uint256 managementFees = calculateManagementFee(
            _totalAssets,
            _rates.managementRate,
            block.timestamp - self.lastFeeTime // timeElapsed
        );

        // by taking management fees the price per share decreases
        uint256 pricePerShare = (10 ** _decimals)
        .mulDiv(_totalAssets + 1 - managementFees, _totalSupply + 10 ** _decimalsOffset, Math.Rounding.Ceil);

        /// Performance fee computation ///

        uint256 performanceFees =
            calculatePerformanceFee(_rates.performanceRate, _totalSupply, pricePerShare, self.highWaterMark, _decimals);

        /// Protocol fee computation & convertion to shares ///
        return doFeeRepartition(self, managementFees + performanceFees, _totalSupply, _totalAssets, _decimalsOffset);
    }

    /// @notice update the fee rates, the new rates will be applied after the cooldown period
    /// @param newRates the new fee rates
    function updateRates(
        FeeManager.FeeManagerStorage storage self,
        Rates memory newRates
    ) public {
        if (newRates.managementRate > MAX_MANAGEMENT_RATE) {
            revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        }
        if (newRates.performanceRate > MAX_PERFORMANCE_RATE) {
            revert AboveMaxRate(MAX_PERFORMANCE_RATE);
        }

        uint256 newRatesTimestamp = block.timestamp + self.cooldown;
        Rates memory currentRates = self.rates;

        self.newRatesTimestamp = newRatesTimestamp;
        self.oldRates = currentRates;
        self.rates = newRates;
        emit RatesUpdated(currentRates, newRates, newRatesTimestamp);
    }

    /// @dev Read the protocol rate from the fee registry
    /// @dev if the value is above the MAX_PROTOCOL_RATE, return the MAX_PROTOCOL_RATE
    /// @return protocolRate the protocol rate
    function protocolRate(
        FeeManager.FeeManagerStorage storage self
    ) public view returns (uint256) {
        uint256 _protocolRate = self.feeRegistry.protocolRate();
        if (_protocolRate > MAX_PROTOCOL_RATE) return MAX_PROTOCOL_RATE;
        return _protocolRate;
    }

    /// @dev Since we have a cooldown period and to avoid a double call
    /// to update the feeRates, this function returns a different rate
    /// following the timestamp
    /// @notice the current fee rates
    function feeRates(
        FeeManager.FeeManagerStorage storage self
    ) public view returns (Rates memory) {
        if (self.newRatesTimestamp <= block.timestamp) return self.rates;
        return self.oldRates;
    }
}
