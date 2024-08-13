// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {NotWhitelisted} from "@src/Whitelistable.sol";
import {BaseTest} from "./Base.sol";

contract TestWhitelist is BaseTest {
    function withWhitelistSetUp() public {
        whitelistInit.push(user5.addr);
        setUpVault(0, 0, 0);
        for (uint256 i; i < whitelistInit.length; i++) {
            assertTrue(vault.isWhitelisted(whitelistInit[i], ""));
        }
        dealAndApprove(user1.addr);
    }

    function withoutWhitelistSetUp() public {
        whitelistInit.push(user5.addr);
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        for (uint256 i; i < whitelistInit.length; i++) {
            assertFalse(vault.isWhitelisted(whitelistInit[i], ""));
        }
        dealAndApprove(user1.addr);
    }

    function test_whitelistInitListMembersShouldBeWhitelisted_MerkleTree()
        public
    {
        withWhitelistSetUp();
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelisted()
        public
    {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, user1.addr)
        );
        vault.requestDeposit(userBalance, user1.addr, user1.addr);
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelistedandOperatorAndOwnerAre()
        public
    {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, controller)
        );
        vault.requestDeposit(userBalance, controller, owner);
    }

    function test_requestDeposit_WhenControllerWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user2.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        requestDeposit(userBalance, controller, operator, owner);
    }

    function test_deposit_ShouldFailWhenReceiverNotWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        requestDeposit(userBalance, user1.addr);
        settle();
        address controller = user1.addr;
        address operator = user1.addr;
        address receiver = user2.addr;
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, receiver)
        );
        deposit(userBalance, controller, operator, receiver);
    }

    // function test_transfer_ShouldFailWhenReceiverNotWhitelisted() public {
    //     uint256 userBalance = assetBalance(user1.addr);
    //     whitelist(user1.addr);
    //     requestDeposit(userBalance, user1.addr);
    //     settle();
    //     deposit(userBalance, user1.addr);
    //     address receiver = user2.addr;
    //     vm.startPrank(user1.addr);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(NotWhitelisted.selector, receiver)
    //     );
    //     vault.transfer(receiver, userBalance / 2);
    //     vm.stopPrank();
    // }

    function test_transfer_WhenReceiverNotWhitelistedAfterDeactivateOfWhitelisting()
        public
    {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        requestDeposit(userBalance, user1.addr);
        settle();

        deposit(userBalance, user1.addr);
        address receiver = user2.addr;
        vm.prank(vault.whitelistManagerRole());
        vault.deactivateWhitelist();
        vm.assertEq(vault.isWhitelistActivated(), false);
        uint256 shares = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        vault.transfer(receiver, shares);
    }

    function test_transfer_ShouldWorkWhenReceiverWhitelisted() public {
        withWhitelistSetUp();
        uint256 userBalance = assetBalance(user1.addr);
        whitelist(user1.addr);
        requestDeposit(userBalance, user1.addr);
        settle();
        deposit(userBalance, user1.addr);
        uint256 shares = vault.balanceOf(user1.addr);
        address receiver = user2.addr;
        whitelist(user2.addr);
        vm.prank(user1.addr);
        vault.transfer(receiver, shares);
    }

    function test_whitelist() public {
        withWhitelistSetUp();
        whitelist(user1.addr);
        assertEq(vault.isWhitelisted(user1.addr, ""), true);
    }

    function test_whitelistList() public {
        withWhitelistSetUp();
        address[] memory users = new address[](2);
        users[0] = user1.addr;
        users[1] = user2.addr;
        whitelist(users);
        assertEq(vault.isWhitelisted(user1.addr, ""), true);
    }

    function test_unwhitelistList() public {
        withWhitelistSetUp();
        address[] memory users = new address[](2);
        users[0] = user1.addr;
        users[1] = user2.addr;
        whitelist(users);
        assertEq(vault.isWhitelisted(user1.addr, ""), true);
        unwhitelist(users[0]);
        assertEq(vault.isWhitelisted(user1.addr, ""), false);
        unwhitelist(users[1]);
        assertEq(vault.isWhitelisted(user2.addr, ""), false);
    }

    function test_noWhitelist() public {
        withoutWhitelistSetUp();
        requestDeposit(1, user1.addr);
    }
}
