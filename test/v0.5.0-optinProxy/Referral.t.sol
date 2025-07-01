// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestReferral is BaseTest {
    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
    }

    function test_referral() public {
        uint256 userBalance = assetBalance(user1.addr);
        vm.expectEmit(true, true, true, true);
        emit Referral(user2.addr, user1.addr, 1, userBalance);
        requestDeposit(userBalance, user1.addr, user1.addr, user1.addr, user2.addr);
    }
}
