// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

bytes32 constant WHITELISTED = keccak256("WHITELISTED");

contract Whitelistable is
    ContextUpgradeable,
    AccessControlEnumerableUpgradeable
{
    struct WhitelistableStorage {
        bool activated;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant whitelistableStorage =
        0x9e6b3200a20a991c129f47dddaca04a18eb4bcf2b53906fb44751d827f001400; //todo compute proper storage slot

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

    function __Whitelistable_init(bool activate) internal onlyInitializing {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.activated = activate;
        __AccessControlEnumerable_init();
    }

    function getActivated() public view returns (bool) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        return $.activated;
    }

    modifier onlyWhitelisted(address account) {
        require(
            getActivated() == false || _isWhitelisted(account),
            "Whitelistable: caller is not whitelisted"
        );
        _;
    }

    /*
     * @notice Add or remove an account from the whitelist
     * @dev acces is restricted to the admin role via modifier onlyRole(getRoleAdmin(role))
     * in the grantRole function
     **/
    function addWhitelist(address account) public {
        grantRole(WHITELISTED, account);
    }

    /*
     * @notice Add multiple accounts to the whitelist
     * @dev acces is restricted to the admin role via modifier onlyRole(getRoleAdmin(role))
     * in the grantRole function
     **/
    function addWhitelistBatch(address[] memory accounts) public {
        for (uint256 i = 0; i < accounts.length; i++) {
            grantRole(WHITELISTED, accounts[i]);
        }
    }

    /*
     * @notice Remove an account from the whitelist
     * @dev acces is restricted to the admin role via modifier onlyRole(getRoleAdmin(role))
     * in the revokeRole function
     **/
    function removeWhitelist(address account) public {
        revokeRole(WHITELISTED, account);
    }

    function _isWhitelisted(address account) internal view returns (bool) {
        return hasRole(WHITELISTED, account);
    }
}
