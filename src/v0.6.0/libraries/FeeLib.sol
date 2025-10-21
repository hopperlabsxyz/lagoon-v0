// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library FeeLib {
    using Math for uint256;

    uint256 constant ONE_YEAR = 365 days;
    uint256 constant BPS_DIVIDER = 10_000; // 100 %

    /// @dev Calculate the management fee
    /// @param assets the total assets under management
    /// @param annualRate the management rate, expressed in BPS and corresponding to the annual
    /// @param timeElapsed the time elapsed since the last fee calculation in seconds
    /// @return managementFee the management fee express in assets
    function calculateManagementFee(
        uint256 assets,
        uint256 annualRate,
        uint256 timeElapsed
    ) external pure returns (uint256 managementFee) {
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
    ) external pure returns (uint256 performanceFee) {
        if (_pricePerShare > _highWaterMark) {
            uint256 profitPerShare;
            unchecked {
                profitPerShare = _pricePerShare - _highWaterMark;
            }
            uint256 profit = profitPerShare.mulDiv(_totalSupply, 10 ** _decimals, Math.Rounding.Ceil);
            performanceFee = profit.mulDiv(_rate, BPS_DIVIDER, Math.Rounding.Ceil);
        }
    }
}
