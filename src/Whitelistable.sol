// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Roles} from "./Roles.sol";

bytes32 constant WHITELISTED = keccak256("WHITELISTED");

error NotWhitelisted(address account);

contract Whitelistable is Roles {
    /// @custom:storage-location erc7201:hopper.storage.Whitelistable
    struct WhitelistableStorage {
        bool activated;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Whitelistable")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant whitelistableStorage =
        0x083cc98ab296d1a1f01854b5f7a2f47df4425a56ba7b35f7faa3a336067e4800; //todo compute proper storage slot

    function _getWhitelistableStorage()
        internal
        pure
        returns (WhitelistableStorage storage $)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := whitelistableStorage
        }
    }

    function __Whitelistable_init(
        bool _activateWhitelist
    ) internal onlyInitializing {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.activated = _activateWhitelist;
        // __AccessControlEnumerable_init();
    }

    function getWhitelistActivated() public view returns (bool) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        return $.activated;
    }

    function deactivateWhitelist() public onlyOwner {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.activated = false;
    }

    modifier onlyWhitelisted(address account) {
        if (getWhitelistActivated() == true && !isWhitelisted(account)) {
            revert NotWhitelisted(account);
        }
        _;
    }

    /*
     * @notice Add or remove an account from the whitelist
     * @dev acces is restricted to the admin role via modifier onlyRole(getRoleAdmin(role))
     * in the grantRole function
     **/
    function whitelist(address account) public {
        grantRole(WHITELISTED, account);
    }

    /*
     * @notice Add multiple accounts to the whitelist
     * @dev acces is restricted to the admin role via modifier onlyRole(getRoleAdmin(role))
     * in the grantRole function
     **/
    function whitelist(address[] memory accounts) public {
        for (uint256 i = 0; i < accounts.length; i++) {
            grantRole(WHITELISTED, accounts[i]);
        }
    }

    /*
     * @notice Remove an account from the whitelist
     * @dev acces is restricted to the admin role via modifier onlyRole(getRoleAdmin(role))
     * in the revokeRole function
     **/
    function revokeWhitelist(address account) public {
        revokeRole(WHITELISTED, account);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return hasRole(WHITELISTED, account);
    }
}
