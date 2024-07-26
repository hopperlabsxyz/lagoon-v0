// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

interface IFeeModule {
    function bps() external view returns (uint256 bps);

    function exitRate() external view returns (uint256 exitRate);

    function entryRate() external view returns (uint256 entryRate);

    function managementRate() external view returns (uint256 managementRate);

    function performanceRate() external view returns (uint256 performanceRate);

    function calculateFee(
        uint256 assets,
        uint256 startTimestamp,
        uint256 highWaterMark
    ) external view returns (uint256 fee);

    function calculateEntryFee(
        uint256 assets
    ) external view returns (uint256 fee);

    function calculateExitFee(
        uint256 assets
    ) external view returns (uint256 fee);
}
