// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {IWhitelistModule} from "./interfaces/IWhitelistModule.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistMapModule is IWhitelistModule, Ownable {
    mapping(address => bool) public isWhitelisted;

    constructor(address owner) Ownable(owner) {}

    /*
     * @notice Add or remove an account from the whitelist
     **/
    function addToWhitelist(address account) external onlyOwner {
        isWhitelisted[account] = true;
    }

    /*
     * @notice Add multiple accounts to the whitelist
     **/
    function addToWhitelist(address[] memory accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isWhitelisted[accounts[i]] = true;
        }
    }

    /*
     * @notice Remove an account from the whitelist
     **/
    function revokeFromWhitelist(address account) external onlyOwner {
        isWhitelisted[account] = false;
    }

    /*
     * @notice Revoke multiple accounts from the whitelist
     **/
    function revokeFromWhitelist(address[] memory accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isWhitelisted[accounts[i]] = false;
        }
    }
}
