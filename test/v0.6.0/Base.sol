// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {SetUp} from "./SetUp.sol";

import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract BaseTest is Test, SetUp {
    using SafeERC20 for IERC20;

    function requestDeposit(
        uint256 amount,
        address controller,
        address owner
    ) internal returns (uint256) {
        vm.prank(owner);
        return vault.requestDeposit(amount, controller, owner);
    }

    function requestDeposit(
        uint256 amount,
        address controller,
        address owner,
        address operator
    ) internal returns (uint256) {
        return _requestDeposit(amount, controller, owner, operator, address(0), false);
    }

    function requestDeposit(
        uint256 amount,
        address controller,
        address owner,
        address operator,
        address referral
    ) internal returns (uint256) {
        return _requestDeposit(amount, controller, owner, operator, referral, false);
    }

    function requestDeposit(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        return requestDeposit(amount, user, user, user);
    }

    function requestDeposit(
        uint256 amount,
        address user,
        bool viaEth
    ) internal returns (uint256) {
        return _requestDeposit(amount, user, user, user, address(0), viaEth);
    }

    function _requestDeposit(
        uint256 amount,
        address controller,
        address owner,
        address operator,
        address referral,
        bool viaEth
    ) internal returns (uint256) {
        uint256 requestDepBefore = vault.pendingDeposit();
        uint256 pendingSiloAssetBalance = assetBalance(address(vault.pendingSilo()));
        uint256 vaultAssetBalance = assetBalance(address(vault));

        uint256 depositId = vault.depositEpochId();
        uint256 requestId;
        vm.prank(operator);
        uint256 value = viaEth ? amount : 0;
        if (referral == address(0)) {
            requestId = vault.requestDeposit{value: value}(amount, controller, owner);
        } else {
            requestId = vault.requestDeposit{value: value}(amount, controller, owner, referral);
        }

        assertEq(vault.pendingDeposit(), requestDepBefore + amount, "pendingDeposit value did not increase properly");
        assertEq(
            assetBalance(address(vault.pendingSilo())),
            pendingSiloAssetBalance + amount,
            "pending silo asset balance did not increase properly"
        );
        assertEq(assetBalance(address(vault)), vaultAssetBalance, "vault asset balance should not increase");
        assertEq(depositId, requestId, "requestId should be equal to current depositId");
        return requestId;
    }

    function deposit(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        uint256 sharesBefore = vault.balanceOf(receiver);

        uint256 lastRequestId = vault.lastDepositRequestId(controller);
        uint256 maxDeposit = vault.convertToShares(vault.maxDeposit(controller), lastRequestId);
        uint256 maxMint = vault.maxMint(controller);

        vm.prank(operator);
        uint256 shares = vault.deposit(amount, receiver, controller);

        uint256 sharesAfter = vault.balanceOf(receiver);

        assertLe(sharesAfter - sharesBefore, maxDeposit, "maxDeposit invariant does not hold [1]");
        assertLe(sharesAfter - sharesBefore, maxMint, "maxMint invariant does not hold [1]");
        assertEq(sharesAfter - sharesBefore, shares);

        return shares;
    }

    function deposit(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        address receiver = user;
        address controller = user;

        uint256 sharesBefore = vault.balanceOf(receiver);

        uint256 lastRequestId = vault.lastDepositRequestId(user);
        uint256 maxDeposit = vault.convertToShares(vault.maxDeposit(controller), lastRequestId);
        uint256 maxMint = vault.maxMint(controller);

        vm.prank(user);
        uint256 shares = vault.deposit(amount, user);

        uint256 sharesAfter = vault.balanceOf(receiver);

        if (!vault.isTotalAssetsValid()) {
            assertLe(sharesAfter - sharesBefore, maxDeposit, "maxDeposit invariant does not hold [1]");
            assertLe(sharesAfter - sharesBefore, maxMint, "maxMint invariant does not hold [1]");
        }
        assertEq(sharesAfter - sharesBefore, shares);

        return shares;
    }

    function mint(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        uint256 sharesBefore = vault.balanceOf(receiver);

        uint256 lastRequestId = vault.lastDepositRequestId(controller);
        uint256 maxDeposit = vault.convertToShares(vault.maxDeposit(controller), lastRequestId);
        uint256 maxMint = vault.maxMint(controller);

        vm.prank(operator);
        uint256 assets = vault.mint(amount, receiver, controller);

        uint256 sharesAfter = vault.balanceOf(receiver);

        assertLe(sharesAfter - sharesBefore, maxDeposit, "maxDeposit invariant does not hold [1]");
        assertLe(sharesAfter - sharesBefore, maxMint, "maxMint invariant does not hold [1]");

        return assets;
    }

    function mint(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        address receiver = msg.sender;
        address controller = user;
        uint256 sharesBefore = vault.balanceOf(receiver);

        uint40 lastRequestId = vault.lastDepositRequestId(user);
        uint256 maxDeposit = vault.convertToShares(vault.maxDeposit(controller), lastRequestId);
        uint256 maxMint = vault.maxMint(controller);

        uint256 assetsExpected = vault.convertToAssetsRequestIdWithRounding(
            amount + FeeLib.computeFeeReverse(amount, vault.getSettlementEntryFeeRate(lastRequestId)),
            lastRequestId,
            Math.Rounding.Ceil
        );
        vm.prank(user);
        uint256 assets = vault.mint(amount, user);
        assertEq(assets, assetsExpected, "mint: wrong assets returned");

        uint256 sharesAfter = vault.balanceOf(receiver);

        assertLe(sharesAfter - sharesBefore, maxDeposit, "maxDeposit invariant does not hold [1]");
        assertLe(sharesAfter - sharesBefore, maxMint, "maxMint invariant does not hold [1]");

        return assets;
    }

    function requestRedeem(
        uint256 amount,
        address controller,
        address owner
    ) internal returns (uint256) {
        address operator = owner;
        return requestRedeem(amount, controller, owner, operator);
    }

    function requestRedeem(
        uint256 amount,
        address controller,
        address owner,
        address operator
    ) internal returns (uint256) {
        uint256 requestRedeemBefore = vault.pendingRedeem();
        uint256 redeemId = vault.redeemEpochId();
        vm.prank(operator);
        uint256 requestId = vault.requestRedeem(amount, controller, owner);
        assertEq(vault.pendingRedeem(), requestRedeemBefore + amount, "pendingRedeem value did not increase properly");
        assertEq(redeemId, requestId, "requestId should be equal to current redeemId");
        return redeemId;
    }

    function requestRedeem(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        return requestRedeem(amount, user, user, user);
    }

    function redeem(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        return redeem(amount, user, user, user);
    }

    function redeem(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        // uint256 lastRequestId = vault.lastRedeemRequestId(controller);
        // console.log("---------");
        // console.log("total assets         ", vault.totalAssets());
        // console.log("asset balance vault  ", assetBalance(address(vault)));
        // console.log("asset balance safe   ", assetBalance(safe.addr));
        // console.log("current epoch id     ", vault.redeemSettleId());
        // console.log("redeem id            ", lastRequestId);
        // console.log("claimable redeems    ", vault.claimableRedeemRequest(lastRequestId, controller));
        // console.log("max redeem           ", vault.maxRedeem(controller));
        // console.log("max redeem converted ", vault.convertToAssets(vault.maxRedeem(controller), lastRequestId));
        // console.log("max withdraw         ", vault.maxWithdraw(controller));
        // console.log("user bal             ", vault.balanceOf(controller));
        // console.log("---------");
        uint256 assetsBeforeReceiver = assetBalance(receiver);
        uint256 sharesBeforeReceiver = balance(receiver);
        uint256 assetsBeforeController = assetBalance(controller);
        uint256 assetsBeforeOperator = assetBalance(operator);

        uint256 maxWithdraw = vault.maxWithdraw(controller);

        // uint256 maxRedeem = vault.convertToAssets(vault.maxRedeem(controller), lastRequestId);

        vm.prank(operator);
        uint256 assets = vault.redeem(amount, receiver, controller);
        uint256 assetsAfterReceiver = assetBalance(receiver);

        assertLe(assetsAfterReceiver - assetsBeforeReceiver, maxWithdraw, "redeem: wrong maxWithdraw");
        // assertLe(assetsAfterReceiver - assetsBeforeReceiver, maxRedeem, "wrong maxRedeem");

        console.log("shares before: ", sharesBeforeReceiver);
        console.log("shares       : ", amount);
        console.log("shares after: ", balance(receiver));
        assertEq(
            assetsBeforeReceiver + assets,
            assetBalance(receiver),
            "redeem: Receiver assets balance did not increase properly"
        );
        if (controller != receiver) {
            assertEq(
                assetsBeforeController,
                assetBalance(controller),
                "redeem: Controller assets balance should remain the same after redeem"
            );
        }
        if (operator != receiver) {
            assertEq(
                assetsBeforeOperator,
                assetBalance(operator),
                "redeem: Operator assets balance should remain the same after redeem"
            );
        }
        return assets;
    }

    function withdraw(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        return withdraw(amount, user, user, user);
    }

    struct Balances {
        uint256 receiver;
        uint256 controller;
        uint256 operator;
    }

    function withdraw(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        uint40 lastRequestId = vault.lastRedeemRequestId(controller);

        Balances memory assetsBefore = Balances({
            receiver: assetBalance(receiver), controller: assetBalance(controller), operator: assetBalance(operator)
        });
        Balances memory sharesBefore =
            Balances({receiver: balance(receiver), controller: balance(controller), operator: balance(operator)});

        uint256 maxWithdraw = vault.maxWithdraw(controller);

        // this value doesn't take into account the exit fee
        // it can only be used if the vault is closed
        uint256 convertedAssetsInShares = vault.convertToSharesWithRounding(amount, Math.Rounding.Ceil);

        vm.prank(operator);
        uint256 shares = vault.withdraw(amount, receiver, controller);

        Balances memory assetsAfter = Balances({
            receiver: assetBalance(receiver), controller: assetBalance(controller), operator: assetBalance(operator)
        });
        Balances memory sharesAfter =
            Balances({receiver: balance(receiver), controller: balance(controller), operator: balance(operator)});

        assertLe(assetsAfter.receiver - assetsBefore.receiver, maxWithdraw, "withdraw: wrong maxRedeem");

        if (vault.state() == State.Closed && vault.claimableRedeemRequest(0, controller) == 0) {
            assertEq(
                assetsBefore.receiver + amount,
                assetsAfter.receiver,
                "withdraw when closed: Receiver assets balance did not increase properly"
            );
            // With exit fees: shares returned = netShares + exitFeeShares
            uint256 exitFeeShares = FeeLib.computeFeeReverse(convertedAssetsInShares, vault.exitRate());
            uint256 expectedShares = convertedAssetsInShares + exitFeeShares;
            assertEq(expectedShares, shares, "withdraw when closed: shares taken from user is wrong");
            assertEq(
                sharesBefore.receiver - sharesAfter.receiver,
                shares,
                "withdraw when closed: shares taken from user is wrong 2"
            );
        } else {
            shares -= FeeLib.computeFee(shares, vault.getSettlementExitFeeRate(lastRequestId));
            uint256 expectedAssets = vault.convertToAssets(shares, lastRequestId);
            expectedAssets += assetsBefore.receiver;
            assertEq(
                expectedAssets,
                assetBalance(receiver),
                "withdraw when not closed: Receiver assets balance did not increase properly"
            );
        }
        if (controller != receiver) {
            assertEq(
                assetsBefore.controller,
                assetBalance(controller),
                "withdraw: Controller assets balance should remain the same after redeem"
            );
        }
        if (operator != receiver) {
            assertEq(
                assetsBefore.operator,
                assetBalance(operator),
                "withdraw: Operator assets balance should remain the same after redeem"
            );
        }
        return shares;
    }

    function updateNewTotalAssets(
        uint256 newTotalAssets
    ) internal {
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(newTotalAssets);
    }

    function settle() internal {
        dealAmountAndApprove(vault.safe(), vault.newTotalAssets());
        uint256 depositSettleIdBefore = vault.depositSettleId();
        uint256 redeemSettleIdBefore = vault.redeemSettleId();

        uint256 pendingDepositAmount = vault.pendingDeposit();
        uint256 pendingRedeemAmount = vault.pendingRedeem();

        vm.startPrank(vault.safe());
        vault.settleDeposit(vault.newTotalAssets());
        vm.stopPrank();

        uint256 depositSettleIdAfter = vault.depositSettleId();
        uint256 redeemSettleIdAfter = vault.redeemSettleId();

        if (pendingDepositAmount == 0) {
            assertEq(depositSettleIdBefore, depositSettleIdAfter);
        } else {
            assertEq(depositSettleIdBefore + 2, depositSettleIdAfter);
        }
        if (pendingRedeemAmount == 0) {
            assertEq(redeemSettleIdBefore, redeemSettleIdAfter);
        } else {
            assertEq(redeemSettleIdBefore + 2, redeemSettleIdAfter);
        }
    }

    function close() internal {
        dealAmountAndApprove(vault.safe(), vault.newTotalAssets());
        uint256 depositSettleIdBefore = vault.depositSettleId();
        uint256 redeemSettleIdBefore = vault.redeemSettleId();

        uint256 pendingDepositAmount = vault.pendingDeposit();
        uint256 pendingRedeemAmount = vault.pendingRedeem();

        vm.startPrank(vault.safe());
        vault.close(vault.newTotalAssets());
        vm.stopPrank();

        checkTotalAssetsExpiration();

        uint256 depositSettleIdAfter = vault.depositSettleId();
        uint256 redeemSettleIdAfter = vault.redeemSettleId();

        if (pendingDepositAmount == 0) {
            assertEq(depositSettleIdBefore, depositSettleIdAfter);
        } else {
            assertEq(depositSettleIdBefore + 2, depositSettleIdAfter);
        }
        if (pendingRedeemAmount == 0) {
            assertEq(redeemSettleIdBefore, redeemSettleIdAfter);
        } else {
            assertEq(redeemSettleIdBefore + 2, redeemSettleIdAfter);
        }
    }

    function settleRedeem() internal {
        dealAmountAndApprove(vault.safe(), vault.newTotalAssets());
        uint256 redeemSettleIdBefore = vault.redeemSettleId();
        uint256 pendingRedeemAmount = vault.pendingRedeem();

        vm.startPrank(vault.safe());
        vault.settleRedeem(vault.newTotalAssets());
        vm.stopPrank();

        checkTotalAssetsExpiration();

        uint256 redeemSettleIdAfter = vault.redeemSettleId();

        if (pendingRedeemAmount == 0) {
            assertEq(redeemSettleIdBefore, redeemSettleIdAfter);
        } else {
            assertEq(redeemSettleIdBefore + 2, redeemSettleIdAfter);
        }
    }

    function updateAndSettle(
        uint256 newTotalAssets
    ) internal {
        updateNewTotalAssets(newTotalAssets);
        vm.warp(block.timestamp + 1 days);
        settle();
    }

    function updateAndSettleRedeem(
        uint256 newTotalAssets
    ) internal {
        updateNewTotalAssets(newTotalAssets);
        vm.warp(block.timestamp + 1 days);
        settleRedeem();
    }

    function updateAndClose(
        uint256 newTotalAssets
    ) internal {
        updateNewTotalAssets(newTotalAssets);
        vm.warp(block.timestamp + 1 days);
        close();
    }

    function dealAndApproveAndWhitelist(
        address user
    ) public {
        dealAmountAndApprove(user, 100_000 * 10 ** vault.underlyingDecimals());
        whitelist(user);
    }

    function dealAmountAndApproveAndWhitelist(
        address user,
        uint256 amount
    ) public {
        dealAmountAndApprove(user, amount);
        whitelist(user);
    }

    function dealAndApprove(
        address user
    ) public {
        dealAmountAndApprove(user, 100_000 * 10 ** vault.underlyingDecimals());
    }

    function dealAmountAndApprove(
        address user,
        uint256 amount
    ) public {
        address asset = vault.asset();
        deal(user, type(uint256).max);
        deal(vault.asset(), user, amount);
        vm.prank(user);
        IERC20(asset).forceApprove(address(vault), UINT256_MAX);
    }

    function assetBalance(
        address user
    ) public view returns (uint256) {
        return IERC4626(vault.asset()).balanceOf(user);
    }

    function whitelist(
        address user
    ) public {
        address[] memory users = new address[](1);
        users[0] = user;
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(users);
    }

    function whitelist(
        address[] memory users
    ) public {
        vm.prank(vault.whitelistManager());
        vault.addToWhitelist(users);
    }

    function unwhitelist(
        address[] memory users
    ) public {
        vm.prank(vault.whitelistManager());
        vault.revokeFromWhitelist(users);
    }

    function unwhitelist(
        address user
    ) public {
        address[] memory users = new address[](1);
        users[0] = user;
        vm.prank(vault.whitelistManager());
        vault.revokeFromWhitelist(users);
    }

    function updateRates(
        Rates memory newRates
    ) public {
        vm.prank(vault.owner());
        vault.updateRates(newRates);
    }

    function balance(
        address user
    ) public view returns (uint256) {
        return vault.balanceOf(user);
    }

    function checkTotalAssetsExpiration() public view {
        uint256 totalAssetsExpiration = vault.totalAssetsExpiration();
        uint256 totalAssetsLifespan = vault.totalAssetsLifespan();

        assertEq(totalAssetsExpiration, block.timestamp + totalAssetsLifespan);
    }
}
