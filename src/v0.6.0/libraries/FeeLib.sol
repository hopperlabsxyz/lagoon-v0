// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {FeeManager} from "../FeeManager.sol";
import {Roles} from "../Roles.sol";
import {ERC7540Lib} from "../libraries/ERC7540Lib.sol";
import {FeeType} from "../primitives/Enums.sol";
import {AboveMaxRate, HighWaterMarkResetNotAllowed, RateCanOnlyDecrease} from "../primitives/Errors.sol";
import {FeeTaken, HighWaterMarkUpdated, RatesUpdated} from "../primitives/Events.sol";
import {Rates} from "../primitives/Struct.sol";
import {RolesLib} from "./RolesLib.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library FeeLib {
    using Math for uint256;

    uint256 constant ONE_YEAR = 365 days;
    uint256 constant BPS_DIVIDER = 10_000; // 100 %

    uint16 constant MAX_MANAGEMENT_RATE = 1000; // 10 %
    uint16 constant MAX_PERFORMANCE_RATE = 5000; // 50 %
    uint16 constant MAX_ENTRY_RATE = 200; // 2 %
    uint16 constant MAX_EXIT_RATE = 200; // 2 %
    uint16 constant MAX_PROTOCOL_RATE = 3000; // 30 %
    uint16 constant MAX_HAIRCUT_RATE = 2000; // 20 %

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

    /// @notice Calculates the management fee for a given period
    /// @param assets The total assets under management
    /// @param annualRate The annual management rate, expressed in BPS
    /// @param timeElapsed The time elapsed since the last fee calculation in seconds
    /// @return managementFee The management fee expressed in assets
    function calculateManagementFee(
        uint256 assets,
        uint256 annualRate,
        uint256 timeElapsed
    ) public pure returns (uint256 managementFee) {
        uint256 annualFee = assets.mulDiv(annualRate, BPS_DIVIDER, Math.Rounding.Ceil);
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR, Math.Rounding.Ceil);
    }

    /// @notice Calculates the performance fee based on profit above the high water mark
    /// @param _rate The performance rate, expressed in BPS
    /// @param _totalSupply The total supply of shares
    /// @param _pricePerShare The current price per share
    /// @param _highWaterMark The highest price per share ever reached
    /// @param _decimals The number of decimals of the shares
    /// @return performanceFee The performance fee expressed in assets
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

    /// @notice Computes the fee for a given amount and rate
    /// @param amount The amount to compute the fee for
    /// @param rate The rate to compute the fee for, expressed in BPS
    /// @return The fee, expressed in the same unit as the amount
    function computeFee(
        uint256 amount,
        uint256 rate
    ) public pure returns (uint256) {
        if (rate == 0) return 0;
        return amount.mulDiv(rate, BPS_DIVIDER, Math.Rounding.Ceil);
    }

    /// @notice Computes the fee amount from a net (post-fee) amount, reversing the fee deduction
    /// @param amount The net amount (after fee deduction) to compute the gross fee for
    /// @param rate The rate to compute the fee for, expressed in BPS
    /// @return The fee, expressed in the same unit as the amount
    function computeFeeReverse(
        uint256 amount,
        uint256 rate
    ) public pure returns (uint256) {
        if (rate == 0) return 0;
        return amount.mulDiv(BPS_DIVIDER, (BPS_DIVIDER - rate), Math.Rounding.Ceil) - amount;
    }

    /// @notice Updates the high water mark only if the new value is greater than the current one
    /// @dev The high water mark is the highest price per share ever reached
    /// @param _newHighWaterMark The candidate new high water mark value
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

    /// @notice Resets the high water mark to the current price per share
    /// @dev Can only be called if allowHighWaterMarkReset was set to true at initialization
    function resetHighWaterMark() public {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        // Check if reset is allowed
        if (!$.allowHighWaterMarkReset) {
            revert HighWaterMarkResetNotAllowed();
        }

        // Get current price per share
        uint256 _decimals = ERC7540(address(this)).decimals();
        uint256 currentPricePerShare = ERC7540(address(this)).convertToAssets(10 ** _decimals);

        // Reset high water mark to current price per share
        uint256 _highWaterMark = $.highWaterMark;
        emit HighWaterMarkUpdated(_highWaterMark, currentPricePerShare);
        $.highWaterMark = currentPricePerShare;
    }

    /// @notice Take the fees by minting the manager and protocol shares
    /// @param shares the amount of fee shares to distribute
    /// @param feeType the type of fee
    /// @param rate the fee rate applied
    /// @param contextId the settleId for settlement fees (0 if not relevant)
    function takeFees(
        uint256 shares,
        FeeType feeType,
        uint16 rate,
        uint40 contextId
    ) public {
        if (shares == 0) return;

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
        emit FeeTaken(feeType, shares, rate, contextId, managerShares, protocolShares);
    }

    /// @dev Calculate and return the manager and protocol shares to be minted as fees
    /// @dev total fees are the sum of the management and performance fees
    /// @dev manager shares are the fees that go to the manager, it is the difference between the total fees and the
    /// protocol fees
    /// @dev protocol shares are the fees that go to the protocol
    /// @param contextId the settleId for settlement fees (0 if not relevant)
    /// @param _previousTotalAssets the previous total assets of the vault
    function takeManagementAndPerformanceFees(
        uint40 contextId,
        uint256 _previousTotalAssets
    ) public {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint16 managementRate = feeRates().managementRate;
        uint16 performanceRate = feeRates().performanceRate;
        uint256 _decimals = ERC7540(address(this)).decimals();
        uint256 _totalAssets = ERC7540(address(this)).totalAssets();
        /// Management fee computation ///
        uint256 managementFees = calculateManagementFee(
            (_totalAssets + _previousTotalAssets) / 2, managementRate, block.timestamp - $.lastFeeTime
        );

        // by taking management fees the price per share decreases
        uint256 pricePerShare = (10 ** _decimals)
        .mulDiv(
            _totalAssets + 1 - managementFees,
            ERC7540(address(this)).totalSupply() + 10 ** ERC7540Lib.decimalsOffset(),
            Math.Rounding.Ceil
        );

        /// Performance fee computation ///

        uint256 performanceFees = calculatePerformanceFee(
            performanceRate, ERC7540(address(this)).totalSupply(), pricePerShare, $.highWaterMark, _decimals
        );

        // since we are minting shares without actually increasing the totalAssets, we need to compensate the future
        // dilution of price per share by virtually decreasing totalAssets in our computation
        uint256 managementShares = managementFees.mulDiv(
            ERC7540(address(this)).totalSupply() + 10 ** ERC7540Lib.decimalsOffset(),
            (_totalAssets - (managementFees + performanceFees)) + 1,
            Math.Rounding.Ceil
        );

        uint256 performanceShares = performanceFees.mulDiv(
            ERC7540(address(this)).totalSupply() + 10 ** ERC7540Lib.decimalsOffset(),
            (_totalAssets - (managementFees + performanceFees)) + 1,
            Math.Rounding.Ceil
        );

        takeFees(managementShares, FeeType.Management, managementRate, contextId);
        takeFees(performanceShares, FeeType.Performance, performanceRate, contextId);
        pricePerShare = ERC7540(address(this)).convertToAssets(10 ** _decimals);
        setHighWaterMark(pricePerShare);

        $.lastFeeTime = block.timestamp;
    }

    /// @notice Updates the fee rates, applied immediately
    /// @dev Entry and exit fee rates can only decrease after initial configuration
    /// @param $ The fee manager storage reference
    /// @param newRates The new fee rates to apply
    /// @param isFirstInitialization True if this is the first rate configuration (allows increasing entry/exit rates)
    function updateRates(
        FeeManager.FeeManagerStorage storage $,
        Rates memory newRates,
        bool isFirstInitialization
    ) public {
        Rates memory currentRates = $.rates;

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
        if (newRates.haircutRate > MAX_HAIRCUT_RATE) {
            revert AboveMaxRate(MAX_HAIRCUT_RATE);
        }

        // After initialization, entry and exit fee rates can only go down.
        if (!isFirstInitialization) {
            if (newRates.entryRate > currentRates.entryRate) {
                revert RateCanOnlyDecrease(currentRates.entryRate, newRates.entryRate, FeeType.Entry);
            }
            if (newRates.exitRate > currentRates.exitRate) {
                revert RateCanOnlyDecrease(currentRates.exitRate, newRates.exitRate, FeeType.Exit);
            }
        }

        $.rates = newRates;
        emit RatesUpdated(currentRates, newRates, block.timestamp);
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

    /// @notice Returns the current fee rates
    /// @return The current Rates struct containing all fee rates
    function feeRates() public view returns (Rates memory) {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        return $.rates;
    }
}
