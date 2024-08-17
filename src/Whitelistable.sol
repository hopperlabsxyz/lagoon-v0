// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IWhitelistModule} from "./interfaces/IWhitelistModule.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// errors
error NotWhitelisted(address account);
error MerkleTreeMode();

// events
event RootUpdated(bytes32 indexed root);
event WhitelistUpdated(address indexed account, bool authorized);

/// @custom:storage-location erc7201:hopper.storage.Whitelistable
struct WhitelistableStorage {
    bytes32 root;
    mapping(address => bool) isWhitelisted;
    bool isActivated;
}

bytes32 constant WHITELIST_MANAGER_ROLE = keccak256("WHITELIST_MANAGER_ROLE");
bytes32 constant WHITELISTED = keccak256("WHITELISTED");

contract Whitelistable is AccessControlEnumerableUpgradeable {

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

    function __Whitelistable_init(bool isActivated) internal onlyInitializing {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.isActivated = isActivated;
        __AccessControlEnumerable_init();
    }

    function getRoot() public view returns(bytes32) {
      return _getWhitelistableStorage().root;
    }

    function isWhitelistActivated() public view returns (bool) {
        return _getWhitelistableStorage().isActivated;
    }

    // @notice Deactivates the whitelist
    function deactivateWhitelist() public onlyRole(WHITELIST_MANAGER_ROLE) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        $.isActivated = false;
    }

    // @notice Checks if an account is whitelisted
    // @param account The address of the account to check
    // @param data The Merkle proof data, required when the root hash is set
    // @return bool True if the account is whitelisted, false otherwise
    function isWhitelisted(
        address account,
        bytes32[] memory proof 
    ) public view returns (bool) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();
        if ($.isActivated == false) {
          return true; 
        }
        if ($.root == 0) {
          return $.isWhitelisted[account];
        }
        bytes32 leaf = keccak256(
          bytes.concat(keccak256(abi.encode(account)))
        );
        return MerkleProof.verify(proof, $.root, leaf);
    }

    // @notice Updates the Merkle tree root hash
    function setRoot(bytes32 root) external onlyRole(WHITELIST_MANAGER_ROLE) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        $.root = root;
        emit RootUpdated(root);
    }

    // @notice Adds an account to the whitelist
    function addToWhitelist(
        address account
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

         require($.root == 0 /*, MerkleTreeMode() */);

        $.isWhitelisted[account] = true;
        emit WhitelistUpdated(account, true);
    }

    // @notice Adds multiple accounts to the whitelist
    function addToWhitelist(
        address[] memory accounts
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        require($.root == 0 /*, MerkleTreeMode() */);

        for (uint256 i = 0; i < accounts.length; i++) {
            $.isWhitelisted[accounts[i]] = true;
            emit WhitelistUpdated(accounts[i], true);
        }
    }

    // @notice Removes an account from the whitelist
    function revokeFromWhitelist(
        address account
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        require($.root == 0 /*, MerkleTreeMode() */);

        $.isWhitelisted[account] = false;
        emit WhitelistUpdated(account, false);
    }

    // @notice Removes multiple accounts from the whitelist
    function revokeFromWhitelist(
        address[] memory accounts
    ) external onlyRole(WHITELIST_MANAGER_ROLE) {
        WhitelistableStorage storage $ = _getWhitelistableStorage();

        require($.root == 0 /*, MerkleTreeMode() */);

        for (uint256 i = 0; i < accounts.length; i++) {
            $.isWhitelisted[accounts[i]] = false;
            emit WhitelistUpdated(accounts[i], false);
        }
    }
}
