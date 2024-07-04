// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

contract TestWhitelist is BaseTest {
    function setUp() public {
        dealAndApprove(user1.addr);
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelisted()
        public
    {
        uint256 userBalance = assetBalance(user1.addr);
        vm.expectRevert();
        requestDeposit(userBalance, user1.addr);
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelistedandOperatorAndOwnerAre()
        public
    {
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        vm.expectRevert();
        requestDeposit(userBalance, controller, operator, owner);
    }

    function test_requestDeposit_WhenControllerWhitelisted() public {
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user2.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        requestDeposit(userBalance, controller, operator, owner);
    }

    function test_deposit_ShouldFailWhenReceiverNotWhitelisted() public {
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        requestDeposit(userBalance, user1.addr);
        settle();
        address controller = user1.addr;
        address operator = user1.addr;
        address receiver = user2.addr;
        vm.expectRevert();
        deposit(userBalance, controller, operator, receiver);
    }
}
