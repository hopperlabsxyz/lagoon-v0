// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, State} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";

contract TestInitiateClosing is BaseTest {
    uint256 user1AssetsBeginning = 0;
    uint256 user2AssetsBeginning = 0;

    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        user1AssetsBeginning = user1Assets;
        uint256 user2Assets = assetBalance(user2.addr);
        user2AssetsBeginning = user2Assets;

        requestDeposit(user1Assets / 2, user1.addr);
        requestDeposit(user2Assets / 2, user2.addr);

        updateAndSettle(0);

        // User2 has pending redeem request
        vm.startPrank(user2.addr);
        vault.deposit(user2Assets / 2, user2.addr);
        // user2 ask for redemption on half of his shares
        vault.requestRedeem(user2Assets / 4, user2.addr, user2.addr);
        vm.stopPrank();

        updateAndSettle(100_000 * 10 ** vault.underlyingDecimals());

        vm.warp(block.timestamp + 30 days);

        assertEq(uint256(vault.state()), uint256(State.Open));

        vm.prank(admin.addr);
        vault.initiateClosing();

        assertEq(uint256(vault.state()), uint256(State.Closing));

        // User1 has claimbale deposit & user2 has claimable redeem
        updateTotalAssets(vault.totalAssets());

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

        vm.startPrank(user1.addr);
        uint256 amountFirstRedeem = vault.redeem(
            vault.balanceOf(user1.addr) / 2,
            user1.addr,
            user1.addr
        );

        uint256 amountSecondRedeem = vault.redeem(
            vault.balanceOf(user1.addr),
            user1.addr,
            user1.addr
        );
        assertEq(amountFirstRedeem, amountSecondRedeem);

        vm.stopPrank();

        assertEq(assetBalance(user1.addr), 2 * user1ClaimableAssets);
        assertEq(assetBalance(user1.addr), user1AssetsBeginning);
    }

    function test_withdrawAssetWithoutClaimableRedeem() public {
        uint256 user1ClaimableAssets = vault.claimableDepositRequest(
            0,
            user1.addr
        );

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

        vm.startPrank(user1.addr);
        uint256 amountFirstWithdraw = vault.withdraw(
            vault.balanceOf(user1.addr) / 2,
            user1.addr,
            user1.addr
        );

        uint256 amountSecondWithdraw = vault.withdraw(
            vault.balanceOf(user1.addr),
            user1.addr,
            user1.addr
        );
        assertEq(amountFirstWithdraw, amountSecondWithdraw);

        vm.stopPrank();

        assertEq(assetBalance(user1.addr), 2 * user1ClaimableAssets);
        assertEq(assetBalance(user1.addr), user1AssetsBeginning);
    }

    function test_cantCloseAVaultWithoutFullUnwind() public {
        IERC20 asset = IERC20(vault.asset());
        uint256 safeBalance = asset.balanceOf(safe.addr);
        vm.prank(safe.addr);
        asset.transfer(address(0x1), safeBalance - 1);

        assertEq(asset.balanceOf(safe.addr), 1);
        assertEq(
            vault.totalAssets(),
            75_000 * 10 ** vault.underlyingDecimals()
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

    function test_redeemSharesWithClaimableRedeem() public {
        uint256 user2PendingShares = vault.pendingRedeemRequest(0, user2.addr);
        assertEq(user2PendingShares, 0);
        assertEq(
            vault.balanceOf(user2.addr),
            25_000 * 10 ** vault.decimals(),
            "wrong shares balance"
        );
        // user 2 here has 50_000 underlying, 25_000 claimableRedeem and 25_000 shares
        updateTotalAssets(vault.totalAssets());
        vm.warp(block.timestamp + 1 days);
        vm.prank(safe.addr);
        vault.close();
        uint256 firstRedeem = redeem(
            (25_000 / 2) * 10 ** vault.decimals(),
            user2.addr
        );
        assertEq(
            firstRedeem,
            (25_000 / 2) * 10 ** vault.underlyingDecimals(),
            "did not received expected assets"
        );
        uint256 secondRedeem = redeem(
            (25_000 / 2) * 10 ** vault.decimals(),
            user2.addr
        );
        assertEq(
            secondRedeem,
            (25_000 / 2) * 10 ** vault.underlyingDecimals(),
            "did not received expected assets 2"
        );
        uint256 thirdRedeem = redeem(
            25_000 * 10 ** vault.decimals(),
            user2.addr
        );
        assertEq(
            thirdRedeem,
            25_000 * 10 ** vault.underlyingDecimals(),
            "did not received expected assets 3"
        );
        assertEq(
            vault.balanceOf(user2.addr),
            0,
            "should not have any shares anymore"
        );
        assertEq(
            user2AssetsBeginning,
            assetBalance(user2.addr),
            "wrong end asset balance"
        );

        // now it is user 1 turns
        assertEq(
            vault.claimableDepositRequest(0, user1.addr),
            50_000 * 10 ** vault.underlyingDecimals()
        );
        assertEq(vault.balanceOf(user1.addr), 0);

        deposit(vault.claimableDepositRequest(0, user1.addr), user1.addr);

        assertEq(
            vault.balanceOf(user1.addr),
            50_000 * 10 ** vault.underlyingDecimals()
        );
        uint256 redeemUser1 = redeem(
            50_000 * 10 ** vault.decimals(),
            user1.addr
        );
        assertEq(
            redeemUser1,
            50_000 * 10 ** vault.underlyingDecimals(),
            "did not received expected assets user 1"
        );

        assertEq(
            user1AssetsBeginning,
            assetBalance(user1.addr),
            "wrong end asset balance user1"
        );
    }

    function test_redeemSharesWithClaimableRedeemWithProfits() public {
        uint256 multi = 2;
        uint256 user2PendingShares = vault.pendingRedeemRequest(0, user2.addr);
        assertEq(user2PendingShares, 0);
        assertEq(
            vault.balanceOf(user2.addr),
            25_000 * 10 ** vault.decimals(),
            "wrong shares balance"
        );
        // user 2 here has 50_000 underlying, 25_000 claimableRedeem and 25_000 shares
        updateTotalAssets(vault.totalAssets() * multi);
        vm.warp(block.timestamp + 1 days);
        deal(vault.asset(), safe.addr, vault.totalAssets() * multi);
        vm.prank(safe.addr);
        vault.close();
        assertEq(
            vault.totalAssets() / 10 ** vault.underlyingDecimals(),
            150_000,
            "wrong total assets"
        );

        uint256 firstRedeem = redeem(
            (25_000 / 2) * 10 ** vault.decimals(),
            user2.addr
        );
        assertEq(
            firstRedeem / 10 ** vault.underlyingDecimals(),
            (25_000 / 2),
            "did not received expected assets"
        ); // no profit here because settle associated with this request did not bring any profits
        uint256 secondRedeem = redeem(
            (25_000 / 2) * 10 ** vault.decimals(),
            user2.addr
        );
        assertEq(
            secondRedeem,
            (25_000 / 2) * 10 ** vault.underlyingDecimals(),
            "did not received expected assets 2"
        ); // same here
        uint256 thirdRedeem = redeem(
            25_000 * 10 ** vault.decimals(),
            user2.addr
        );
        assertApproxEqAbs(
            thirdRedeem,
            25_000 * 10 ** vault.underlyingDecimals() * multi,
            1,
            "did not received expected assets 3"
        );
        assertEq(
            vault.balanceOf(user2.addr),
            0,
            "should not have any shares anymore"
        );
        assertApproxEqAbs(
            (75_000 + (25_000 * multi)) * 10 ** vault.underlyingDecimals(),
            assetBalance(user2.addr),
            1,
            "wrong end asset balance"
        );

        // now it is user 1 turns
        assertEq(
            vault.claimableDepositRequest(0, user1.addr),
            50_000 * 10 ** vault.underlyingDecimals()
        );
        assertEq(vault.balanceOf(user1.addr), 0);

        deposit(vault.claimableDepositRequest(0, user1.addr), user1.addr);

        assertEq(
            vault.balanceOf(user1.addr),
            50_000 * 10 ** vault.underlyingDecimals(),
            "wrong shares balance user1"
        );
        uint256 redeemUser1 = redeem(
            50_000 * 10 ** vault.decimals(),
            user1.addr
        );
        assertEq(
            redeemUser1,
            50_000 * 10 ** vault.underlyingDecimals() * multi,
            "did not received expected assets user 1"
        );
        assertApproxEqAbs(
            user1AssetsBeginning + 50_000 * 10 ** vault.underlyingDecimals(),
            assetBalance(user1.addr),
            1,
            "wrong end asset balance user1"
        );
    }
}
