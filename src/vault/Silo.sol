//SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @title Silo
/// @dev This contract is used to hold the assets/shares of the users that
/// requested a deposit/redeem. It is used to simplify the logic of the vault.
contract Silo {
    constructor(IERC20 underlying) {
        underlying.forceApprove(msg.sender, type(uint256).max);
    }
}
