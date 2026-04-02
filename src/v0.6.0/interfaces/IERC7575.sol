// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title IERC7575 - Extended ERC-4626 interface
/// @notice Adds share token address getter to the ERC-4626 vault standard
/// @dev See https://eips.ethereum.org/EIPS/eip-7575
interface IERC7575 is IERC4626 {
    /// @notice Returns the address of the share token
    /// @return The address of the ERC20 share token
    function share() external view returns (address);
}
