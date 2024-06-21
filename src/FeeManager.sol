// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {IERC7540} from "./interfaces/IERC7540.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

struct FeeManagerStorage {
    address manager;
    uint256 managementFee;
    uint256 performanceFee;
    uint256 lastFeeTime;
    uint256 highWaterMark;
}

uint256 constant ONE_YEAR = 365 days;
uint256 constant BPS_DIVIDER = 10_000;

abstract contract FeeManager is Initializable {
  using Math for uint256;

  // keccak256(abi.encode(uint256(keccak256("hopper.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));
  // solhint-disable-next-line const-name-snakecase
  bytes32 private constant feeManagerStorage =
    0xa5292f7ccd85acc1b3080c01f5da9af7799f2c26826bd4d79081d6511780bd00;

    function _getFeeManagerStorage() internal pure returns (FeeManagerStorage storage $) {
      assembly {
        $.slot := feeManagerStorage
      }
    }

    function initialize(uint256 _highWaterMark, uint256 _managementFee, uint256 _performanceFee, address _manager) public {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        $.manager = _manager;
        $.managementFee = _managementFee;
        $.performanceFee = _performanceFee;
        $.lastFeeTime = block.timestamp;
        $.highWaterMark = _highWaterMark;
    }

    function managementFee() external view returns(uint256){
      FeeManagerStorage storage $ = _getFeeManagerStorage();
      return $.managementFee;
    }

    function performanceFee() external view returns(uint256){
      FeeManagerStorage storage $ = _getFeeManagerStorage();
      return $.performanceFee;
    }

    function lastFeeTime() external view returns(uint256){
      FeeManagerStorage storage $ = _getFeeManagerStorage();
      return $.lastFeeTime;
    }

    function highWaterMark() external view returns(uint256){
      FeeManagerStorage storage $ = _getFeeManagerStorage();
      return $.highWaterMark;
    }

    function calculateManagementFee(uint256 totalAssets) internal view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 timeElapsed;
        unchecked {
          timeElapsed = block.timestamp - $.lastFeeTime;
        }
        uint256 annualFee = totalAssets.mulDiv($.managementFee, BPS_DIVIDER, Math.Rounding.Floor);
        return annualFee.mulDiv(timeElapsed, ONE_YEAR);
    }

    function calculatePerformanceFee(uint256 totalAssets) internal view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 hwm = $.highWaterMark;
        if (totalAssets > hwm) {
          uint256 profit;
          unchecked {
            profit = totalAssets - hwm; 
          }
          return profit.mulDiv($.performanceFee, BPS_DIVIDER, Math.Rounding.Floor);
        }
        return 0;
    }

    function collectFees(uint256 newTotalAssets) external virtual;
}

