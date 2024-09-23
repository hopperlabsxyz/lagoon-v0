// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {State} from "./Enums.sol";

/// Vault ///
event Referral(address indexed referral, address indexed owner, uint256 indexed requestId, uint256 assets);

event StateUpdated(State state);

event TotalAssetsUpdated(uint256 totalAssets);

event UpdateTotalAssets(uint256 totalAssets);

/// WhitelistableUpgradeable ///
event RootUpdated(bytes32 indexed root);

event WhitelistUpdated(address indexed account, bool authorized);
