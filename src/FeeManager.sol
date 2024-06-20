// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {IERC7540} from "./interfaces/IERC7540.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract FeeManager is Initializable {

    address public manager;
    uint256 public managementFeeRate;
    uint256 public performanceFeeRate;
    uint256 public lastFeeTime;
    uint256 public highWaterMark;
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant BPS_DIVIDER = 10_000;

    function initialize(uint256 _highWaterMark, uint256 _managementFeeRate, uint256 _performanceFeeRate) public {
        manager = msg.sender;
        managementFeeRate = _managementFeeRate;
        performanceFeeRate = _performanceFeeRate;
        lastFeeTime = block.timestamp;
        highWaterMark = _highWaterMark;
    }

    function calculateManagementFee(uint256 totalAssets) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastFeeTime;
        uint256 annualFee = (totalAssets * managementFeeRate) / BPS_DIVIDER;
        return (annualFee * timeElapsed) / ONE_YEAR;
    }

    function calculatePerformanceFee(uint256 totalAssets) internal view returns (uint256) {
        if (totalAssets > highWaterMark) {
            uint256 profit = totalAssets - highWaterMark;
            return (profit * performanceFeeRate) / BPS_DIVIDER;
        }
        return 0;
    }

    function collectFees() external virtual;
}

