// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {Roles} from "./Roles.sol";
import {WhitelistDisabled, WhitelistUpdated} from "./primitives/Events.sol";

abstract contract Whitelistable is Roles {
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Whitelistable")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:storage-location erc7201:hopper.storage.Whitelistable
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant whitelistableStorage = 0x083cc98ab296d1a1f01854b5f7a2f47df4425a56ba7b35f7faa3a336067e4800;

    /// @custom:storage-definition erc7201:hopper.storage.Whitelistable
    /// @param isWhitelisted The mapping of whitelisted addresses.
    /// @param isActivated The flag to check if the whitelist is activated.
    struct WhitelistableStorage {
        mapping(address => bool) isWhitelisted;
        bool isActivated;
    }

    /// @dev Returns the storage struct of the whitelist.
    /// @return _whitelistableStorage The storage struct of the whitelist.
    function _getWhitelistableStorage() internal pure returns (WhitelistableStorage storage _whitelistableStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _whitelistableStorage.slot := whitelistableStorage
        }
    }

    /// @dev Initializes the whitelist.
    /// @param activate if the whitelist should be activated.
    // solhint-disable-next-line func-name-mixedcase
    function __Whitelistable_init(
        bool activate
    ) internal onlyInitializing {
        if (activate) {
            WhitelistableStorage storage $ = _getWhitelistableStorage();
            $.isActivated = true;
        }
    }

    /// @notice Returns if the whitelist is activated
    /// @return True if the whitelist is activated, false otherwise
    function isWhitelistActivated() public view returns (bool) {
        return _getWhitelistableStorage().isActivated;
    }

    /// @notice Deactivates the whitelist
    function disableWhitelist() public onlyOwner {
        _getWhitelistableStorage().isActivated = false;
        emit WhitelistDisabled();
    }

    /// @notice Checks if an account is whitelisted
    /// @param account The address of the account to check
    /// @return True if the account is whitelisted, false otherwise
    function isWhitelisted(
        address account
    ) public view returns (bool) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        if (_getRolesStorage().feeRegistry.protocolFeeReceiver() == account) {
            return true;
        }
        return $.isActivated ? $.isWhitelisted[account] : true;
    }

    /// @notice Adds multiple accounts to the whitelist
    function addToWhitelist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $.isWhitelisted[accounts[i]] = true;
            emit WhitelistUpdated(accounts[i], true);
        }
    }

    /// @notice Removes multiple accounts from the whitelist
    /// @param accounts The addresses of the accounts to remove
    function revokeFromWhitelist(
        address[] memory accounts
    ) external onlyWhitelistManager {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        uint256 i = 0;
        for (; i < accounts.length;) {
            $.isWhitelisted[accounts[i]] = false;
            emit WhitelistUpdated(accounts[i], false);
            // solhint-disable-next-line no-inline-assembly
            unchecked {
                ++i;
            }
        }
    }
}
