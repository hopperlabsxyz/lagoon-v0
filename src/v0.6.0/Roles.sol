// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {RolesLib} from "./libraries/RolesLib.sol";
import {
    OnlySafe,
    OnlyValuationManagerOrSecurityCouncil,
    OnlyWhitelistManager,
    SafeUpgradeabilityNotAllowed
} from "./primitives/Errors.sol";
import {
    FeeReceiverUpdated,
    SafeUpdated,
    SafeUpgradeabilityGivenUp,
    ValuationManagerUpdated,
    WhitelistManagerUpdated
} from "./primitives/Events.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {FeeRegistry} from "@src/protocol-v2/FeeRegistry.sol";

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
        address securityCouncil;
    }

    /// @dev Initializes the roles of the vault.
    /// @param roles The roles to be initialized.
    // solhint-disable-next-line func-name-mixedcase
    function __Roles_init(
        RolesStorage memory roles
    ) internal onlyInitializing {
        RolesStorage storage $ = RolesLib._getRolesStorage();

        $.whitelistManager = roles.whitelistManager;
        $.feeReceiver = roles.feeReceiver;
        $.safe = roles.safe;
        $.feeRegistry = roles.feeRegistry;
        $.valuationManager = roles.valuationManager;
        $.securityCouncil = roles.securityCouncil;
    }

    /// @dev Returns the storage struct of the roles.
    /// @return _rolesStorage The storage struct of the roles.
    function getRolesStorage() public pure returns (RolesStorage memory _rolesStorage) {
        _rolesStorage = RolesLib._getRolesStorage();
    }

    /// @dev Modifier to check if the caller is the safe.
    modifier onlySafe() {
        RolesLib._onlySafe();
        _;
    }

    /// @dev Modifier to check if the caller is the whitelist manager.
    modifier onlyWhitelistManager() {
        RolesLib._onlyWhitelistManager();
        _;
    }

    /// @dev Modifier to check if the caller is the valuation manager.
    modifier onlyValuationManagerOrSecurityCouncil() {
        RolesLib._onlyValuationManagerOrSecurityCouncil();
        _;
    }

    /// @dev Modifier to check if the caller is the security council.
    modifier onlySecurityCouncil() {
        RolesLib._onlySecurityCouncil();
        _;
    }

    /// @notice Updates the address of the whitelist manager.
    /// @param _whitelistManager The new address of the whitelist manager.
    /// @dev Only the owner can call this function.
    function updateWhitelistManager(
        address _whitelistManager
    ) external onlyOwner {
        RolesLib.updateWhitelistManager(_whitelistManager);
    }

    /// @notice Updates the address of the valuation manager.
    /// @param _valuationManager The new address of the valuation manager.
    /// @dev Only the owner can call this function.
    function updateValuationManager(
        address _valuationManager
    ) external onlyOwner {
        RolesLib.updateValuationManager(_valuationManager);
    }

    /// @notice Updates the address of the fee receiver.
    /// @param _feeReceiver The new address of the fee receiver.
    /// @dev Only the owner can call this function.
    function updateFeeReceiver(
        address _feeReceiver
    ) external onlyOwner {
        RolesLib.updateFeeReceiver(_feeReceiver);
    }

    /// @notice Updates the address of the safe.
    /// @param _safe The new address of the safe.
    /// @dev Only the owner can call this function.
    function updateSafe(
        address _safe
    ) external onlyOwner {
        RolesLib.updateSafe(_safe);
    }

    /// @notice Updates the address of the security council.
    /// @param _securityCouncil The new address of the security council.
    /// @dev Only the owner can call this function.
    function updateSecurityCouncil(
        address _securityCouncil
    ) external onlyOwner {
        RolesLib.updateSecurityCouncil(_securityCouncil);
    }
}
