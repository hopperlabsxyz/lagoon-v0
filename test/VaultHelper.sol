// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import "../src/Vault.sol";
import "../src/ERC7540.sol";

contract VaultHelper is Vault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(bool disable) Vault(disable) {
        if (disable) _disableInitializers();
    }

    function totalSupplyDeposit(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].totalSupplyDeposit;
    }

    function previousEpochTotalSupplyDeposit() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[$.epochId - 1].totalSupplyDeposit;
    }

    function totalSupplyRedeem(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].totalSupplyRedeem;
    }

    function previousEpochTotalSupplyRedeem() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[$.epochId - 1].totalSupplyRedeem;
    }

    function totalAssetsDeposit(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].totalAssetsDeposit;
    }

    function previousEpochTotalAssetsDeposit() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[$.epochId - 1].totalAssetsDeposit;
    }

    function totalAssetsRedeem(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].totalAssetsRedeem;
    }

    function previousEpochTotalAssetsRedeem() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[$.epochId - 1].totalAssetsRedeem;
    }

    function vaultHopper() public view returns (address) {
        return getRoleMember(HOPPER_ROLE, 0);
    }

    function vaultAdmin() public view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    function vaultAM() public view returns (address) {
        return getRoleMember(ASSET_MANAGER_ROLE, 0);
    }

    function vaultValorizationRole() public view returns (address) {
        return getRoleMember(VALORIZATION_ROLE, 0);
    }

    function toUnwind() public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.toUnwind;
    }

    function underlyingDecimals() public view returns(uint256) {
      IERC20Metadata asset = IERC20Metadata(asset());
      return asset.decimals();
    }
}
