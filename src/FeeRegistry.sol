// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

uint256 constant MAX_PROTOCOL_RATE = 3000; // 30 %

contract FeeRegistry is Ownable2StepUpgradeable {
    /// @custom:storage-location erc7201:hopper.storage.FeeRegistry
    struct FeeRegistryStorage {
        uint256 protocolRate;
        mapping(address => bool) isCustomRate;
        mapping(address => uint256) customRate;
        address protocolFeeReceiver;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.FeeRegistry")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant feeRegistryStorage =
        0xfae567c932a2d69f96a50330b7967af6689561bf72e1f4ad815fc97800b3f300;

    function initialize(
        address initialOwner,
        address _protocolFeeReceiver
    ) public initializer {
        __Ownable_init(initialOwner);
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        $.protocolFeeReceiver = _protocolFeeReceiver;
    }

    function _getFeeRegistryStorage()
        internal
        pure
        returns (FeeRegistryStorage storage $)
    {
        assembly {
            $.slot := feeRegistryStorage
        }
    }

    function protocolRate(address vault) external view returns (uint256 rate) {
        return _protocolRate(vault);
    }

    function protocolRate() external view returns (uint256 rate) {
        return _protocolRate(msg.sender);
    }

    function _protocolRate(address vault) internal view returns (uint256 rate) {
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        if ($.isCustomRate[vault]) {
            return $.customRate[vault];
        }
        return $.protocolRate;
    }

    function setProtocolRate(uint256 rate) external onlyOwner {
        require(rate <= MAX_PROTOCOL_RATE);
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        $.protocolRate = rate;
    }

    function setCustomRate(address vault, uint256 rate) external onlyOwner {
        require(rate <= MAX_PROTOCOL_RATE);
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        $.customRate[vault] = rate;
        $.isCustomRate[vault] = true;
    }

    function cancelCustomRate(address vault) external onlyOwner {
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        $.isCustomRate[vault] = false;
    }

    function isCustomRate(address vault) external view returns (bool) {
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        return $.isCustomRate[vault];
    }

    function customRate(address vault) external view returns (uint256) {
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        return $.customRate[vault];
    }

    function protocolFeeReceiver() external view returns (address) {
        return _getFeeRegistryStorage().protocolFeeReceiver;
    }
}
