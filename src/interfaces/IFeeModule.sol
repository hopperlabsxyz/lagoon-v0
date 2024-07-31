// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

interface IFeeModule {
    function calculateManagementFee(
        uint256 assets,
        uint256 rate,
        uint256 bps,
        uint256 timeElapsed,
        uint256 maxFee
    ) external pure returns (uint256 managementFee);

    function calculatePerformanceFee(
        uint256 assets,
        uint256 rate,
        uint256 bps,
        uint256 highWaterMark,
        uint256 maxFee
    ) external pure returns (uint256 performanceFee);
}
