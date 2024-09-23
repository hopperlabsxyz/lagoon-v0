//SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {IERC7540} from "./IERC7540.sol";

interface IERC7540Redeem is IERC7540 {
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address sender, uint256 shares
    );

    function requestRedeem(uint256 shares, address operator, address owner) external returns (uint256 requestId);

    function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);

    function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 shares);
}
