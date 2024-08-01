// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFeeModule} from "./interfaces/IFeeModule.sol";
import {FeeRegistry} from "./FeeRegistry.sol";

uint256 constant ONE_YEAR = 365 days;
uint256 constant BPS_DIVIDER = 10_000;
uint256 constant MAX_MANAGEMENT_FEES = 500; // 5%
uint256 constant MAX_PERFORMANCE_FEES = 5000; // 50%
uint256 constant MAX_PROTOCOL_FEES = 3000; // 30%
uint256 constant BPS = 10_000; // 100 %
uint256 constant COOLDOWN = 1 days;

error AboveMaxFee();

contract FeeManager is Initializable {
    using Math for uint256;

    uint256 public constant MAX_MANAGEMENT_RATE = 1_000; // 10 %
    uint256 public constant MAX_PERFORMANCE_RATE = 5_000; // 50 %

    /// @custom:storage-location erc7201:hopper.storage.FeeManager
    struct FeeManagerStorage {
        uint256 managementRate;
        uint256 performanceRate;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        FeeRegistry feeRegistry;
        IFeeModule feeModule;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant feeManagerStorage =
        0xa5292f7ccd85acc1b3080c01f5da9af7799f2c26826bd4d79081d6511780bd00;

    function _getFeeManagerStorage()
        internal
        pure
        returns (FeeManagerStorage storage $)
    {
        assembly {
            $.slot := feeManagerStorage
        }
    }

    function __FeeManager_init(
        address _feeModule,
        address _registry,
        uint256 _managementRate,
        uint256 _performanceRate
    ) internal onlyInitializing {
        require(_managementRate < MAX_MANAGEMENT_RATE /*, AboveMaxFee()*/);
        require(_performanceRate < MAX_PERFORMANCE_RATE /*, AboveMaxFee()*/);

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.feeRegistry = FeeRegistry(_registry);
        $.feeModule = IFeeModule(_feeModule);
        $.highWaterMark = 0;

        $.managementRate = _managementRate;
        $.performanceRate = _performanceRate;

        $.lastFeeTime = block.timestamp;
    }

    function managementRate() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.managementRate;
    }

    function performanceRate() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.performanceRate;
    }

    function protocolRate() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.feeRegistry.protocolRate();
    }

    function lastFeeTime() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.lastFeeTime;
    }

    function highWaterMark() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.highWaterMark;
    }

    function _setHighWaterMark(
        uint256 _newHighWaterMark
    ) internal returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 _highWaterMark = $.highWaterMark;

        if (_newHighWaterMark > _highWaterMark) {
            $.highWaterMark = _newHighWaterMark;
            return _newHighWaterMark;
        }

        return _highWaterMark;
    }

    function maxManagementFee(
        uint256 _assets,
        uint256 _timeElapsed
    ) public pure returns (uint256 maxManagementFees) {
        uint256 annualFee = _assets.mulDiv(MAX_MANAGEMENT_RATE, BPS);
        maxManagementFees = annualFee.mulDiv(_timeElapsed, ONE_YEAR);
    }

    function maxPerformanceFee(
        uint256 _assets,
        uint256 _highWaterMark
    ) public pure returns (uint256 maxPerformanceFees) {
        if (_assets > _highWaterMark) {
            uint256 profit;
            unchecked {
                profit = _assets - _highWaterMark;
            }
            maxPerformanceFees = profit.mulDiv(MAX_PERFORMANCE_RATE, BPS);
        }
    }

    function _calculateFees(
        uint256 newTotalAssets,
        uint256 totalSupply
    ) internal view returns (uint256 managerShares, uint256 protocolShares) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        /// Management fee calculation ///

        uint256 timeElapsed = block.timestamp - $.lastFeeTime;
        uint256 maxManagementFees = maxManagementFee(
            newTotalAssets,
            timeElapsed
        );
        uint256 managementFees = $.feeModule.calculateManagementFee(
            newTotalAssets,
            $.managementRate,
            timeElapsed,
            maxManagementFees
        );
        require(managementFees <= maxManagementFees);

        /// Performance fee calculation ///

        uint256 maxPerformanceFees = maxPerformanceFee(
            newTotalAssets,
            $.highWaterMark
        );

        uint256 performanceFees = $.feeModule.calculatePerformanceFee(
            newTotalAssets - managementFees,
            $.performanceRate,
            $.highWaterMark,
            maxPerformanceFees
        );

        require(performanceFees <= maxPerformanceFees);

        /// Protocol fee calculation & convertion to shares ///

        uint256 totalFees = managementFees + performanceFees;

        uint256 totalShares = totalFees.mulDiv(
            totalSupply + 1,
            (newTotalAssets - totalFees) + 1,
            Math.Rounding.Floor
        );

        protocolShares = totalShares.mulDiv($.feeRegistry.protocolRate(), BPS);
        managerShares = totalShares - protocolShares;
    }
}
