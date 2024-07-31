// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract FeeModule {
    using Math for uint256;

    uint256 public constant ONE_YEAR = 365 days;

    function calculateFee(
        uint256 assets,
        uint256 managementRate,
        uint256 performanceRate,
        uint256 highWaterMark,
        uint256 timeElapsed,
        uint256 bps
    ) public pure returns (uint256 managementFees, uint256 performanceFees) {
        uint256 annualFee = assets.mulDiv(managementRate, bps);
        managementFees = annualFee.mulDiv(timeElapsed, ONE_YEAR);
        assets -= managementFees;
        if (assets > highWaterMark) {
            uint256 profit;
            unchecked {
                profit = assets - highWaterMark;
            }
            performanceFees = profit.mulDiv(performanceRate, bps);
        }
    }
}
