// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import "../src/vault/ERC7540.sol";
import "../src/vault/Vault.sol";

contract VaultHelper is Vault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(bool disable) Vault() {
        if (disable) _disableInitializers();
    }

    function totalSupply(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.settles[$.epochs[uint40(epochId)].settleId].totalSupply;
    }

    // function previousEpochTotalSupply() public view returns (uint256) {
    //     ERC7540Storage storage $ = _getERC7540Storage();
    //     return $.epochs[$.epochId - 1].totalSupply;
    // }

    function totalAssets(uint256 epochId) public view returns (uint256) {
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

    function lastDepositRequestId_debug(address controller) public view returns (uint256) {
        return _getERC7540Storage().lastDepositRequestId[controller];
    }

    // Pending states
    function pendingDeposit() public view returns (uint256) {
        return IERC20(asset()).balanceOf(pendingSilo());
    }

    function pendingRedeem() public view returns (uint256) {
        return balanceOf(pendingSilo());
    }

    function redeemEpochId() public view returns (uint256) {
        return _getERC7540Storage().redeemEpochId;
    }

    function depositEpochId() public view returns (uint256) {
        return _getERC7540Storage().depositEpochId;
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

    /// @notice Returns the address of protocol fee receiver.
    function protocolFeeReceiver() public view returns (address) {
        return FeeRegistry(_getRolesStorage().feeRegistry).protocolFeeReceiver();
    }

    /// @notice Returns the address of the safe associated with the vault.
    function safe() public view returns (address) {
        return _getRolesStorage().safe;
    }

    /// @notice Returns the address of the NAV manager.
    function navManager() public view returns (address) {
        return _getRolesStorage().navManager;
    }

    /// @notice Returns the address of the fee registry.
    function feeRegistry() public view returns (address) {
        return address(_getRolesStorage().feeRegistry);
    }
}
