// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

interface IWhitelistModule {
    function isWhitelisted(address account, bytes calldata data) external view returns (bool);
}
