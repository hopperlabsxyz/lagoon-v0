// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {FeeRegistry} from "./FeeRegistry.sol";

error OnlySafe();
error OnlyWhitelistManager();
error OnlyTotalAssetsManager();

contract RolesUpgradeable is Ownable2StepUpgradeable {
    /// @notice Stores the various roles responsible of managing the vault.
    /// @param whitelistManager The address responsible of managing the whitelist.
    /// @param feeReceiver The address that will receive the fees generated.
    /// @param safe Every lagoon vault is associated with a Safe smart contract. This address will receive the assets of the vault and can settle deposits and redeems.
    /// @param feeRegistry The address of the FeeRegistry contract.
    /// @param totalAssetsManager. This address is responsible of updating the totalAssets value of the vault.
    /// @param owner The address of the owner of the contract. Not visible in the struct.
    struct RolesStorage {
        address whitelistManager;
        address feeReceiver;
        address safe;
        address feeRegistry;
        address totalAssetsManager;
    }

    function __Roles_init(RolesStorage memory roles) internal onlyInitializing {
        RolesStorage storage $ = _getRolesStorage();
        $.whitelistManager = roles.whitelistManager;
        $.feeReceiver = roles.feeReceiver;
        $.safe = roles.safe;
        $.feeRegistry = roles.feeRegistry;
        $.totalAssetsManager = roles.totalAssetsManager;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Roles")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant rolesStorage =
        0x7c302ed2c673c3d6b4551cf74a01ee649f887e14fd20d13dbca1b6099534d900;

    function _getRolesStorage() internal pure returns (RolesStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := rolesStorage
        }
    }

    modifier onlySafe() {
        if (_getRolesStorage().safe != _msgSender()) revert OnlySafe();
        _;
    }

    modifier onlyWhitelistManager() {
        if (_getRolesStorage().whitelistManager != _msgSender())
            revert OnlyWhitelistManager();
        _;
    }

    modifier onlyTotalAssetsManager() {
        if (_getRolesStorage().totalAssetsManager != _msgSender())
            revert OnlyTotalAssetsManager();
        _;
    }

    function whitelistManager() public view returns (address) {
        return _getRolesStorage().whitelistManager;
    }

    function feeReceiver() public view returns (address) {
        return _getRolesStorage().feeReceiver;
    }

    function protocolFeeReceiver() public view returns (address) {
        return
            FeeRegistry(_getRolesStorage().feeRegistry).protocolFeeReceiver();
    }

    function safe() public view returns (address) {
        return _getRolesStorage().safe;
    }

    function totalAssetsManager() public view returns (address) {
        return _getRolesStorage().totalAssetsManager;
    }

    function feeRegistry() public view returns (address) {
        return _getRolesStorage().feeRegistry;
    }

    function updateWhitelistManager(
        address _whitelistManager
    ) external onlyOwner {
        _getRolesStorage().whitelistManager = _whitelistManager;
    }

    function updateTotalAssetsManager(
        address _totalAssetsManager
    ) external onlyOwner {
        _getRolesStorage().totalAssetsManager = _totalAssetsManager;
    }

    function updateFeeReceiver(address _feeReceiver) external onlyOwner {
        _getRolesStorage().feeReceiver = _feeReceiver;
    }
}
