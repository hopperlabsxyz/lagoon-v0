// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {IFeeModule} from "./interfaces/IFeeModule.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

uint256 constant ONE_YEAR = 365 days;

contract FeeModule is IFeeModule {
    using Math for uint256;

    uint256 public immutable bps;
    uint256 public immutable exitRate;
    uint256 public immutable entryRate;
    uint256 public immutable managementRate;
    uint256 public immutable performanceRate;

    constructor(
        uint256 _bps,
        uint256 _exitRate,
        uint256 _entryRate,
        uint256 _managementRate,
        uint256 _performanceRate
    ) {
        bps = _bps;
        exitRate = _exitRate;
        entryRate = _entryRate;
        managementRate = _managementRate;
        performanceRate = _performanceRate;
    }

    function _calculateManagementFee(
        uint256 totalAssets,
        uint256 startTimestamp
    ) internal view returns (uint256 managementFee) {
        // throw if timestamp > startTimestamp
        uint256 timeElapsed = block.timestamp - startTimestamp;
        uint256 annualFee = totalAssets.mulDiv(
            managementRate,
            bps,
            Math.Rounding.Floor
        );
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR);
    }

    function _calculatePerformanceFee(
        uint256 totalAssets,
        uint256 highWaterMark
    ) internal view returns (uint256 performanceFee) {
        if (totalAssets > highWaterMark) {
            uint256 profit;
            unchecked {
                profit = totalAssets - highWaterMark;
            }
            performanceFee = profit.mulDiv(
                performanceRate,
                bps,
                Math.Rounding.Floor
            );
        } else {
            performanceFee = 0;
        }
    }

    function calculateFee(
        uint256 assets,
        uint256 startTimestamp,
        uint256 highWaterMark
    ) external view returns (uint256 fee) {
        uint256 managementFees = _calculateManagementFee(
            assets,
            startTimestamp
        );
        uint256 performanceFees = _calculatePerformanceFee(
            assets - managementFees,
            highWaterMark
        );
        return managementFees + performanceFees;
    }

    function calculateEntryFee(uint256) external pure returns (uint256 fee) {
        return 0;
    }

    function calculateExitFee(uint256) external pure returns (uint256 fee) {
        return 0;
    }
}
