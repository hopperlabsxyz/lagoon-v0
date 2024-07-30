// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library FeeLibrary {
    using Math for uint256;

    uint256 public constant BPS = 10_000; // 100 %
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant MAX_MANAGEMENT_RATE = 1_000; // 10 %
    uint256 public constant MAX_PERFORMANCE_RATE = 5_000; // 50 %

    function calculateManagementFee(
        uint256 assets,
        uint256 timeElapsed,
        uint256 rate
    ) public pure returns (uint256 managementFee) {
        require(rate <= MAX_MANAGEMENT_RATE);
        uint256 annualFee = assets.mulDiv(rate, BPS, Math.Rounding.Floor);
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR);
    }

    function calculatePerformanceFee(
        uint256 assets,
        uint256 highWaterMark,
        uint256 rate
    ) public pure returns (uint256 performanceFee) {
        require(rate <= MAX_PERFORMANCE_RATE);
        if (assets > highWaterMark) {
            uint256 profit;
            unchecked {
                profit = assets - highWaterMark;
            }
            performanceFee = profit.mulDiv(rate, BPS, Math.Rounding.Floor);
        }
    }

    function calculateEntryFee(
        uint256
    ) external pure returns (uint256 entryFee) {
        entryFee = 0;
    }

    function calculateExitFee(uint256) external pure returns (uint256 exitFee) {
        exitFee = 0;
    }
}
