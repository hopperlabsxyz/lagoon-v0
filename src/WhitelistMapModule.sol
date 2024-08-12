// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {IWhitelistModule} from "./interfaces/IWhitelistModule.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistMapModule is IWhitelistModule, Ownable {
    event AddedToWhitelist(address indexed account);
    event RevokedFromWhitelist(address indexed account);

    mapping(address => bool) internal _isWhitelisted;

    constructor(address owner) Ownable(owner) {}

    /*
     * @notice Add or remove an account from the whitelist
     **/
    function add(address account) external onlyOwner {
        _isWhitelisted[account] = true;
        emit AddedToWhitelist(account);
    }

    /*
     * @notice Add multiple accounts to the whitelist
     **/
    function add(address[] memory accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isWhitelisted[accounts[i]] = true;
            emit AddedToWhitelist(accounts[i]);
        }
    }

    /*
     * @notice Remove an account from the whitelist
     **/
    function revoke(address account) external onlyOwner {
        _isWhitelisted[account] = false;
        emit RevokedFromWhitelist(account);
    }

    /*
     * @notice Revoke multiple accounts from the whitelist
     **/
    function revoke(address[] memory accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isWhitelisted[accounts[i]] = false;
            emit RevokedFromWhitelist(accounts[i]);
        }
    }

    function isWhitelisted(
        address account,
        bytes calldata
    ) external view returns (bool) {
        return _isWhitelisted[account];
    }
}
