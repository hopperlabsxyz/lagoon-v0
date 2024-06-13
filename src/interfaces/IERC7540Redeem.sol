//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

interface IERC7540Redeem {
    event RedeemRequest(
        address indexed controller,
        address indexed owner,
        uint256 indexed requestId,
        address sender,
        uint256 shares
    );

    function requestRedeem(
        uint256 shares,
        address operator,
        address owner
    ) external returns (uint256 requestId);

    function pendingRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 shares);

    function claimableRedeemRequest(
        uint256 requestId,
        address controller
    ) external view returns (uint256 shares);
}
