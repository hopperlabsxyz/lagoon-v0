// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {NotWhitelisted} from "@src/Whitelistable.sol";
import {Referral} from "@src/Vault.sol";
import {BaseTest} from "./Base.sol";

contract TestReferral is BaseTest {
    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
    }

    function test_referral() public {
        uint256 userBalance = assetBalance(user1.addr);
        vm.expectEmit(true, true, true, true);
        emit Referral(user2.addr, 1, userBalance);
        requestDeposit(
            userBalance,
            user1.addr,
            abi.encode(new bytes32[](0), user2.addr)
        );
    }
}
