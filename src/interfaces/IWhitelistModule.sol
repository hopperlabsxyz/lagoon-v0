// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

interface IWhitelistModule {
    function isWhitelisted(address account) external view returns (bool);
}
