// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import "@src/v0.6.0/ERC7540.sol";
import "@src/v0.6.0/FeeManager.sol";
import "@src/v0.6.0/Roles.sol";
import "@src/v0.6.0/Vault/Vault.sol";
import "@src/v0.6.0/primitives/Errors.sol";
import "@src/v0.6.0/primitives/Events.sol";
import "@src/v0.6.0/primitives/Struct.sol";

contract VaultHelper is Vault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(
        bool disable
    ) Vault(disable) {}

    function totalSupply(
        uint256 epochId
    ) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.settles[$.epochs[uint40(epochId)].settleId].totalSupply;
    }

    function decimalsOffset() public view returns (uint256) {
        return _decimalsOffset();
    }

    // function previousEpochTotalSupply() public view returns (uint256) {
    //     ERC7540Storage storage $ = _getERC7540Storage();
    //     return $.epochs[$.epochId - 1].totalSupply;
    // }

    /// @notice Returns if the whitelist is activated
    /// @return True if the whitelist is activated, false otherwise
    function isWhitelistActivated() public view returns (bool) {
        return _getWhitelistableStorage().isActivated;
    }

    function totalAssets(
        uint256 epochId
    ) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.settles[$.epochs[uint40(epochId)].settleId].totalAssets;
    }

    function newTotalAssets() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.newTotalAssets;
    }

    // function previousEpochTotalAssets() public view returns (uint256) {
    //     ERC7540Storage storage $ = _getERC7540Storage();
    //     return $.epochs[$.epochId - 1].totalAssets;
    // }

    function underlyingDecimals() public view returns (uint256) {
        IERC20Metadata asset = IERC20Metadata(asset());
        return asset.decimals();
    }

    function pricePerShare() public view returns (uint256) {
        return _convertToAssets(1 * 10 ** decimals(), Math.Rounding.Floor);
    }

    function protocolRate() public view returns (uint256) {
        return _protocolRate();
    }

    function lastDepositEpochIdSettled_debug() public view returns (uint256) {
        return _getERC7540Storage().lastDepositEpochIdSettled;
    }

    function lastDepositRequestId_debug(
        address controller
    ) public view returns (uint256) {
        return _getERC7540Storage().lastDepositRequestId[controller];
    }

    // Pending states
    function pendingDeposit() public view returns (uint256) {
        return IERC20(asset()).balanceOf(pendingSilo());
    }

    function pendingRedeem() public view returns (uint256) {
        return balanceOf(pendingSilo());
    }

    /// @notice Returns the state of the vault. It can be Open, Closing, or Closed.
    function state() external view returns (State) {
        return _getVaultStorage().state;
    }

    /// @notice Returns the address of the whitelist manager.
    function whitelistManager() public view returns (address) {
        return _getRolesStorage().whitelistManager;
    }

    /// @notice Returns the address of the fee receiver.
    function feeReceiver() public view returns (address) {
        return _getRolesStorage().feeReceiver;
    }

    // /// @notice Returns the address of protocol fee receiver.
    // function protocolFeeReceiver() public view returns (address) {
    //     return FeeRegistry(_getRolesStorage().feeRegistry).protocolFeeReceiver();
    // }

    /// @notice Returns the address of the valuation manager.
    function valuationManager() public view returns (address) {
        return _getRolesStorage().valuationManager;
    }

    /// @notice Returns the address of the fee registry.
    function feeRegistry() public view returns (address) {
        return address(_getRolesStorage().feeRegistry);
    }

    function redeemSettleId() public view returns (uint256) {
        ERC7540Storage storage $erc7540 = _getERC7540Storage();
        return $erc7540.redeemSettleId;
    }

    function depositSettleId() public view returns (uint256) {
        ERC7540Storage storage $erc7540 = _getERC7540Storage();
        return $erc7540.depositSettleId;
    }

    function epochSettleId(
        uint40 epochId
    ) public view returns (uint40) {
        return _getERC7540Storage().epochs[epochId].settleId;
    }

    function depositEpochId() public view returns (uint40) {
        return _getERC7540Storage().depositEpochId;
    }

    function redeemEpochId() public view returns (uint40) {
        return _getERC7540Storage().redeemEpochId;
    }

    function totalAssetsExpiration() public view returns (uint256) {
        return _getERC7540Storage().totalAssetsExpiration;
    }

    function totalAssetsLifespan() public view returns (uint256) {
        return _getERC7540Storage().totalAssetsLifespan;
    }

    function activateWhitelist() public {
        _getWhitelistableStorage().isActivated = true;
    }

    function protocolFeeReceiver() public view returns (address) {
        return _getRolesStorage().feeRegistry.protocolFeeReceiver();
    }

    function pendingSilo() public view returns (address) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return address($.pendingSilo);
    }

    function lastRedeemRequestId(
        address controller
    ) public view returns (uint40) {
        return _getERC7540Storage().lastRedeemRequestId[controller];
    }

    function lastDepositRequestId(
        address controller
    ) public view returns (uint40) {
        return _getERC7540Storage().lastDepositRequestId[controller];
    }

    /// @notice the time of the last fee calculation
    function lastFeeTime() public view returns (uint256) {
        return _getFeeManagerStorage().lastFeeTime;
    }

    /// @notice value of the high water mark, the highest price per share ever reached
    function highWaterMark() public view returns (uint256) {
        return _getFeeManagerStorage().highWaterMark;
    }
}
