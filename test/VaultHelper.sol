// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import {Vault} from "../src/Vault.sol";

contract VaultHelper is Vault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(bool disable) Vault(disable) {
        if (disable) _disableInitializers();
    }

    function totalSupplyDeposit(uint256 epochId) public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[epochId].totalSupplyDeposit;
    }

    function previousEpochTotalSupplyDeposit() public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[$.epochId - 1].totalSupplyDeposit;
    }

    function totalSupplyRedeem(uint256 epochId) public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[epochId].totalSupplyRedeem;
    }

    function previousEpochTotalSupplyRedeem() public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[$.epochId - 1].totalSupplyRedeem;
    }

    function totalAssetsDeposit(uint256 epochId) public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[epochId].totalAssetsDeposit;
    }

    function previousEpochTotalAssetsDeposit() public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[$.epochId - 1].totalAssetsDeposit;
    }

    function totalAssetsRedeem(uint256 epochId) public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[epochId].totalAssetsRedeem;
    }

    function previousEpochTotalAssetsRedeem() public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.epochs[$.epochId - 1].totalAssetsRedeem;
    }
}
