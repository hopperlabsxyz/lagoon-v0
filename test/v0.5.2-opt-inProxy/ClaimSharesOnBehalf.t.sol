// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestClaimSharesOnBehalf is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);
        dealAndApproveAndWhitelist(user3.addr);
        dealAndApproveAndWhitelist(user4.addr);
        dealAndApproveAndWhitelist(user5.addr);
        dealAndApproveAndWhitelist(user6.addr);
    }

    function test_claimSharesOnBehalf_onlySafe() public {
        address[] memory controllers = new address[](0);
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, vault.safe()));
        vault.claimSharesOnBehalf(controllers);
    }

    function test_claimSharesOnBehalf() public {
        uint256 user1Balance = assetBalance(user1.addr);
        uint256 user1RequestId = requestDeposit(user1Balance, user1.addr);

        uint256 user2Balance = assetBalance(user2.addr);
        uint256 user2RequestId = requestDeposit(user2Balance, user2.addr);

        // First settlement
        updateAndSettle(0);

        uint256 user3Balance = assetBalance(user3.addr);
        uint256 user3RequestId = requestDeposit(user3Balance, user3.addr);

        uint256 user4Balance = assetBalance(user4.addr);
        uint256 user4RequestId = requestDeposit(user4Balance, user4.addr);

        // Seconds settlement
        updateAndSettle(user1Balance + user2Balance);

        uint256 user5Balance = assetBalance(user5.addr);
        uint256 user5RequestId = requestDeposit(user5Balance, user5.addr);

        // Third settlement
        updateAndSettle(user1Balance + user2Balance + user3Balance + user4Balance);

        assertEq(vault.maxDeposit(user1.addr), user1Balance, "wrong maxDeposit on user 1");
        assertEq(vault.maxDeposit(user2.addr), user2Balance, "wrong maxDeposit on user 2");
        assertEq(vault.maxDeposit(user3.addr), user3Balance, "wrong maxDeposit on user 3");
        assertEq(vault.maxDeposit(user4.addr), user4Balance, "wrong maxDeposit on user 4");
        assertEq(vault.maxDeposit(user5.addr), user5Balance, "wrong maxDeposit on user 5");

        address[] memory controllers = new address[](6);

        controllers[0] = user1.addr;
        controllers[1] = user2.addr;
        controllers[2] = user3.addr;
        controllers[3] = user4.addr;
        controllers[4] = user5.addr;
        controllers[5] = user6.addr; // nothing to claim on user 6

        // Claiming all users shares all at once
        vm.prank(safe.addr);
        vault.claimSharesOnBehalf(controllers);

        uint256 user1Shares = vault.convertToShares(user1Balance, user1RequestId);
        assertEq(user1Shares, vault.balanceOf(user1.addr), "user1 balance is wrong");
        assertEq(user1Shares, user1Balance * 10 ** vault.decimalsOffset());

        uint256 user2Shares = vault.convertToShares(user2Balance, user2RequestId);

        assertEq(user2Shares, vault.balanceOf(user2.addr), "user2 balance is wrong");
        assertEq(user2Shares, user2Balance * 10 ** vault.decimalsOffset());

        uint256 user3Shares = vault.convertToShares(user3Balance, user3RequestId);

        assertEq(user3Shares, vault.balanceOf(user3.addr), "user3 balance is wrong");
        assertEq(user3Shares, user3Balance * 10 ** vault.decimalsOffset());

        uint256 user4Shares = vault.convertToShares(user4Balance, user4RequestId);

        assertEq(user4Shares, vault.balanceOf(user4.addr), "user4 balance is wrong");
        assertEq(user4Shares, user4Balance * 10 ** vault.decimalsOffset());

        uint256 user5Shares = vault.convertToShares(user5Balance, user5RequestId);

        assertEq(user5Shares, vault.balanceOf(user5.addr), "user5 balance is wrong");
        assertEq(user5Shares, user5Balance * 10 ** vault.decimalsOffset());

        assertEq(0, vault.balanceOf(user6.addr), "user6 balance is wrong");
    }
}
