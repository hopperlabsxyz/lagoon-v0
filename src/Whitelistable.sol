// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {IWhitelistModule} from "./interfaces/IWhitelistModule.sol";

bytes32 constant WHITELISTED = keccak256("WHITELISTED");

error NotWhitelisted(address account);

contract Whitelistable is AccessControlEnumerableUpgradeable {
    /// @custom:storage-location erc7201:hopper.storage.Whitelistable
    struct WhitelistableStorage {
        address whitelistModule;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Whitelistable")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant whitelistableStorage =
        0x083cc98ab296d1a1f01854b5f7a2f47df4425a56ba7b35f7faa3a336067e4800;

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
        address whitelistModule
    ) internal onlyInitializing {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.whitelistModule = whitelistModule;
        __AccessControlEnumerable_init();
    }

    function isWhitelistActivated() public view returns (bool) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        return $.whitelistModule != address(0);
    }

    function deactivateWhitelist() public onlyRole(DEFAULT_ADMIN_ROLE) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.whitelistModule = address(0);
    }

    modifier onlyWhitelisted(address account, bytes memory data) {
        if (isWhitelistActivated() == true && !isWhitelisted(account, data)) {
            revert NotWhitelisted(account);
        }
        _;
    }

    function isWhitelisted(
        address account,
        bytes memory data
    ) public view returns (bool) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        return IWhitelistModule($.whitelistModule).isWhitelisted(account, data);
    }
}
