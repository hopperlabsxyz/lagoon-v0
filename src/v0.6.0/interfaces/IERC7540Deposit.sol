// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {IERC7540} from "./IERC7540.sol";

interface IERC7540Deposit is IERC7540 {
    /**
     * owner has locked assets in the Vault to Request a deposit with request ID requestId.
     * controller controls this Request.
     * sender is the caller of the requestDeposit
     * which may not be equal to the owner
     *
     */
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 assets
    );

    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external payable returns (uint256 requestId);

    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares);

    function mint(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);

    function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 assets);
}
