// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {IFeeModule} from "./interfaces/IFeeModule.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FeeModule is IFeeModule, Ownable {
    uint256 internal _protocolRate;

    constructor(address _owner) Ownable(_owner) {}

    mapping(address => bool) isDisabled;

    uint256 public constant MAX_PROTOCOL_RATE = 100; // 1 %

    function setProtocolRate(uint256 rate) external {
        require(rate <= MAX_PROTOCOL_RATE);
        _protocolRate = rate;
    }

    function protocolRate() external returns (uint256 rate) {
        if (!isDisabled[msg.sender]) {
            rate = _protocolRate;
        }
    }

    function disableVaultProtocolFee(address vault) external {
        isDisabled[vault] = true;
    }
}
