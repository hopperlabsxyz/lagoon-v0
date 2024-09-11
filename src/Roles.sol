// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {FeeRegistry} from "./FeeRegistry.sol";

error OnlySafe();
error OnlyWhitelistManager();
error OnlyValorizationManager();

contract RolesUpgradeable is Ownable2StepUpgradeable {
    struct RolesStorage {
        address whitelistManager;
        address feeReceiver;
        address safe;
        address feeRegistry;
        address valorizationManager;
    }

    function __Roles_init(RolesStorage memory roles) internal onlyInitializing {
        RolesStorage storage $ = _getRolesStorage();
        $.whitelistManager = roles.whitelistManager;
        $.feeReceiver = roles.feeReceiver;
        $.safe = roles.safe;
        $.feeRegistry = roles.feeRegistry;
        $.valorizationManager = roles.valorizationManager;
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

    modifier onlyValorizationManager() {
        if (_getRolesStorage().valorizationManager != _msgSender())
            revert OnlyValorizationManager();
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

    function valorizationManager() public view returns (address) {
        return _getRolesStorage().valorizationManager;
    }

    function feeRegistry() public view returns (address) {
        return _getRolesStorage().feeRegistry;
    }

    function updateWhitelistManager(
        address _whitelistManager
    ) external onlyOwner {
        _getRolesStorage().whitelistManager = _whitelistManager;
    }

    function updateFeeReceiver(address _feeReceiver) external onlyOwner {
        _getRolesStorage().feeReceiver = _feeReceiver;
    }
}
