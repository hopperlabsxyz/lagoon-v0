// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import "../src/Vault.sol";
import "../src/ERC7540.sol";

contract VaultHelper is Vault {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(bool disable) Vault() {
        if (disable) _disableInitializers();
    }

    function totalSupply(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].totalSupply;
    }

    function previousEpochTotalSupply() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[$.epochId - 1].totalSupply;
    }

    function totalAssets(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].totalAssets;
    }

    function previousEpochTotalAssets() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[$.epochId - 1].totalAssets;
    }

    function underlyingDecimals() public view returns (uint256) {
        IERC20Metadata asset = IERC20Metadata(asset());
        return asset.decimals();
    }

    function toUnwind(uint256 epochId) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].toUnwind;
    }

    function oldestEpochIdUnwinded() public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.oldestEpochIdUnwinded;
    }

    function availableToWithdraw(
        uint256 epochId
    ) public view returns (uint256) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.epochs[epochId].availableToWithdraw;
    }
}
