//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

interface IERC7540Deposit {
    /**
     * owner has locked assets in the Vault to Request a deposit with request ID requestId.
     * controller controls this Request.
     * sender is the caller of the requestDeposit
     * which may not be equal to the owner
     * */
    event DepositRequest(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 assets
    );

    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) external returns (uint256 requestId);

    function pendingDepositRequest(
        address owner
    ) external view returns (uint256 assets);

    function claimableDepositRequest(
        address owner
    ) external view returns (uint256 assets);
}
