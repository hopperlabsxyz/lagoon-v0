// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFeeModule} from "./interfaces/IFeeModule.sol";
import {FeeLibrary} from "./libraries/FeeLibrary.sol";

uint256 constant ONE_YEAR = 365 days;
uint256 constant BPS_DIVIDER = 10_000;
uint256 constant MAX_MANAGEMENT_FEES = 500; // 5%
uint256 constant MAX_PERFORMANCE_FEES = 5000; // 50%
uint256 constant MAX_PROTOCOL_FEES = 3000; // 30%
uint256 constant COOLDOWN = 1 days;

error AboveMaxFee();

contract FeeManager is Initializable {
    using Math for uint256;
    using FeeLibrary for uint256;

    /// @custom:storage-location erc7201:hopper.storage.FeeManager
    struct FeeManagerStorage {
        uint256 managementRate;
        uint256 performanceRate;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        IFeeModule registry;
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
        address _registry,
        uint256 _managementRate,
        uint256 _performanceRate
    ) internal onlyInitializing {
        if (
            _managementRate.isAboveMaxManagementRate() ||
            _performanceRate.isAboveMaxPerformanceRate()
        ) revert AboveMaxFee();

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.registry = IFeeModule(_registry);
        $.highWaterMark = 0;

        $.managementRate = _managementRate;
        $.performanceRate = _performanceRate;

        $.lastFeeTime = block.timestamp;
    }

    function managementFee() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.managementRate;
    }

    function performanceFee() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.performanceRate;
    }

    function protocolFee() external returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.registry.protocolRate();
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

    function _calculateFees(
        uint256 newTotalAssets,
        uint256 totalSupply
    ) internal returns (uint256 managerShares, uint256 protocolShares) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 managementFees = newTotalAssets.calculateManagementFee(
            block.timestamp - $.lastFeeTime,
            $.managementRate
        );

        uint256 performanceFees = (newTotalAssets - managementFees)
            .calculatePerformanceFee($.highWaterMark, $.performanceRate);

        uint256 _totalFees = managementFees + performanceFees;

        uint256 _totalFeeShares = _totalFees.mulDiv(
            totalSupply + 1,
            newTotalAssets - _totalFees + 1,
            Math.Rounding.Floor
        );

        (managerShares, protocolShares) = _totalFeeShares.calculateProtocolFee(
            $.registry.protocolRate()
        );

        $.lastFeeTime = block.timestamp;
    }
}
