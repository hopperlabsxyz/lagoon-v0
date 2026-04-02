// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC7540} from "./IERC7540.sol";

/// @title IERC7540Redeem - Asynchronous redeem interface for ERC-7540 vaults
/// @notice Defines the async redeem request/claim flow
interface IERC7540Redeem is IERC7540 {
    /// @notice Emitted when a redeem request is created
    /// @param controller The address that controls this request
    /// @param owner The address that locked shares for redemption
    /// @param requestId The unique identifier for this redeem request
    /// @param sender The caller of requestRedeem (may differ from owner)
    /// @param shares The amount of shares submitted for redemption
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );

    /// @notice Submits a request to redeem shares from the vault
    /// @param shares The amount of shares to redeem
    /// @param controller The address that will control this request
    /// @param owner The address providing the shares
    /// @return requestId The unique identifier for this redeem request
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) external returns (uint256 requestId);

    /// @notice Returns the amount of shares pending in a redeem request that has not yet been settled
    /// @param requestId The unique identifier for the redeem request
    /// @param controller The address that controls the redeem request
    /// @return shares The amount of pending shares
    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 shares);

    /// @notice Returns the amount of shares in a redeem request that are claimable after settlement
    /// @param requestId The unique identifier for the redeem request
    /// @param controller The address that controls the redeem request
    /// @return shares The amount of claimable shares
    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 shares);
}
