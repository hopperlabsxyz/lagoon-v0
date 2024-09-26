// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title FeeRegistry
/// @notice The FeeRegistry contract manages protocol fee rates for various vaults.
/// It allows the contract owner (the protocol) to set a default protocol fee rate, define custom fee rates
/// for specific vaults, and manage the address that receives these protocol fees.
/// Protocol fees represents a fraction (which is the rate) of the fees taken by the asset manager of the vault
contract FeeRegistry is Ownable2StepUpgradeable {
    struct CustomRate {
        bool isActivated;
        uint16 rate;
    }

    /// @custom:storage-location erc7201:hopper.storage.FeeRegistry
    struct FeeRegistryStorage {
        uint256 protocolRate;
        address protocolFeeReceiver;
        mapping(address => CustomRate) customRate;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.FeeRegistry")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant feeRegistryStorage = 0xfae567c932a2d69f96a50330b7967af6689561bf72e1f4ad815fc97800b3f300;

    /// @notice Initializes the owner and protocol fee receiver.
    /// @param initialOwner The contract protocol address.
    /// @param _protocolFeeReceiver The protocol fee receiver.
    function initialize(address initialOwner, address _protocolFeeReceiver) public initializer {
        __Ownable_init(initialOwner);
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        $.protocolFeeReceiver = _protocolFeeReceiver;
    }

    function _getFeeRegistryStorage() internal pure returns (FeeRegistryStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := feeRegistryStorage
        }
    }

    /// @notice Updates the address of the protocol fee receiver.
    /// @param _protocolFeeReceiver The new protocol fee receiver address.
    function updateProtocolFeeReceiver(address _protocolFeeReceiver) external onlyOwner {
        _getFeeRegistryStorage().protocolFeeReceiver = _protocolFeeReceiver;
    }

    /// @notice Sets the protocol fee rate.
    /// @param rate The new protocol fee rate.
    function setProtocolRate(uint256 rate) external onlyOwner {
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        $.protocolRate = rate;
    }

    /// @notice Sets a custom fee rate for a specific vault.
    /// @param vault The address of the vault.
    /// @param rate The custom fee rate for the vault.
    function setCustomRate(address vault, uint16 rate, bool isActivated) external onlyOwner {
        _getFeeRegistryStorage().customRate[vault] = CustomRate({isActivated: isActivated, rate: rate});
    }

    /// @notice Checks if a custom fee rate is set for a specific vault.
    /// @param vault The address of the vault.
    /// @return True if the vault has a custom fee rate, false otherwise.
    function isCustomRate(address vault) external view returns (bool) {
        return _getFeeRegistryStorage().customRate[vault].isActivated;
    }

    /// @notice Returns the address of the protocol fee receiver.
    /// @return The protocol fee receiver address.
    function protocolFeeReceiver() external view returns (address) {
        return _getFeeRegistryStorage().protocolFeeReceiver;
    }

    /// @notice Returns the protocol fee rate for a specific vault,
    /// representing the percentage of the fees taken by the asset manager.
    /// @param vault The address of the vault.
    /// @return rate The protocol fee rate for the vault.
    function protocolRate(address vault) external view returns (uint256 rate) {
        return _protocolRate(vault);
    }

    /// @return rate The protocol fee rate for the caller,
    /// representing the percentage of the fees taken by the asset manager.
    function protocolRate() external view returns (uint256 rate) {
        return _protocolRate(msg.sender);
    }

    /// @notice Calculates the protocol fee rate for a specific vault.
    /// @param vault The address of the vault.
    /// @return rate The protocol fee rate for the vault, considering custom rates.
    function _protocolRate(address vault) internal view returns (uint256 rate) {
        FeeRegistryStorage storage $ = _getFeeRegistryStorage();
        if ($.customRate[vault].isActivated) {
            return uint256($.customRate[vault].rate);
        }
        return $.protocolRate;
    }
}
