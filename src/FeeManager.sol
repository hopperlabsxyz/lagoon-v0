// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "./FeeRegistry.sol";
// import {console} from "forge-std/console.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ERC7540Upgradeable} from "@src/ERC7540.sol";
uint256 constant ONE_YEAR = 365 days;
uint256 constant BPS = 10_000; // 100 %

struct Rates {
    uint256 managementRate;
    uint256 performanceRate;
}

error AboveMaxRate(uint256 rate, uint256 maxRate);

abstract contract FeeManager is Ownable2StepUpgradeable, ERC7540Upgradeable {
    using Math for uint256;

    uint256 public constant MAX_MANAGEMENT_RATE = 1_000; // 10 %
    uint256 public constant MAX_PERFORMANCE_RATE = 5_000; // 50 %
    uint256 public constant MAX_PROTOCOL_RATE = 3_000; // 30 %
    uint256 constant COOLDOWN = 1 days;

    /// @custom:storage-location erc7201:hopper.storage.FeeManager
    struct FeeManagerStorage {
        Rates rates;
        Rates oldRates;
        uint256 newRatesTimestamp;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        FeeRegistry feeRegistry;
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
        uint256 _performanceRate,
        uint256 _decimals
    ) internal onlyInitializing {
        if (_managementRate > MAX_MANAGEMENT_RATE)
            // todo change to require form
            revert AboveMaxRate(_managementRate, MAX_MANAGEMENT_RATE);
        if (_performanceRate > MAX_PERFORMANCE_RATE)
            revert AboveMaxRate(_performanceRate, MAX_PERFORMANCE_RATE);

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.feeRegistry = FeeRegistry(_registry);
        $.highWaterMark = 10 ** _decimals;

        $.rates.managementRate = _managementRate;
        $.rates.performanceRate = _performanceRate;

        $.lastFeeTime = block.timestamp;
    }

    function updateRates(Rates memory newRates) external onlyOwner {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        if (newRates.managementRate > MAX_MANAGEMENT_RATE)
            revert AboveMaxRate(newRates.managementRate, MAX_MANAGEMENT_RATE);
        if (newRates.performanceRate > MAX_PERFORMANCE_RATE)
            revert AboveMaxRate(newRates.performanceRate, MAX_PERFORMANCE_RATE);

        $.newRatesTimestamp = block.timestamp + COOLDOWN;
        $.oldRates = $.rates;
        $.rates = newRates;
    }

    function feeRates() public view returns (Rates memory) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        if ($.newRatesTimestamp <= block.timestamp) return $.rates;
        return $.oldRates;
    }

    function lastFeeTime() public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.lastFeeTime;
    }

    function highWaterMark() public view returns (uint256) {
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

    function _protocolRate() internal view returns (uint256 protocolRate) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        protocolRate = $.feeRegistry.protocolRate();
        if (protocolRate > MAX_PROTOCOL_RATE) return MAX_PROTOCOL_RATE;
        return protocolRate;
    }

    function _calculateManagementFee(
        uint256 assets,
        uint256 rate,
        uint256 timeElapsed
    ) internal pure returns (uint256 managementFee) {
        uint256 annualFee = assets.mulDiv(rate, BPS);
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR);
    }

    function _calculatePerformanceFee(
        uint256 _rate,
        uint256 _totalSupply,
        uint256 _pricePerShare,
        uint256 _highWaterMark,
        uint256 _decimals
    ) internal pure returns (uint256 performanceFee) {
        if (_pricePerShare > _highWaterMark) {
            uint256 profitPerShare;
            unchecked {
                profitPerShare = _pricePerShare - _highWaterMark;
            }
            uint256 profit = profitPerShare.mulDiv(
                _totalSupply,
                10 ** _decimals
            );
            performanceFee = profit.mulDiv(_rate, BPS);
        }
    }

    function _calculateFees()
        internal
        view
        returns (uint256 managerShares, uint256 protocolShares)
    {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        Rates memory _rates = feeRates();

        /// Management fee computation ///

        uint256 timeElapsed = block.timestamp - $.lastFeeTime;
        uint256 _totalAssets = totalAssets();
        uint256 managementFees = _calculateManagementFee(
            _totalAssets,
            _rates.managementRate,
            timeElapsed
        );

        /// Performance fee computation ///

        uint256 _pricePerShare = _convertToAssets(
            10 ** decimals(),
            Math.Rounding.Floor
        );
        uint256 _totalSupply = totalSupply();
        uint256 performanceFees = _calculatePerformanceFee(
            _rates.performanceRate,
            _totalSupply,
            _pricePerShare,
            $.highWaterMark,
            decimals()
        );

        /// Protocol fee computation & convertion to shares ///

        uint256 totalFees = managementFees + performanceFees;

        uint256 totalShares = totalFees.mulDiv(
            _totalSupply + 1,
            (totalAssets() - totalFees) + 1,
            Math.Rounding.Ceil
        );

        protocolShares = totalShares.mulDiv(
            _protocolRate(),
            BPS,
            Math.Rounding.Ceil
        );
        managerShares = totalShares - protocolShares;
    }
}
