// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IFeeModule} from "./interfaces/IFeeModule.sol";

uint256 constant ONE_YEAR = 365 days;
uint256 constant BPS_DIVIDER = 10_000;
uint256 constant MAX_PROTOCOL_FEES = 3000; // 30%
uint256 constant COOLDOWN = 1 days;

error AboveMaxFee();

contract FeeManager is Initializable {
    using Math for uint256;

    /// @custom:storage-location erc7201:hopper.storage.FeeManager
    struct FeeManagerStorage {
        uint256 protocolFee;
        uint256 lastFeeTime;
        uint256 highWaterMark;
        IFeeModule fee;
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
        address fee,
        uint256 _protocolFee
    ) internal onlyInitializing {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        $.fee = IFeeModule(fee);
        $.highWaterMark = 0;

        if (_protocolFee > MAX_PROTOCOL_FEES) revert AboveMaxFee();
        $.protocolFee = _protocolFee;

        $.lastFeeTime = block.timestamp;
    }

    function protocolFee() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.protocolFee;
    }

    function lastFeeTime() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.lastFeeTime;
    }

    function highWaterMark() external view returns (uint256) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        return $.highWaterMark;
    }

    function setProtocolFee() public virtual {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        $.protocolFee = $.protocolFee;
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

    function calculateProtocolFee(
        uint256 _totalFeeShares
    ) public view returns (uint256 managerFees, uint256 protocolFees) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();
        if ($.protocolFee > 0) {
            protocolFees = _totalFeeShares.mulDiv(
                $.protocolFee,
                BPS_DIVIDER,
                Math.Rounding.Floor
            );
            managerFees = _totalFeeShares - protocolFees;
        } else {
            protocolFees = 0;
            managerFees = _totalFeeShares;
        }
    }

    function _calculateFees(
        uint256 newTotalAssets,
        uint256 totalSupply
    ) internal returns (uint256 managerShares, uint256 protocolShares) {
        FeeManagerStorage storage $ = _getFeeManagerStorage();

        uint256 _totalFees = $.fee.calculateFee(
            newTotalAssets,
            block.timestamp,
            $.highWaterMark
        );
        uint256 _totalFeeShares = _totalFees.mulDiv(
            totalSupply + 1,
            newTotalAssets - _totalFees + 1,
            Math.Rounding.Floor
        );

        (managerShares, protocolShares) = calculateProtocolFee(_totalFeeShares);

        $.lastFeeTime = block.timestamp;
    }
}
