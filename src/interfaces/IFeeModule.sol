// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

interface IFeeModule {
    function protocolRate() external returns (uint256);

    function setProtocolRate(uint256 rate) external;
}
