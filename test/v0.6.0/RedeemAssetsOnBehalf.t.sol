// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestRedeemAssetsOnBehalf is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);
        dealAndApproveAndWhitelist(user3.addr);
    }

    function test_RedeemAssetsOnBehalf_onlySafe() public {
        address[] memory controllers = new address[](0);
        vm.expectRevert(abi.encodeWithSelector(OnlySafe.selector, vault.safe()));
        vault.redeemAssetsOnBehalf(controllers);
    }

    function test_RedeemAssetsOnBehalf() public {
        uint256 user1Balance = assetBalance(user1.addr);
        uint256 user1RequestId = requestDeposit(user1Balance, user1.addr);

        uint256 user2Balance = assetBalance(user2.addr);
        uint256 user2RequestId = requestDeposit(user2Balance, user2.addr);

        // First settlement
        updateAndSettle(0);

        vm.startPrank(user1.addr);
        vault.deposit(user1Balance, user1.addr);
        uint256 user1Shares = vault.balanceOf(user1.addr);
        vault.requestRedeem(user1Shares, user1.addr, user1.addr);
        vm.stopPrank();

        vm.startPrank(user2.addr);
        vault.deposit(user2Balance, user2.addr);
        uint256 user2Shares = vault.balanceOf(user1.addr);
        vault.requestRedeem(user2Shares, user2.addr, user2.addr);
        vm.stopPrank();

        // Seconds settlement
        updateAndSettle(user1Balance + user2Balance);

        assertEq(vault.maxRedeem(user1.addr), user1Shares, "wrong maxRedeem on user 1");
        assertEq(vault.maxRedeem(user2.addr), user2Shares, "wrong maxRedeem on user 2");
        assertEq(vault.maxRedeem(user3.addr), 0, "wrong maxRedeem on user 3");

        address[] memory controllers = new address[](6);

        controllers[0] = user1.addr;
        controllers[1] = user2.addr;
        controllers[2] = user3.addr;

        // // Claiming all users shares all at once
        vm.prank(safe.addr);
        vault.redeemAssetsOnBehalf(controllers);

        uint256 user1AssetAfterClaim = vault.convertToAssets(user1Shares, user1RequestId);
        assertEq(user1AssetAfterClaim, underlying.balanceOf(user1.addr), "user1 asset balance is wrong");
        assertEq(vault.maxRedeem(user1.addr), 0, "wrong maxRedeem on user 1");

        uint256 user2AssetAfterClaim = vault.convertToAssets(user2Shares, user2RequestId);
        assertEq(user2AssetAfterClaim, underlying.balanceOf(user2.addr), "user2 asset balance is wrong");
        assertEq(vault.maxRedeem(user2.addr), 0, "wrong maxRedeem on user 2");

        assertEq(vault.maxRedeem(user3.addr), 0, "wrong maxRedeem on user 3");
    }
}
