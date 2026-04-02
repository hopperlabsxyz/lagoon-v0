// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC7540} from "./IERC7540.sol";

/// @title IERC7540Deposit - Asynchronous deposit interface for ERC-7540 vaults
/// @notice Defines the async deposit request/claim flow
interface IERC7540Deposit is IERC7540 {
    /// @notice Emitted when a deposit request is created
    /// @param controller The address that controls this request
    /// @param owner The address that locked assets in the vault
    /// @param requestId The unique identifier for this deposit request
    /// @param sender The caller of requestDeposit (may differ from owner)
    /// @param assets The amount of assets deposited
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );

    /// @notice Submits a request to deposit assets into the vault
    /// @param assets The amount of assets to deposit
    /// @param controller The address that will control this request
    /// @param owner The address providing the assets
    /// @return requestId The unique identifier for this deposit request
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external payable returns (uint256 requestId);

    /// @notice Claims shares from a settled deposit request
    /// @param assets The amount of assets to claim shares for
    /// @param receiver The address that will receive the shares
    /// @param controller The address that controls the deposit request
    /// @return shares The amount of shares minted
    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external returns (uint256 shares);

    /// @notice Claims a specific amount of shares from a settled deposit request
    /// @param shares The amount of shares to mint
    /// @param receiver The address that will receive the shares
    /// @param controller The address that controls the deposit request
    /// @return assets The amount of assets consumed
    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) external returns (uint256 assets);

    /// @notice Returns the amount of assets pending in a deposit request that has not yet been settled
    /// @param requestId The unique identifier for the deposit request
    /// @param controller The address that controls the deposit request
    /// @return assets The amount of pending assets
    function pendingDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 assets);

    /// @notice Returns the amount of assets in a deposit request that are claimable after settlement
    /// @param requestId The unique identifier for the deposit request
    /// @param controller The address that controls the deposit request
    /// @return assets The amount of claimable assets
    function claimableDepositRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 assets);
}
