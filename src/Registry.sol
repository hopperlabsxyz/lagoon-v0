// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Registry is Ownable {
    uint256 public constant MAX_PROTOCOL_RATE = 100; // 1 %

    uint256 internal _protocolRate;

    mapping(address => bool) internal isCustomRate;
    mapping(address => uint256) internal customRate;

    constructor(address _owner) Ownable(_owner) {}

    function protocolRate() external view returns (uint256 rate) {
        if (isCustomRate[msg.sender]) {
            return customRate[msg.sender];
        }
        return _protocolRate;
    }

    function setProtocolRate(uint256 rate) external onlyOwner {
        require(rate <= MAX_PROTOCOL_RATE);
        _protocolRate = rate;
    }

    function setCustomRate(address vault, uint256 rate) external onlyOwner {
        require(rate <= MAX_PROTOCOL_RATE);
        customRate[vault] = rate;
        isCustomRate[vault] = true;
    }
}
