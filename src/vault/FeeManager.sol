// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {AboveMaxRate, CooldownNotOver} from "./Errors.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";
import {ERC7540Upgradeable} from "@src/vault/ERC7540.sol";

uint256 constant ONE_YEAR = 365 days;
uint256 constant BPS_DIVIDER = 10_000; // 100 %

struct Rates {
    uint16 managementRate;
    uint16 performanceRate;
}

abstract contract FeeManager is Ownable2StepUpgradeable, ERC7540Upgradeable {
    using Math for uint256;

    uint16 public constant MAX_MANAGEMENT_RATE = 1000; // 10 %
    uint16 public constant MAX_PERFORMANCE_RATE = 5000; // 50 %
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30 %

    /// @custom:storage-location erc7201:hopper.storage.FeeManager
    /// @param newRatesTimestamp the timestamp at which the new rates will be applied
    /// @param lastFeeTime the timestamp of the last fee calculation, it is used to compute management fees
    /// @param highWaterMark the highest price per share ever reached, performance fees are taken when the price per
    /// share is above this value
    /// @param cooldown the time to wait before applying new rates
    /// @param rates the current fee rates
    /// @param oldRates the previous fee rates, they are used during the cooldown period when new rates are set
    /// @param feeRegistry the fee registry contract, it is used to read the protocol rate
    struct FeeManagerStorage {
        FeeRegistry feeRegistry;
        uint256 newRatesTimestamp;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        uint256 cooldown;
        Rates rates;
        Rates oldRates;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.FeeManager")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant feeManagerStorage = 0xa5292f7ccd85acc1b3080c01f5da9af7799f2c26826bd4d79081d6511780bd00;

    /// @notice Get the storage slot for the FeeManagerStorage struct
    /// @return _feeManagerStorage the storage slot
    function _getFeeManagerStorage() internal pure returns (FeeManagerStorage storage _feeManagerStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _feeManagerStorage.slot := feeManagerStorage
        }
    }

    // solhint-disable-next-line func-name-mixedcase
    /// @notice Initialize the FeeManager contract
    /// @param _registry the address of the fee registry contract
    /// @param _managementRate the management rate, expressed in BPS
    /// @param _performanceRate the performance rate, expressed in BPS
    /// @param _decimals the number of decimals of the shares
    /// @param _cooldown the time to wait before applying new rates
    function __FeeManager_init(
        address _registry,
        uint16 _managementRate,
        uint16 _performanceRate,
        uint256 _decimals,
        uint256 _cooldown
    ) internal onlyInitializing {
        if (_managementRate > MAX_MANAGEMENT_RATE) {
            revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        }
        if (_performanceRate > MAX_PERFORMANCE_RATE) {
            revert AboveMaxRate(MAX_PERFORMANCE_RATE);
        }

        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.newRatesTimestamp = block.timestamp;

        $.cooldown = _cooldown;

        $.feeRegistry = FeeRegistry(_registry);
        $.highWaterMark = 10 ** _decimals;

        $.rates.managementRate = _managementRate;
        $.rates.performanceRate = _performanceRate;

        $.lastFeeTime = block.timestamp;
    }

    /// @notice Take the fees by minting the manager and protocol shares
    /// @param feeReceiver the address that will receive the manager shares
    /// @param protocolFeeReceiver the address that will receive the protocol shares
    function _takeFees(address feeReceiver, address protocolFeeReceiver) internal {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        if ($.lastFeeTime == block.timestamp) return; // this will happen when settleRedeem happens after settleDeposit

        (uint256 managerShares, uint256 protocolShares) = _calculateFees();

        if (managerShares > 0) {
            _mint(feeReceiver, managerShares);
            if (
                protocolShares > 0 // they can't be protocolShares without managerShares
            ) _mint(protocolFeeReceiver, protocolShares);
        }

        uint256 _pricePerShare = _convertToAssets(10 ** decimals(), Math.Rounding.Floor);

        // we update the high water mark only if the new value is greater than the current one
        uint256 _highWaterMark = $.highWaterMark;
        if (_pricePerShare > _highWaterMark) $.highWaterMark = _pricePerShare;

        $.lastFeeTime = block.timestamp;
    }

    /// @notice update the fee rates, the new rates will be applied after the cooldown period
    /// @param newRates the new fee rates
    function updateRates(Rates memory newRates) external onlyOwner {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        if (block.timestamp < $.newRatesTimestamp) {
            revert CooldownNotOver($.newRatesTimestamp - block.timestamp);
        }
        if (newRates.managementRate > MAX_MANAGEMENT_RATE) {
            revert AboveMaxRate(MAX_MANAGEMENT_RATE);
        }
        if (newRates.performanceRate > MAX_PERFORMANCE_RATE) {
            revert AboveMaxRate(MAX_PERFORMANCE_RATE);
        }

        $.newRatesTimestamp = block.timestamp + $.cooldown;
        $.oldRates = $.rates;
        $.rates = newRates;
    }

    /// @dev Since we have a cooldown period and to avoid a double call
    /// to update the feeRates, this function returns a different rate
    /// following the timestamp
    /// @notice the current fee rates
    function feeRates() public view returns (Rates memory) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        if ($.newRatesTimestamp <= block.timestamp) return $.rates;
        return $.oldRates;
    }

    /// @notice the time of the last fee calculation
    function lastFeeTime() public view returns (uint256) {
        return _getFeeManagerStorage().lastFeeTime;
    }

    /// @notice value of the high water mark, the highest price per share ever reached
    function highWaterMark() public view returns (uint256) {
        return _getFeeManagerStorage().highWaterMark;
    }

    /// @dev Update the high water mark only if the new value is greater than the current one
    /// @dev The high water mark is the highest price per share ever reached
    /// @param _newHighWaterMark the new high water mark
    /// @return the new high water mark
    function _setHighWaterMark(uint256 _newHighWaterMark) internal returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 _highWaterMark = $.highWaterMark;

        if (_newHighWaterMark > _highWaterMark) {
            $.highWaterMark = _newHighWaterMark;
            return _newHighWaterMark;
        }

        return _highWaterMark;
    }

    /// @dev Read the protocol rate from the fee registry
    /// @dev if the value is above the MAX_PROTOCOL_RATE, return the MAX_PROTOCOL_RATE
    /// @return protocolRate the protocol rate
    function _protocolRate() internal view returns (uint256 protocolRate) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        protocolRate = $.feeRegistry.protocolRate();
        if (protocolRate > MAX_PROTOCOL_RATE) return MAX_PROTOCOL_RATE;
        return protocolRate;
    }

    /// @dev Calculate and return the manager and protocol shares to be minted as fees
    /// @dev total fees are the sum of the management and performance fees
    /// @dev manager shares are the fees that go to the manager, it is the difference between the total fees and the
    /// protocol fees
    /// @dev protocol shares are the fees that go to the protocol
    /// @return managerShares the manager shares to be minted as fees
    /// @return protocolShares the protocol shares to be minted as fees
    function _calculateFees() internal view returns (uint256 managerShares, uint256 protocolShares) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        Rates memory _rates = feeRates();

        /// Management fee computation ///

        uint256 timeElapsed = block.timestamp - $.lastFeeTime;
        uint256 _totalAssets = totalAssets();
        uint256 managementFees = _calculateManagementFee(_totalAssets, _rates.managementRate, timeElapsed);

        /// Performance fee computation ///

        uint256 _pricePerShare = _convertToAssets(10 ** decimals(), Math.Rounding.Floor);
        uint256 _totalSupply = totalSupply();
        uint256 performanceFees =
            _calculatePerformanceFee(_rates.performanceRate, _totalSupply, _pricePerShare, $.highWaterMark, decimals());

        /// Protocol fee computation & convertion to shares ///

        uint256 totalFees = managementFees + performanceFees;

        uint256 totalShares = totalFees.mulDiv(_totalSupply + 1, (totalAssets() - totalFees) + 1, Math.Rounding.Ceil);

        protocolShares = totalShares.mulDiv(_protocolRate(), BPS_DIVIDER, Math.Rounding.Ceil);
        managerShares = totalShares - protocolShares;
    }

    /// @dev Calculate the management fee
    /// @param assets the total assets under management
    /// @param annualRate the management rate, expressed in BPS and corresponding to the annual
    /// @param timeElapsed the time elapsed since the last fee calculation in seconds
    /// @return managementFee the management fee express in assets
    function _calculateManagementFee(
        uint256 assets,
        uint256 annualRate,
        uint256 timeElapsed
    ) internal pure returns (uint256 managementFee) {
        uint256 annualFee = assets.mulDiv(annualRate, BPS_DIVIDER);
        managementFee = annualFee.mulDiv(timeElapsed, ONE_YEAR);
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
            uint256 profit = profitPerShare.mulDiv(_totalSupply, 10 ** _decimals);
            performanceFee = profit.mulDiv(_rate, BPS_DIVIDER);
        }
    }
}
