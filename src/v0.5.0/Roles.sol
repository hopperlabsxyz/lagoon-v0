// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {OnlySafe, OnlyValuationManager, OnlyWhitelistManager} from "./primitives/Errors.sol";
import {FeeReceiverUpdated, ValuationManagerUpdated, WhitelistManagerUpdated} from "./primitives/Events.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";

/// @title RolesUpgradeable
/// @dev This contract is used to define the various roles needed for a vault to operate.
/// @dev It also defines the modifiers used to check functions' caller.
abstract contract Roles is Ownable2StepUpgradeable {
    /// @notice Stores the various roles responsible of managing the vault.
    /// @param whitelistManager The address responsible of managing the whitelist.
    /// @param feeReceiver The address that will receive the fees generated.
    /// @param safe Every lagoon vault is associated with a Safe smart contract. This address will receive the assets of
    /// the vault and can settle deposits and redeems.
    /// @param feeRegistry The address of the FeeRegistry contract.
    /// @param valuationManager. This address is responsible of updating the newTotalAssets value of the vault.
    /// @param owner The address of the owner of the contract. It considered as the admin. It is not visible in the
    /// struct. It can change the others roles and itself. Initiate the fund closing. Disable the whitelist.
    struct RolesStorage {
        address whitelistManager;
        address feeReceiver;
        address safe;
        FeeRegistry feeRegistry;
        address valuationManager;
    }

    /// @dev Initializes the roles of the vault.
    /// @param roles The roles to be initialized.
    // solhint-disable-next-line func-name-mixedcase
    function __Roles_init(
        RolesStorage memory roles
    ) internal onlyInitializing {
        RolesStorage storage $ = _getRolesStorage();

        $.whitelistManager = roles.whitelistManager;
        $.feeReceiver = roles.feeReceiver;
        $.safe = roles.safe;
        $.feeRegistry = FeeRegistry(roles.feeRegistry);
        $.valuationManager = roles.valuationManager;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Roles")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:storage-location erc7201:hopper.storage.Roles
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant rolesStorage = 0x7c302ed2c673c3d6b4551cf74a01ee649f887e14fd20d13dbca1b6099534d900;

    /// @dev Returns the storage struct of the roles.
    /// @return _rolesStorage The storage struct of the roles.
    function _getRolesStorage() internal pure returns (RolesStorage storage _rolesStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _rolesStorage.slot := rolesStorage
        }
    }

    /// @dev Returns the storage struct of the roles.
    /// @return _rolesStorage The storage struct of the roles.
    function getRolesStorage() public pure returns (RolesStorage memory _rolesStorage) {
        _rolesStorage = _getRolesStorage();
    }

    /// @dev Modifier to check if the caller is the safe.
    modifier onlySafe() {
        address _safe = _getRolesStorage().safe;
        if (_safe != msg.sender) revert OnlySafe(_safe);
        _;
    }

    /// @dev Modifier to check if the caller is the whitelist manager.
    modifier onlyWhitelistManager() {
        address _whitelistManager = _getRolesStorage().whitelistManager;
        if (_whitelistManager != msg.sender) {
            revert OnlyWhitelistManager(_whitelistManager);
        }
        _;
    }

    /// @dev Modifier to check if the caller is the valuation manager.
    modifier onlyValuationManager() {
        address _valuationManager = _getRolesStorage().valuationManager;
        if (_valuationManager != msg.sender) {
            revert OnlyValuationManager(_valuationManager);
        }
        _;
    }

    /// @notice Updates the address of the whitelist manager.
    /// @param _whitelistManager The new address of the whitelist manager.
    /// @dev Only the owner can call this function.
    function updateWhitelistManager(
        address _whitelistManager
    ) external onlyOwner {
        emit WhitelistManagerUpdated(_getRolesStorage().whitelistManager, _whitelistManager);
        _getRolesStorage().whitelistManager = _whitelistManager;
    }

    /// @notice Updates the address of the valuation manager.
    /// @param _valuationManager The new address of the valuation manager.
    /// @dev Only the owner can call this function.
    function updateValuationManager(
        address _valuationManager
    ) external onlyOwner {
        emit ValuationManagerUpdated(_getRolesStorage().valuationManager, _valuationManager);
        _getRolesStorage().valuationManager = _valuationManager;
    }

    /// @notice Updates the address of the fee receiver.
    /// @param _feeReceiver The new address of the fee receiver.
    /// @dev Only the owner can call this function.
    function updateFeeReceiver(
        address _feeReceiver
    ) external onlyOwner {
        emit FeeReceiverUpdated(_getRolesStorage().feeReceiver, _feeReceiver);
        _getRolesStorage().feeReceiver = _feeReceiver;
    }
}
