// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {FeeRegistry} from "./FeeRegistry.sol";

error OnlySafe();
error OnlyWhitelistManager();
error OnlyTotalAssetsManager();

/// @title RolesUpgradeable
/// @dev This contract is used to define the various roles needed for a vault to operate.
/// @dev It also defines the modifiers used to check functions' caller.
contract RolesUpgradeable is Ownable2StepUpgradeable {
    /// @notice Stores the various roles responsible of managing the vault.
    /// @param whitelistManager The address responsible of managing the whitelist.
    /// @param feeReceiver The address that will receive the fees generated.
    /// @param safe Every lagoon vault is admitted to be associated with a (gnosis) Safe smart wallet. This address will receive the assets of the vault and can call settle functions.
    /// @param feeRegistry The address of the FeeRegistry contract. It can't be changed.
    /// @param totalAssetsManager. This address is responsible of updating the newtotalAssets value of the vault.
    /// @param owner The address of the owner of the contract. It considered as the admin.It is not visible in the struct. It can change the others roles and itself. Initiate the fund closing. Disable the whitelist.
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

    /// @dev Returns the storage struct of the roles.
    function _getRolesStorage() internal pure returns (RolesStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := rolesStorage
        }
    }

    /// @dev Modifier to check if the caller is the safe.
    modifier onlySafe() {
        if (_getRolesStorage().safe != _msgSender()) revert OnlySafe();
        _;
    }

    /// @dev Modifier to check if the caller is the whitelist manager.
    modifier onlyWhitelistManager() {
        if (_getRolesStorage().whitelistManager != _msgSender())
            revert OnlyWhitelistManager();
        _;
    }

    /// @dev Modifier to check if the caller is the total assets manager.
    modifier onlyTotalAssetsManager() {
        if (_getRolesStorage().totalAssetsManager != _msgSender())
            revert OnlyTotalAssetsManager();
        _;
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
        return
            FeeRegistry(_getRolesStorage().feeRegistry).protocolFeeReceiver();
    }

    /// @notice Returns the address of the safe associated with the vault.
    function safe() public view returns (address) {
        return _getRolesStorage().safe;
    }

    /// @notice Returns the address of the total assets manager.
    function totalAssetsManager() public view returns (address) {
        return _getRolesStorage().totalAssetsManager;
    }

    /// @notice Returns the address of the fee registry.
    function feeRegistry() public view returns (address) {
        return _getRolesStorage().feeRegistry;
    }

    /// @notice Updates the address of the whitelist manager.
    /// @param _whitelistManager The new address of the whitelist manager.
    /// @dev Only the owner can call this function.
    function updateWhitelistManager(
        address _whitelistManager
    ) external onlyOwner {
        _getRolesStorage().whitelistManager = _whitelistManager;
    }

    /// @notice Updates the address of the total assets manager.
    /// @param _totalAssetsManager The new address of the total assets manager.
    /// @dev Only the owner can call this function.
    function updateTotalAssetsManager(
        address _totalAssetsManager
    ) external onlyOwner {
        _getRolesStorage().totalAssetsManager = _totalAssetsManager;
    }

    /// @notice Updates the address of the fee receiver.
    /// @param _feeReceiver The new address of the fee receiver.
    /// @dev Only the owner can call this function.
    function updateFeeReceiver(address _feeReceiver) external onlyOwner {
        _getRolesStorage().feeReceiver = _feeReceiver;
    }
}
