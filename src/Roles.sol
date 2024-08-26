// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract Roles is Ownable2StepUpgradeable {
    struct RolesStorage {
        address whitelistManager;
        address feeReceiver;
        address safe;
        address protocolRegistry; // todo use
        address protocolFeeReceiver; // todo get it from protocolFeeReceiver
        address valorizationManager;
    }

    function __Roles_init(RolesStorage memory roles) internal onlyInitializing {
        RolesStorage storage $ = _getRolesStorage();
        $.whitelistManager = roles.whitelistManager;
        $.feeReceiver = roles.feeReceiver;
        $.safe = roles.safe;
        $.protocolRegistry = roles.protocolRegistry;
        $.protocolFeeReceiver = roles.protocolFeeReceiver;
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
        require(_getRolesStorage().safe == _msgSender());
        _;
    }

    modifier onlyWhitelistManager() {
        require(_getRolesStorage().whitelistManager == _msgSender());
        _;
    }

    modifier onlyValorizationManager() {
        require(_getRolesStorage().valorizationManager == _msgSender());
        _;
    }

    function whitelistManager() public view returns (address) {
        return _getRolesStorage().whitelistManager;
    }

    function feeReceiver() public view returns (address) {
        return _getRolesStorage().feeReceiver;
    }

    function protocolFeeReceiver() public view returns (address) {
        return _getRolesStorage().protocolFeeReceiver;
    }

    function safe() public view returns (address) {
        return _getRolesStorage().safe;
    }

    function valorizationManager() public view returns (address) {
        return _getRolesStorage().valorizationManager;
    }

    function protocolRegistry() public view returns (address) {
        return _getRolesStorage().protocolRegistry;
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
