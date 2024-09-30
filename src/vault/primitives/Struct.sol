// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

struct Rates {
    uint16 managementRate;
    uint16 performanceRate;
}

struct EpochData {
    uint40 settleId;
    mapping(address => uint256) depositRequest;
    mapping(address => uint256) redeemRequest;
}

struct SettleData {
    uint256 totalSupply;
    uint256 totalAssets;
}
