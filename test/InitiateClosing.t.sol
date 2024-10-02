// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC7540InvalidOperator} from "@src/vault/ERC7540.sol";
import {Closed, NotClosing, NotOpen, State, Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";

contract TestInitiateClosing is BaseTest {
    uint256 user1AssetsBeginning = 0;
    uint256 user2AssetsBeginning = 0;

    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        State s = vault.state();
        require(s == State.Open, "vault should be open");
        dealAndApprove(user1.addr); // if we deal 100k assets
        dealAndApprove(user2.addr); // if we deal 100k assets

        uint256 user1Assets = assetBalance(user1.addr);
        user1AssetsBeginning = user1Assets; // 100k assets

        uint256 user2Assets = assetBalance(user2.addr);
        user2AssetsBeginning = user2Assets; // 100k assets

        requestDeposit(user1Assets / 2, user1.addr); // 50k assets
        requestDeposit(user2Assets / 2, user2.addr); // 50k assets

        // user1: 50k shares claimable
        // user2: 50k shares claimable
        updateAndSettle(0);

        // User2 claims 50k shares
        vm.startPrank(user2.addr);
        vault.deposit(user2Assets / 2, user2.addr);

        // user2 ask for redemption on half of his shares
        vault.requestRedeem(25_000 * 10 ** vault.decimals(), user2.addr, user2.addr); // 25k shares pending
        vm.stopPrank();

        // user1: 50k shares claimable
        // user2:
        //    - 25k assets claimable
        //    - 25k shares holding
        updateAndSettle(100_000 * 10 ** vault.underlyingDecimals());

        vm.warp(block.timestamp + 30 days);

        assertEq(uint256(vault.state()), uint256(State.Open));

        // Invariant: We can't call close without initiating close
        vm.prank(safe.addr);
        vm.expectRevert(abi.encodeWithSelector(NotClosing.selector, State.Open));
        vault.close();

        vm.prank(admin.addr);
        vault.initiateClosing();

        assertEq(uint256(vault.state()), uint256(State.Closing));

        // user1: 50k shares claimable
        // user2:
        //    - 25k assets claimable
        //    - 25k shares holding
        updateNewTotalAssets(vault.totalAssets());

        vm.warp(block.timestamp + 1 days);
    }

    function test_canNotCallInitiateClosingTwice() public {
        vm.prank(admin.addr);
        vm.expectRevert(abi.encodeWithSelector(NotOpen.selector, State.Closing));
        vault.initiateClosing();
    }

    function test_closingVaultMarkTheVaultAsClosed() public {
        vm.prank(safe.addr);
        vault.close();

        assertEq(uint256(vault.state()), uint256(State.Closed));
    }

    function test_newSettleDepositAreForbiddenButClaimsAreAvailable() public {
        vm.prank(vault.safe());
        vm.expectRevert(abi.encodeWithSelector(NotOpen.selector, State.Closing));
        vault.settleDeposit();

        // previous settled deposit request are still claimable in State.Closing
        vm.prank(user1.addr);
        vault.deposit(1, user1.addr);

        assertEq(vault.balanceOf(user1.addr), 1 * 10 ** vault.decimalsOffset(), "user1 wrong balance");

        vm.prank(safe.addr);
        vault.close();

        // previous settled deposit request are still claimable in State.Closed
        vm.prank(user1.addr);
        vault.deposit(1, user1.addr);

        assertEq(vault.balanceOf(user1.addr), 2 * 10 ** vault.decimalsOffset());
    }

    function test_requestRedemptionAreImpossible() public {
        uint256 user1PendingAssets = vault.pendingDepositRequest(0, user1.addr);

        vm.startPrank(user1.addr);

        vault.deposit(user1PendingAssets, user1.addr);
        uint256 user1Shares = vault.balanceOf(user1.addr);

        vm.expectRevert(abi.encodeWithSelector(NotOpen.selector, State.Closing));
        vault.requestRedeem(user1Shares / 2, user1.addr, user1.addr);

        vm.stopPrank();

        vm.prank(safe.addr);
        vault.close();

        vm.expectRevert(abi.encodeWithSelector(NotOpen.selector, State.Closed));
        vault.requestRedeem(user1Shares / 2, user1.addr, user1.addr);
    }

    function test_redeemAssetWithoutClaimableRedeem() public {
        uint256 user1ClaimableAssets = vault.claimableDepositRequest(0, user1.addr);

        vm.prank(user1.addr);
        vault.deposit(user1ClaimableAssets, user1.addr);

        // @dev we can add assets and shares because pps = 1 assets / share
        assertEq(vault.balanceOf(user1.addr), user1ClaimableAssets * 10 ** vault.decimalsOffset());

        console.log("safe balance: ", IERC20(vault.asset()).balanceOf(safe.addr));

        vm.prank(safe.addr);
        vault.close();

        vm.startPrank(user1.addr);
        uint256 amountFirstRedeem = vault.redeem(vault.balanceOf(user1.addr) / 2, user1.addr, user1.addr);

        uint256 amountSecondRedeem = vault.redeem(vault.balanceOf(user1.addr), user1.addr, user1.addr);
        assertEq(amountFirstRedeem, amountSecondRedeem);

        vm.stopPrank();

        assertEq(assetBalance(user1.addr), 2 * user1ClaimableAssets);
        assertEq(assetBalance(user1.addr), user1AssetsBeginning);
    }

    function test_withdrawAssetWithoutClaimableRedeem() public {
        uint256 user1ClaimableAssets = vault.claimableDepositRequest(0, user1.addr);

        vm.prank(user1.addr);
        vault.deposit(user1ClaimableAssets, user1.addr);

        // @dev we can add assets and shares because pps = 1 assets / share
        assertEq(
            vault.balanceOf(user1.addr), user1ClaimableAssets * 10 ** vault.decimalsOffset(), "wrong balance of shares"
        );

        console.log("safe balance: ", IERC20(vault.asset()).balanceOf(safe.addr));

        vm.prank(safe.addr);
        vault.close();

        vm.startPrank(user1.addr);
        uint256 sharesFirstWithdraw = vault.withdraw(user1ClaimableAssets / 2, user1.addr, user1.addr);

        uint256 sharesSecondWithdraw = vault.withdraw(user1ClaimableAssets / 2, user1.addr, user1.addr);
        assertEq(sharesFirstWithdraw, sharesSecondWithdraw, "first withdraw != second withdraw");

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
        assertEq(vault.totalAssets(), 75_000 * 10 ** vault.underlyingDecimals());
        vm.prank(safe.addr);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vault.close();

        assertEq(asset.balanceOf(safe.addr), 1);
    }

    function test_CloseCantBeCalledAfterVaultIsClosed() public {
        vm.prank(safe.addr);
        vault.close();

        vm.prank(safe.addr);
        vm.expectRevert(abi.encodeWithSelector(NotClosing.selector, State.Closed));
        vault.close();
    }

    function test_redeemSharesWithClaimableRedeem() public {
        uint256 user2PendingShares = vault.pendingRedeemRequest(0, user2.addr);
        assertEq(user2PendingShares, 0);
        assertEq(vault.balanceOf(user2.addr), 25_000 * 10 ** vault.decimals(), "wrong shares balance");
        // user 2 here has 50_000 underlying, 25_000 claimableRedeem and 25_000 shares
        updateNewTotalAssets(vault.totalAssets());
        vm.warp(block.timestamp + 1 days);
        vm.prank(safe.addr);
        vault.close();
        uint256 firstRedeem = redeem((25_000 / 2) * 10 ** vault.decimals(), user2.addr);
        assertEq(firstRedeem, (25_000 / 2) * 10 ** vault.underlyingDecimals(), "did not received expected assets");
        uint256 secondRedeem = redeem((25_000 / 2) * 10 ** vault.decimals(), user2.addr);
        assertEq(secondRedeem, (25_000 / 2) * 10 ** vault.underlyingDecimals(), "did not received expected assets 2");
        uint256 thirdRedeem = redeem(25_000 * 10 ** vault.decimals(), user2.addr);
        assertEq(thirdRedeem, 25_000 * 10 ** vault.underlyingDecimals(), "did not received expected assets 3");
        assertEq(vault.balanceOf(user2.addr), 0, "should not have any shares anymore");
        assertEq(user2AssetsBeginning, assetBalance(user2.addr), "wrong end asset balance");

        // now it is user 1 turns
        assertEq(vault.claimableDepositRequest(0, user1.addr), 50_000 * 10 ** vault.underlyingDecimals());
        assertEq(vault.balanceOf(user1.addr), 0);

        deposit(vault.claimableDepositRequest(0, user1.addr), user1.addr);

        assertEq(vault.balanceOf(user1.addr), 50_000 * 10 ** vault.decimals());
        uint256 assetsRedeemUser1 = redeem(50_000 * 10 ** vault.decimals(), user1.addr);
        assertEq(
            assetsRedeemUser1, 50_000 * 10 ** vault.underlyingDecimals(), "did not received expected assets user 1"
        );

        assertEq(user1AssetsBeginning, assetBalance(user1.addr), "wrong end asset balance user1");
    }

    function test_redeemSharesWithClaimableRedeemWithProfits() public {
        uint256 multi = 2;
        uint256 user2PendingShares = vault.pendingRedeemRequest(0, user2.addr);
        assertEq(user2PendingShares, 0);
        assertEq(vault.balanceOf(user2.addr), 25_000 * 10 ** vault.decimals(), "wrong shares balance");
        // user 2 here has 50_000 underlying, 25_000 claimableRedeem and 25_000 shares
        updateNewTotalAssets(vault.totalAssets() * multi);
        vm.warp(block.timestamp + 1 days);
        deal(vault.asset(), safe.addr, vault.totalAssets() * multi);
        vm.prank(safe.addr);
        vault.close();
        assertEq(vault.totalAssets() / 10 ** vault.underlyingDecimals(), 150_000, "wrong total assets");

        uint256 firstRedeem = redeem((25_000 / 2) * 10 ** vault.decimals(), user2.addr);
        assertEq(firstRedeem / 10 ** vault.underlyingDecimals(), (25_000 / 2), "did not received expected assets"); // no
        // profit here because settle associated with this request did not bring any profits
        uint256 secondRedeem = redeem((25_000 / 2) * 10 ** vault.decimals(), user2.addr);
        assertEq(secondRedeem, (25_000 / 2) * 10 ** vault.underlyingDecimals(), "did not received expected assets 2"); // same
            // here

        uint256 thirdRedeem = redeem(25_000 * 10 ** vault.decimals(), user2.addr);
        assertApproxEqAbs(
            thirdRedeem, 25_000 * 10 ** vault.underlyingDecimals() * multi, 1, "did not received expected assets 3"
        );
        assertEq(vault.balanceOf(user2.addr), 0, "should not have any shares anymore");
        assertApproxEqAbs(
            (75_000 + (25_000 * multi)) * 10 ** vault.underlyingDecimals(),
            assetBalance(user2.addr),
            1,
            "wrong end asset balance"
        );

        // now it is user 1 turns
        assertEq(vault.claimableDepositRequest(0, user1.addr), 50_000 * 10 ** vault.underlyingDecimals());
        assertEq(vault.balanceOf(user1.addr), 0);

        deposit(vault.claimableDepositRequest(0, user1.addr), user1.addr);

        assertEq(vault.balanceOf(user1.addr), 50_000 * 10 ** vault.decimals(), "wrong shares balance user1");
        uint256 redeemUser1 = redeem(50_000 * 10 ** vault.decimals(), user1.addr);
        assertEq(
            redeemUser1, 50_000 * 10 ** vault.underlyingDecimals() * multi, "did not received expected assets user 1"
        );
        assertApproxEqAbs(
            user1AssetsBeginning + 50_000 * 10 ** vault.underlyingDecimals(),
            assetBalance(user1.addr),
            1,
            "wrong end asset balance user1"
        );
    }

    // @dev The vault is State.Closing => classic async path is used
    function test_inClosingStateCanNotWithdrawOrRedeemIfNotOperatorAndEvenWithEnoughAllowance() public {
        uint256 assetsClaimable = vault.claimableRedeemRequest(0, user2.addr);

        vm.prank(user2.addr);
        vault.approve(user3.addr, assetsClaimable);

        vm.prank(user3.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.withdraw(assetsClaimable, user2.addr, user2.addr);

        vm.prank(user3.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.redeem(assetsClaimable, user2.addr, user2.addr);
    }

    // @dev The vault is State.Closing => classic async path is used
    function test_inClosingStateCanWithdrawAndRedeemIfOperator() public {
        uint256 decimalsOffset = vault.decimalsOffset();
        uint256 sharesClaimable = vault.claimableRedeemRequest(0, user2.addr);
        uint256 assetsClaimable = sharesClaimable / (10 ** decimalsOffset);

        vm.prank(user2.addr);
        vault.setOperator(user3.addr, true);

        vm.prank(user3.addr);
        uint256 amount1 = vault.withdraw(assetsClaimable / 2, user2.addr, user2.addr);
        assertEq(amount1, sharesClaimable / 2, "amount1 is wrong");

        vm.prank(user3.addr);
        uint256 amount2 = vault.redeem(sharesClaimable / 2, user2.addr, user2.addr);
        assertEq(amount2, assetsClaimable / 2, "amount2 is wrong");
    }

    // @dev The vault is State.Closed => sync path is used after all async claims are claimed
    function test_inClosedStateCanWithdrawAndRedeemIfOperatorOrEnoughAllowance() public {
        vm.prank(safe.addr);
        vault.close();

        uint256 decimalsOffset = vault.decimalsOffset();
        uint256 sharesClaimable = vault.claimableRedeemRequest(0, user2.addr);
        uint256 assetsClaimable = sharesClaimable / (10 ** decimalsOffset);

        vm.prank(user2.addr);
        vault.setOperator(user3.addr, true);

        vm.prank(user2.addr);
        vault.setOperator(user4.addr, true);

        vm.prank(user2.addr);
        vault.approve(user4.addr, sharesClaimable / 2);

        // All assets that where redeemed in async mode are claimed first
        vm.prank(user3.addr);
        uint256 amount1 = vault.withdraw(assetsClaimable, user2.addr, user2.addr);
        assertEq(amount1, sharesClaimable, "amount1 is wrong");

        // There are still assetsClaimable assets available to claim synchronously (see initial setUp)
        // assertEq(vault.balanceOf(user2.addr), assetsClaimable);

        // user3 is an operator so he can sync withdraw on behalf of user2...
        vm.prank(user3.addr);
        uint256 amount2 = vault.withdraw(assetsClaimable / 4, user2.addr, user2.addr);
        assertEq(amount2, sharesClaimable / 4, "amount2 is wrong");

        // ... and sync redeem also
        vm.prank(user3.addr);
        uint256 amount3 = vault.redeem(sharesClaimable / 4, user2.addr, user2.addr);
        assertEq(amount3, assetsClaimable / 4, "amount3 is wrong");

        // user5 can't redeem because he is not an operator nor has enough allowance for doing so
        vm.expectRevert(ERC7540InvalidOperator.selector);

        vm.prank(user5.addr);
        vault.redeem(sharesClaimable / 4, user2.addr, user2.addr);

        // ... same for withdraw
        vm.expectRevert(ERC7540InvalidOperator.selector);

        vm.prank(user5.addr);
        vault.withdraw(assetsClaimable / 4, user2.addr, user2.addr);

        // User4 has enough allow to withdraw assets on behalf of user2
        vm.prank(user4.addr);
        uint256 amount4 = vault.withdraw(assetsClaimable / 4, user2.addr, user2.addr);
        assertEq(amount4, sharesClaimable / 4, "amount4 is wrong");

        // ... same for redeem
        vm.prank(user4.addr);
        uint256 amount5 = vault.redeem(sharesClaimable / 4, user2.addr, user2.addr);
        assertEq(amount5, assetsClaimable / 4, "amount5 is wrong");
    }

    function test_cantUpdateNewTotalAssetsWhenClosed() public {
        vm.prank(safe.addr);
        vault.close();

        vm.startPrank(vault.navManager());
        uint256 totalAssets = vault.totalAssets();
        vm.expectRevert(abi.encodeWithSelector(Closed.selector));
        vault.updateNewTotalAssets(totalAssets);
    }
}
