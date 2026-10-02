// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IWETH9} from "./interfaces/IWETH9.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @title Silo
/// @dev This contract is used to hold the assets/shares of the users that
/// requested a deposit/redeem. It is used to simplify the logic of the vault.
contract Silo {
    IWETH9 public wrappedNativeToken;

    constructor(
        IERC20 underlying,
        address _wrappedNativeToken
    ) {
        underlying.forceApprove(msg.sender, type(uint256).max);
        wrappedNativeToken = IWETH9(_wrappedNativeToken);
    }

    function depositEth() external payable {
        IWETH9(wrappedNativeToken).deposit{value: msg.value}();
    }
}
