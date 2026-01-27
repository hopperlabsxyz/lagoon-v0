// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {FeeManager} from "../FeeManager.sol";
import {Roles} from "../Roles.sol";
import {ERC7540Lib} from "../libraries/ERC7540Lib.sol";
import {FeeType} from "../primitives/Enums.sol";
import {AboveMaxRate} from "../primitives/Errors.sol";
import {FeeTaken, HighWaterMarkUpdated, RatesUpdated} from "../primitives/Events.sol";
import {Rates} from "../primitives/Struct.sol";
import {RolesLib} from "./RolesLib.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library FeeLib {
    using Math for uint256;

    uint256 constant ONE_YEAR = 365 days;
    uint256 constant BPS_DIVIDER = 10_000; // 100 %

    uint16 constant MAX_MANAGEMENT_RATE = 1000; // 10 %
    uint16 constant MAX_PERFORMANCE_RATE = 5000; // 50 %
    uint16 constant MAX_ENTRY_RATE = 1000; // 10 %
    uint16 constant MAX_EXIT_RATE = 1000; // 10 %
    uint16 constant MAX_HAIRCUT_RATE = 1000; // 10 %
    uint16 constant MAX_PROTOCOL_RATE = 3000; // 30 %

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));
    /// @custom:storage-location erc7201:hopper.storage.FeeManager
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant feeManagerStorage = 0xa5292f7ccd85acc1b3080c01f5da9af7799f2c26826bd4d79081d6511780bd00;

    /// @notice Get the storage slot for the FeeManagerStorage struct
    /// @return _feeManagerStorage the storage slot
    function _getFeeManagerStorage() internal pure returns (FeeManager.FeeManagerStorage storage _feeManagerStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _feeManagerStorage.slot := feeManagerStorage
        }
    }

    /// @dev Calculate the management fee
    /// @param assets the total assets under management
    /// @param annualRate the management rate, expressed in BPS and corresponding to the annual
    /// @param timeElapsed the time elapsed since the last fee calculation in seconds
    /// @return managementFee the management fee express in assets
    function calculateManagementFee(
        uint256 assets,
        uint256 annualRate,
        uint256 timeElapsed
    ) public pure returns (uint256 managementFee) {
        uint256 annualFee = assets.mulDiv(annualRate, BPS_DIVIDER, Math.Rounding.Ceil);
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR, Math.Rounding.Ceil);
    }

    /// @dev Calculate the performance fee
    /// @dev The performance is calculated as the difference between the current price per share and the high water mark
    /// @dev The performance fee is calculated as the product of the performance and the performance rate
    /// @param _rate the performance rate, expressed in BPS
    /// @param _totalSupply the total supply of shares
    /// @param _pricePerShare the current price per share
    /// @param _highWaterMark the highest price per share ever reached
    /// @param _decimals the number of decimals of the shares
    /// @return performanceFee the performance fee express in assets
    function calculatePerformanceFee(
        uint256 _rate,
        uint256 _totalSupply,
        uint256 _pricePerShare,
        uint256 _highWaterMark,
        uint256 _decimals
    ) public pure returns (uint256 performanceFee) {
        if (_pricePerShare > _highWaterMark) {
            uint256 profitPerShare;
            unchecked {
                profitPerShare = _pricePerShare - _highWaterMark;
            }
            uint256 profit = profitPerShare.mulDiv(_totalSupply, 10 ** _decimals, Math.Rounding.Ceil);
            performanceFee = profit.mulDiv(_rate, BPS_DIVIDER, Math.Rounding.Ceil);
        }
    }

    /// @dev Compute the fee for a given amount and rate
    /// @param amount The amount to compute the fee for
    /// @param rate The rate to compute the fee for, expressed in BPS
    /// @return fee The fee, expressed in the same unit as the amount
    function computeFee(
        uint256 amount,
        uint256 rate
    ) public pure returns (uint256) {
        if (rate == 0) return 0;
        return amount.mulDiv(rate, BPS_DIVIDER, Math.Rounding.Ceil);
    }

    /// @dev Compute the fee for a given amount and rate
    /// @param amount The amount to compute the fee for
    /// @param rate The rate to compute the fee for, expressed in BPS
    /// @return fee The fee, expressed in the same unit as the amount
    function computeFeeReverse(
        uint256 amount,
        uint256 rate
    ) public pure returns (uint256) {
        if (rate == 0) return 0;
        return amount.mulDiv(BPS_DIVIDER, (BPS_DIVIDER - rate), Math.Rounding.Ceil) - amount;
    }

    /// @dev Update the high water mark only if the new value is greater than the current one
    /// @dev The high water mark is the highest price per share ever reached
    /// @param _newHighWaterMark the new high water mark
    function setHighWaterMark(
        uint256 _newHighWaterMark
    ) public {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 _highWaterMark = $.highWaterMark;

        if (_newHighWaterMark > _highWaterMark) {
            emit HighWaterMarkUpdated(_highWaterMark, _newHighWaterMark);
            $.highWaterMark = _newHighWaterMark;
        }
    }

    /// @notice Take the fees by minting the manager and protocol shares
    /// @param shares the amount of fee shares to distribute
    function takeFees(
        uint256 shares,
        FeeType feeType
    ) public {
        Roles.RolesStorage storage $roles = RolesLib._getRolesStorage();

        address feeReceiver = $roles.feeReceiver;
        address protocolFeeReceiver = $roles.feeRegistry.protocolFeeReceiver();

        // Fee repartition
        uint256 protocolShares = shares.mulDiv(protocolRate(), BPS_DIVIDER, Math.Rounding.Ceil);
        uint256 managerShares = shares - protocolShares;

        if (managerShares > 0) {
            ERC7540(address(this)).forge(feeReceiver, managerShares);
            if (
                protocolShares > 0 // they can't be protocolShares without managerShares
            ) ERC7540(address(this)).forge(protocolFeeReceiver, protocolShares);
        }
        emit FeeTaken(feeType, shares);
    }

    /// @dev Calculate and return the manager and protocol shares to be minted as fees
    /// @dev total fees are the sum of the management and performance fees
    /// @dev manager shares are the fees that go to the manager, it is the difference between the total fees and the
    /// protocol fees
    /// @dev protocol shares are the fees that go to the protocol
    function takeManagementAndPerformanceFees() public {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 _decimals = ERC7540(address(this)).decimals();

        Rates memory _rates = feeRates();

        /// Management fee computation ///

        uint256 timeElapsed = block.timestamp - $.lastFeeTime;
        uint256 _totalAssets = ERC7540(address(this)).totalAssets();
        uint256 managementFees = calculateManagementFee(_totalAssets, _rates.managementRate, timeElapsed);

        // by taking management fees the price per share decreases
        uint256 pricePerShare = (10 ** _decimals)
        .mulDiv(
            _totalAssets + 1 - managementFees,
            ERC7540(address(this)).totalSupply() + 10 ** ERC7540Lib.decimalsOffset(),
            Math.Rounding.Ceil
        );

        /// Performance fee computation ///

        uint256 _totalSupply = ERC7540(address(this)).totalSupply();
        uint256 performanceFees =
            calculatePerformanceFee(_rates.performanceRate, _totalSupply, pricePerShare, $.highWaterMark, _decimals);

        uint256 totalFees = managementFees + performanceFees;

        // since we are minting shares without actually increasing the totalAssets, we need to compensate the future
        // dilution of price per share by virtually decreasing totalAssets in our computation
        uint256 managementShares = managementFees.mulDiv(
            _totalSupply + 10 ** ERC7540Lib.decimalsOffset(), (_totalAssets - totalFees) + 1, Math.Rounding.Ceil
        );

        uint256 performanceShares = performanceFees.mulDiv(
            _totalSupply + 10 ** ERC7540Lib.decimalsOffset(), (_totalAssets - totalFees) + 1, Math.Rounding.Ceil
        );

        takeFees(managementShares, FeeType.Management);
        takeFees(performanceShares, FeeType.Performance);

        pricePerShare = ERC7540(address(this)).convertToAssets(10 ** ERC7540(address(this)).decimals());
        setHighWaterMark(pricePerShare);

        $.lastFeeTime = block.timestamp;
    }

    /// @notice update the fee rates, the new rates will be applied after the cooldown period
    /// @param newRates the new fee rates
    function updateRates(
        FeeManager.FeeManagerStorage storage $,
        Rates memory newRates
    ) public {
        if (newRates.managementRate > MAX_MANAGEMENT_RATE) {
            revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        }
        if (newRates.performanceRate > MAX_PERFORMANCE_RATE) {
            revert AboveMaxRate(MAX_PERFORMANCE_RATE);
        }
        if (newRates.entryRate > MAX_ENTRY_RATE) {
            revert AboveMaxRate(MAX_ENTRY_RATE);
        }
        if (newRates.exitRate > MAX_EXIT_RATE) {
            revert AboveMaxRate(MAX_EXIT_RATE);
        }

        uint256 newRatesTimestamp = block.timestamp + $.cooldown;
        Rates memory currentRates = $.rates;

        $.newRatesTimestamp = newRatesTimestamp;
        $.oldRates = currentRates;
        $.rates = newRates;
        emit RatesUpdated(currentRates, newRates, newRatesTimestamp);
    }

    /// @dev Read the protocol rate from the fee registry
    /// @dev if the value is above the MAX_PROTOCOL_RATE, return the MAX_PROTOCOL_RATE
    /// @return protocolRate the protocol rate
    function protocolRate() public view returns (uint256) {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 _protocolRate = $.feeRegistry.protocolRate();
        if (_protocolRate > MAX_PROTOCOL_RATE) return MAX_PROTOCOL_RATE;
        return _protocolRate;
    }

    /// @dev Since we have a cooldown period and to avoid a double call
    /// to update the feeRates, this function returns a different rate
    /// following the timestamp
    /// @notice the current fee rates
    function feeRates() public view returns (Rates memory) {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        if ($.newRatesTimestamp <= block.timestamp) return $.rates;
        return $.oldRates;
    }
}
