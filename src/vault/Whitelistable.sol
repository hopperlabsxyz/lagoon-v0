// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {NotWhitelisted} from "./Errors.sol";
import {WhitelistUpdated} from "./Events.sol";
import {RolesUpgradeable} from "./Roles.sol";

// import {console} from "forge-std/console.sol";

contract WhitelistableUpgradeable is RolesUpgradeable {
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Whitelistable")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant whitelistableStorage = 0x083cc98ab296d1a1f01854b5f7a2f47df4425a56ba7b35f7faa3a336067e4800;

    /// @custom:storage-location erc7201:hopper.storage.Whitelistable
    struct WhitelistableStorage {
        mapping(address => bool) isWhitelisted;
        bool isActivated;
    }

    function _getWhitelistableStorage() internal pure returns (WhitelistableStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := whitelistableStorage
        }
    }

    // modifier onlyWhitelisted(address account) {
    //     require(isWhitelisted(account), NotWhitelisted);
    //     _;
    // }

    // solhint-disable-next-line func-name-mixedcase
    function __Whitelistable_init(bool isActivated) internal onlyInitializing {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.isActivated = isActivated;
    }

    function isWhitelistActivated() public view returns (bool) {
        return _getWhitelistableStorage().isActivated;
    }

    /// @notice Deactivates the whitelist
    function deactivateWhitelist() public onlyOwner {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.isActivated = false;
    }

    /// @notice Checks if an account is whitelisted
    /// @param account The address of the account to check
    /// @return True if the account is whitelisted, false otherwise
    function isWhitelisted(address account) public view returns (bool) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        return $.isActivated ? $.isWhitelisted[account] : true;
    }

    /// @notice Adds an account to the whitelist
    function addToWhitelist(address account) external onlyWhitelistManager {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        $.isWhitelisted[account] = true;
        emit WhitelistUpdated(account, true);
    }

    /// @notice Adds multiple accounts to the whitelist
    function addToWhitelist(address[] memory accounts) external onlyWhitelistManager {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $.isWhitelisted[accounts[i]] = true;
            emit WhitelistUpdated(accounts[i], true);
        }
    }

    /// @notice Removes an account from the whitelist
    function revokeFromWhitelist(address account) external onlyWhitelistManager {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        $.isWhitelisted[account] = false;
        emit WhitelistUpdated(account, false);
    }

    /// @notice Removes multiple accounts from the whitelist
    function revokeFromWhitelist(address[] memory accounts) external onlyWhitelistManager {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $.isWhitelisted[accounts[i]] = false;
            emit WhitelistUpdated(accounts[i], false);
        }
    }
}
