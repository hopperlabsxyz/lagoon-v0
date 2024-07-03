// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

struct FeeDetails {
    uint256 currentFee;
    uint256 updatedFee;
    uint256 lastUpdate;
}

struct FeeManagerStorage {
    FeeDetails managementFee;
    FeeDetails protocolFee;
    FeeDetails performanceFee;
    uint256 lastFeeTime;
    uint256 highWaterMark;
}

struct FeeSchema {
    uint256 managementFee;
    uint256 performanceFee;
    uint256 protocolFee;
}

uint256 constant ONE_YEAR = 365 days;
uint256 constant BPS_DIVIDER = 10_000;
uint256 constant MAX_MANAGEMENT_FEES = 500; // 5%
uint256 constant MAX_PERFORMANCE_FEES = 5000; // 50%
uint256 constant MAX_PROTOCOL_FEES = 3000; // 30%
uint256 constant COOLDOWN = 1 days;

contract FeeManager is Initializable {
    using Math for uint256;

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
        FeeSchema calldata feeSchema
    ) internal onlyInitializing {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.highWaterMark = 0;
        $.managementFee.currentFee = feeSchema.managementFee >
            MAX_MANAGEMENT_FEES
            ? MAX_MANAGEMENT_FEES
            : feeSchema.managementFee;
        $.performanceFee.currentFee = feeSchema.performanceFee >
            MAX_PERFORMANCE_FEES
            ? MAX_PERFORMANCE_FEES
            : feeSchema.performanceFee;
        $.protocolFee.currentFee = feeSchema.protocolFee > MAX_PROTOCOL_FEES
            ? MAX_PROTOCOL_FEES
            : feeSchema.protocolFee;
        $.lastFeeTime = block.timestamp;
    }

    function managementFee() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.managementFee.currentFee;
    }

    function performanceFee() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.performanceFee.currentFee;
    }

    function protocolFee() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.protocolFee.currentFee;
    }

    function lastFeeTime() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.lastFeeTime;
    }

    function highWaterMark() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.highWaterMark;
    }

    function calculateManagementFee(
        uint256 _AUM
    ) public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 timeElapsed;
        unchecked {
            timeElapsed = block.timestamp - $.lastFeeTime;
        }
        uint256 annualFee = _AUM.mulDiv(
            $.managementFee.currentFee,
            BPS_DIVIDER,
            Math.Rounding.Floor
        );
        return annualFee.mulDiv(timeElapsed, ONE_YEAR);
    }

    function calculatePerformanceFee(
        uint256 _AUM
    ) public view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        uint256 hwm = $.highWaterMark;
        if (_AUM > hwm) {
            uint256 profit;
            unchecked {
                profit = _AUM - hwm;
            }
            return
                profit.mulDiv(
                    $.performanceFee.currentFee,
                    BPS_DIVIDER,
                    Math.Rounding.Floor
                );
        }
        return 0;
    }

    function calculateProtocolFee(
        uint256 _totalFeeShares
    ) public view returns (uint256 managerFees, uint256 protocolFees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        if ($.protocolFee.currentFee > 0) {
            protocolFees = _totalFeeShares.mulDiv(
                $.protocolFee.currentFee,
                BPS_DIVIDER,
                Math.Rounding.Floor
            );
            managerFees = _totalFeeShares - protocolFees;
        } else {
            protocolFees = 0;
            managerFees = _totalFeeShares;
        }
    }

    function setProtocolFee() public virtual {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        require(block.timestamp >= $.protocolFee.lastUpdate + COOLDOWN);
        $.protocolFee.currentFee = $.protocolFee.updatedFee;
    }

    function setManagementFee() public virtual {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        require(block.timestamp >= $.managementFee.lastUpdate + COOLDOWN);
        $.managementFee.currentFee = $.managementFee.updatedFee;
    }

    function setPerformanceFee() public virtual {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        require(block.timestamp >= $.performanceFee.lastUpdate + COOLDOWN);
        $.performanceFee.currentFee = $.performanceFee.updatedFee;
    }

    function updateProtocolFee(uint256 _protocolFee) public virtual {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        $.protocolFee.updatedFee = _protocolFee > MAX_PROTOCOL_FEES
            ? MAX_PROTOCOL_FEES
            : _protocolFee;
        $.protocolFee.lastUpdate = block.timestamp;
    }

    function updateManagementFee(uint256 _managementFee) public virtual {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        $.managementFee.updatedFee = _managementFee > MAX_MANAGEMENT_FEES
            ? MAX_MANAGEMENT_FEES
            : _managementFee;
        $.managementFee.lastUpdate = block.timestamp;
    }

    function updatePerformanceFee(uint256 _performanceFee) public virtual {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        $.performanceFee.updatedFee = _performanceFee > MAX_PERFORMANCE_FEES
            ? MAX_PERFORMANCE_FEES
            : _performanceFee;
        $.performanceFee.lastUpdate = block.timestamp;
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

        uint256 _managementFees = calculateManagementFee(newTotalAssets);
        uint256 _performanceFees = calculatePerformanceFee(
            newTotalAssets - _managementFees
        );

        uint256 _totalFees = _managementFees + _performanceFees;

        uint256 _netAUM = newTotalAssets - _totalFees;
        uint256 _totalFeeShares;
        if (_netAUM != 0) {
            _totalFeeShares = totalSupply.mulDiv(
                _totalFees,
                _netAUM,
                Math.Rounding.Floor
            );
        }

        (managerShares, protocolShares) = calculateProtocolFee(_totalFeeShares);

        $.lastFeeTime = block.timestamp;
    }
}
