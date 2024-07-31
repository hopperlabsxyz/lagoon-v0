// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFeeModule} from "./interfaces/IFeeModule.sol";

contract FeeModule is IFeeModule {
    using Math for uint256;

    uint256 public constant ONE_YEAR = 365 days;

    function calculateManagementFee(
        uint256 assets,
        uint256 rate,
        uint256 bps,
        uint256 timeElapsed,
        uint256 // maxFee
    ) external pure returns (uint256 managementFee) {
        uint256 annualFee = assets.mulDiv(rate, bps);
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR);
    }

    function calculatePerformanceFee(
        uint256 assets,
        uint256 rate,
        uint256 bps,
        uint256 highWaterMark,
        uint256 // maxFee
    ) external pure returns (uint256 performanceFee) {
        if (assets > highWaterMark) {
            uint256 profit;
            unchecked {
                profit = assets - highWaterMark;
            }
            performanceFee = profit.mulDiv(rate, bps);
        }
    }
}
