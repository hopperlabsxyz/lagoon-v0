// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

contract TestMint is BaseTest {
    function setUp() public {
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_mint() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 claimableAssets = vault.claimableDepositRequest(0, user1.addr);
        uint256 assetsClaimed = mint(12, user1.addr);
        assertEq(12, vault.balanceOf(user1.addr));
        uint256 claimableAssetsAfter = vault.claimableDepositRequest(
            0,
            user1.addr
        );
        assertEq(claimableAssetsAfter + assetsClaimed, claimableAssets);
        assertLt(claimableAssetsAfter, claimableAssets);
    }

    function test_mintAsOperator() public {
        uint256 userBalance = assetBalance(user1.addr);

        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 claimableAssets = vault.claimableDepositRequest(0, user1.addr);
        uint256 assetsClaimed = mint(12, user1.addr, user2.addr, user1.addr);
        assertEq(12, vault.balanceOf(user1.addr));
        uint256 claimableAssetsAfter = vault.claimableDepositRequest(
            0,
            user1.addr
        );
        assertEq(claimableAssetsAfter + assetsClaimed, claimableAssets);
        assertLt(claimableAssetsAfter, claimableAssets);
    }
}
