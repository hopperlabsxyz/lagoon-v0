// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {FeeManager} from "../FeeManager.sol";
import {ERC7540Lib} from "../libraries/ERC7540Lib.sol";
import {AboveMaxRate} from "../primitives/Errors.sol";
import {HighWaterMarkUpdated, RatesUpdated} from "../primitives/Events.sol";
import {RatesUpdated} from "../primitives/Events.sol";
import {Rates} from "../primitives/Struct.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library FeeLib {
    using Math for uint256;

    uint256 constant ONE_YEAR = 365 days;
    uint256 constant BPS_DIVIDER = 10_000; // 100 %

    uint16 constant MAX_MANAGEMENT_RATE = 1000; // 10 %
    uint16 constant MAX_PERFORMANCE_RATE = 5000; // 50 %
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
    /// @param feeReceiver the address that will receive the manager shares
    /// @param protocolFeeReceiver the address that will receive the protocol shares
    function takeFees(
        address feeReceiver,
        address protocolFeeReceiver
    ) public {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        (uint256 managerShares, uint256 protocolShares) = calculateFees();

        if (managerShares > 0) {
            ERC7540(address(this)).forge(feeReceiver, managerShares);
            if (
                protocolShares > 0 // they can't be protocolShares without managerShares
            ) ERC7540(address(this)).forge(protocolFeeReceiver, protocolShares);
        }
        uint256 pricePerShare = ERC7540(address(this)).convertToAssets(10 ** ERC7540(address(this)).decimals());
        setHighWaterMark(pricePerShare);

        $.lastFeeTime = block.timestamp;
    }

    /// @dev Calculate and return the manager and protocol shares to be minted as fees
    /// @dev total fees are the sum of the management and performance fees
    /// @dev manager shares are the fees that go to the manager, it is the difference between the total fees and the
    /// protocol fees
    /// @dev protocol shares are the fees that go to the protocol
    /// @return managerShares the manager shares to be minted as fees
    /// @return protocolShares the protocol shares to be minted as fees
    function calculateFees() public view returns (uint256 managerShares, uint256 protocolShares) {
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

        /// Protocol fee computation & convertion to shares ///

        uint256 totalFees = managementFees + performanceFees;

        // since we are minting shares without actually increasing the totalAssets, we need to compensate the future
        // dilution of price per share by virtually decreasing totalAssets in our computation
        uint256 totalShares = totalFees.mulDiv(
            _totalSupply + 10 ** ERC7540Lib.decimalsOffset(), (_totalAssets - totalFees) + 1, Math.Rounding.Ceil
        );

        protocolShares = totalShares.mulDiv(protocolRate(), BPS_DIVIDER, Math.Rounding.Ceil);
        managerShares = totalShares - protocolShares;
    }

    /// @notice update the fee rates, applied immediately
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
        Rates memory currentRates = $.rates;
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

    /// @notice the current fee rates
    function feeRates() public view returns (Rates memory) {
        FeeManager.FeeManagerStorage storage $ = _getFeeManagerStorage();

        return $.rates;
    }
}
