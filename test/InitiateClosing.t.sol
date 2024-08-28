// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, State} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";

contract TestIniateClosing is BaseTest {
    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
        // dealAndApprove(user2.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        // uint256 user2Assets = assetBalance(user2.addr);

        requestDeposit(user1Assets / 2, user1.addr);
        // requestDeposit(user2Assets / 4, user2.addr);

        updateAndSettle(0);

        // User2 has pending redeem request
        // vm.startPrank(user2.addr);
        // vault.deposit(user2Assets / 4, user2.addr);
        // user2 ask for redemption on half of his shares
        // vault.requestRedeem(user1Assets / 8, user2.addr, user2.addr);
        // vm.stopPrank();

        vm.warp(block.timestamp + 30 days);

        assertEq(uint256(vault.state()), uint256(State.Open));

        vm.prank(admin.addr);
        vault.initiateClosing();

        assertEq(uint256(vault.state()), uint256(State.Closing));

        // User1 has claimbale deposit & user2 has claimable redeem
        updateTotalAssets(50_000 * 10 ** vault.underlyingDecimals());

        vm.warp(block.timestamp + 1 days);
    }

    function test_closingVaultMarkTheVaultAsClosed() public {
        vm.prank(safe.addr);
        vault.close();

        assertEq(uint256(vault.state()), uint256(State.Closed));
    }

    function test_newSettleDepositAreForbiddenButClaimsAreAvailable() public {
        vm.prank(vault.safe());
        vm.expectRevert("Not open");
        vault.settleDeposit();

        // previous settled deposit request are still claimable in State.Closing
        vm.prank(user1.addr);
        vault.deposit(1, user1.addr);

        assertEq(vault.balanceOf(user1.addr), 1);

        vm.prank(safe.addr);
        vault.close();

        // previous settled deposit request are still claimable in State.Closed
        vm.prank(user1.addr);
        vault.deposit(1, user1.addr);

        assertEq(vault.balanceOf(user1.addr), 2);
    }

    function test_requestRedemptionAreImpossible() public {
        uint256 user1PendingAssets = vault.pendingDepositRequest(0, user1.addr);

        vm.startPrank(user1.addr);

        vault.deposit(user1PendingAssets, user1.addr);
        uint256 user1Shares = vault.balanceOf(user1.addr);

        vm.expectRevert("Not open");
        vault.requestRedeem(user1Shares / 2, user1.addr, user1.addr);

        vm.stopPrank();

        vm.prank(safe.addr);
        vault.close();

        vm.expectRevert("Not open");
        vault.requestRedeem(user1Shares / 2, user1.addr, user1.addr);
    }

    function test_redeemAssetWithoutClaimableRedeem() public {
        uint256 user1ClaimableAssets = vault.claimableDepositRequest(
            0,
            user1.addr
        );
        console.log("claimable assets: ", user1ClaimableAssets);

        vm.prank(user1.addr);
        vault.deposit(user1ClaimableAssets, user1.addr);

        // @dev we can add assets and shares because pps = 1 assets / share
        assertEq(vault.balanceOf(user1.addr), user1ClaimableAssets);

        console.log(
            "safe balance: ",
            IERC20(vault.asset()).balanceOf(safe.addr)
        );

        vm.prank(safe.addr);
        vault.close();

        vm.prank(user1.addr);
        uint256 amount = vault.redeem(
            user1ClaimableAssets / 2,
            user1.addr,
            user1.addr
        );
        console.log("totalSupply : ", vault.totalSupply());
        assertEq(amount, user1ClaimableAssets / 2);

        console.log("vault balance: ", assetBalance(address(vault)));
        console.log(
            "amount : ",
            vault.convertToAssets(vault.balanceOf(user1.addr))
        );

        vm.startPrank(user1.addr);
        vault.redeem(vault.balanceOf(user1.addr), user1.addr, user1.addr);
        vm.stopPrank();

        // @dev we can add assets and shares because pps = 1 assets / share
        assertEq(assetBalance(user1.addr), 2 * user1ClaimableAssets);
    }

    function test_withdrawAssetWithoutClaimableRedeem() public {
        uint256 user1PendingAssets = vault.pendingDepositRequest(0, user1.addr);
        uint256 user1Assets = assetBalance(user1.addr);

        vm.startPrank(user1.addr);

        vault.deposit(user1PendingAssets, user1.addr);
        uint256 user1Shares = vault.balanceOf(user1.addr);

        vault.withdraw(user1Shares / 2, user1.addr, user1.addr);
        vm.stopPrank();

        // @dev we can add assets and shares because pps = 1 assets / share
        assertEq(assetBalance(user1.addr), user1Assets + user1Shares / 2);

        vm.prank(safe.addr);
        vault.close();

        vm.prank(user1.addr);
        vault.withdraw(user1Shares / 2, user1.addr, user1.addr);

        // @dev we can add assets and shares because pps = 1 assets / share
        assertEq(assetBalance(user1.addr), user1Assets + user1Shares);
    }

    function test_cantCloseAVaultWithoutFullUnwind() public {
        IERC20 asset = IERC20(vault.asset());
        uint256 safeBalance = asset.balanceOf(safe.addr);
        vm.prank(safe.addr);
        asset.transfer(address(0x1), safeBalance - 1);

        assertEq(asset.balanceOf(safe.addr), 1);
        assertEq(
            vault.totalAssets(),
            50_000 * 10 ** vault.underlyingDecimals()
        );

        vm.prank(safe.addr);
        vm.expectRevert("not enough liquidity to unwind");
        vault.close();

        assertEq(asset.balanceOf(safe.addr), 1);
    }

    function test_CloseCantBeCalledAfterVaultIsClosed() public {
        vm.prank(safe.addr);
        vault.close();

        vm.prank(safe.addr);
        vm.expectRevert("Not Closing");
        vault.close();
    }

    // function test_withdrawAssetWithClaimableRedeem() public {
    //     uint256 user2PendingShares = vault.pendingRedeemRequest(0, user2.addr);

    //     deal(
    //         vault.asset(),
    //         safe.addr,
    //         100_000 * 10 ** vault.underlyingDecimals()
    //     );

    //     updateTotalAssets(100_000 * 10 ** vault.underlyingDecimals());

    //     vm.warp(block.timestamp + 1 days);

    //     vm.prank(safe.addr);
    //     vault.close();

    //     vm.prank(user2.addr);
    //     vault.redeem(user2PendingShares, user2.addr, user2.addr);

    //     vm.prank(user2.addr);
    //     vault.redeem(user2PendingShares, user2.addr, user2.addr);

    //     // vm.prank(user1.addr);
    //     // vault.withdraw(user1Shares / 2, user1.addr, user1.addr);

    //     // // @dev we can add assets and shares because pps = 1 assets / share
    //     // assertEq(assetBalance(user1.addr), user1Assets + user1Shares);
    // }
}
