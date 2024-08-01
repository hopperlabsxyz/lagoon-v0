// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";

contract TestCancelRequest is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        requestDeposit(user1Assets / 2, user1.addr);

        updateAndSettle(0);
        deposit(user1Assets / 2, user1.addr);
    }

    function test_cancelRequestDeposit() public {
        uint256 assetsBeforeRequest = assetBalance(user1.addr);
        requestDeposit(assetsBeforeRequest / 2, user1.addr);
        uint256 assetsBeforeCancel = assetBalance(user1.addr);
        vm.prank(user1.addr);
        vault.cancelRequestDeposit();
        uint256 assetsAfterCancel = assetBalance(user1.addr);
        assertLt(assetsBeforeCancel, assetsAfterCancel);
        assertEq(assetsAfterCancel, assetsBeforeRequest);
    }

    function test_cancelRequestDeposit_when0PendingRequest() public {
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.cancelRequestDeposit();
        vm.stopPrank();
    }

    function test_cancelRequestRedeem() public {
        uint256 sharesBeforeRequest = vault.balanceOf(user1.addr);
        requestRedeem(sharesBeforeRequest, user1.addr);
        uint256 sharesBeforeCancel = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        vault.cancelRequestRedeem();
        uint256 sharesAfterCancel = vault.balanceOf(user1.addr);
        assertLt(sharesBeforeCancel, sharesAfterCancel);
        assertEq(sharesAfterCancel, sharesBeforeRequest);
    }

    function test_cancelRequestRedeem_when0PendingRequest() public {
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.cancelRequestRedeem();
        vm.stopPrank();
    }
}
