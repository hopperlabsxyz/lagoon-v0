// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {FeeManager} from "../FeeManager.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {FeeType, State} from "../primitives/Enums.sol";
import {
    CantDepositNativeToken,
    Closed,
    ERC7540InvalidOperator,
    NotClosing,
    NotOpen,
    NotWhitelisted,
    OnlyAsyncDepositAllowed,
    OnlySyncDepositAllowed,
    ValuationUpdateNotAllowed
} from "../primitives/Errors.sol";
import {StateUpdated} from "../primitives/Events.sol";
import {VaultStorage} from "../primitives/VaultStorage.sol";
import {VaultStorage} from "../primitives/VaultStorage.sol";
import {ERC7540Lib} from "./ERC7540Lib.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library VaultLib {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:slot erc7201:hopper.storage.vault
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant vaultStorage = 0x0e6b3200a60a991c539f47dddaca04a18eb4bcf2b53906fb44751d827f001400;

    /// @notice Returns the storage struct of the vault.
    /// @return _vaultStorage The storage struct of the vault.
    function _getVaultStorage() internal pure returns (VaultStorage storage _vaultStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _vaultStorage.slot := vaultStorage
        }
    }

    function _onlyOpen() internal view {
        State _state = _getVaultStorage().state;
        if (_state != State.Open) revert NotOpen(_state);
    }

    function _onlyClosing() internal view {
        State _state = _getVaultStorage().state;
        if (_state != State.Closing) revert NotClosing(_state);
    }

    function _onlySyncDeposit() internal view {
        // if total assets is not valid we can only do asynchronous deposit
        if (!isTotalAssetsValid()) {
            revert OnlyAsyncDepositAllowed();
        }
    }

    function _onlyAsyncDeposit() internal view {
        // if total assets is valid we can only do synchronous deposit
        if (isTotalAssetsValid()) {
            revert OnlySyncDepositAllowed();
        }
    }

    function isTotalAssetsValid() public view returns (bool) {
        return block.timestamp < ERC7540Lib._getERC7540Storage().totalAssetsExpiration;
    }

    /// @notice Initiates the closing of the vault. Can only be called by the owner.
    /// @dev we make sure that initiate closing will make an epoch changement if the variable newTotalAssets is
    /// "defined"
    /// @dev (!= type(uint256).max). This guarantee that no userShares will be locked in a pending state.
    function initiateClosing() public {
        ERC7540.ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();
        if ($.newTotalAssets != type(uint256).max) {
            ERC7540Lib.updateNewTotalAssets($.newTotalAssets);
        }
        _getVaultStorage().state = State.Closing;
        emit StateUpdated(State.Closing);
    }

    function close(
        uint256 _newTotalAssets
    ) public {
        ERC7540Lib.updateTotalAssets(_newTotalAssets);
        FeeLib.takeManagementAndPerformanceFees();
        ERC7540Lib.settleDeposit(msg.sender);
        ERC7540Lib.settleRedeem(msg.sender);
        _getVaultStorage().state = State.Closed;

        // we take the exit fees here here
        uint256 _totalAssets = ERC7540Lib._getERC7540Storage().totalAssets;
        uint256 _totalSupply = ERC7540(address(this)).totalSupply();
        uint256 exitFee = _totalAssets.mulDiv(FeeLib.feeRates().exitRate, FeeLib.BPS_DIVIDER, Math.Rounding.Ceil);

        uint256 exitFeeShares = exitFee.mulDiv(
            _totalSupply + 10 ** ERC7540Lib.decimalsOffset(), (_totalAssets - exitFee) + 1, Math.Rounding.Ceil
        );
        FeeLib.takeFees(exitFeeShares, FeeType.Exit);

        // Transfer will fail if there are not enough assets inside the safe, making sure that redeem requests are
        // fulfilled
        IERC20(IERC4626(address(this)).asset()).safeTransferFrom(msg.sender, address(this), _totalAssets);

        emit StateUpdated(State.Closed);
    }
}
