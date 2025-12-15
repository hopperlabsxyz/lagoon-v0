// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {Constants} from "./Constants.sol";
import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract BaseTest is Test, Constants {
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
        vm.prank(operator);
        return vault.deposit(amount, receiver, controller);
    }

    function deposit(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        vm.prank(user);
        return vault.deposit(amount, user);
    }

    function mint(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        vm.prank(operator);
        return vault.mint(amount, receiver, controller);
    }

    function mint(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        vm.prank(user);
        return vault.mint(amount, user);
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
        uint256 assetsBeforeReceiver = assetBalance(receiver);
        uint256 assetsBeforeController = assetBalance(controller);
        uint256 assetsBeforeOperator = assetBalance(operator);
        vm.prank(operator);
        uint256 assets = vault.redeem(amount, receiver, controller);
        assertEq(
            assetsBeforeReceiver + assets, assetBalance(receiver), "Receiver assets balance did not increase properly"
        );
        if (controller != receiver) {
            assertEq(
                assetsBeforeController,
                assetBalance(controller),
                "Controller assets balance should remain the same after redeem"
            );
        }
        if (operator != receiver) {
            assertEq(
                assetsBeforeOperator,
                assetBalance(operator),
                "Operator assets balance should remain the same after redeem"
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

    function withdraw(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        uint256 assetsBeforeReceiver = assetBalance(receiver);
        uint256 assetsBeforeController = assetBalance(controller);
        uint256 assetsBeforeOperator = assetBalance(operator);
        vm.prank(operator);
        uint256 shares = vault.withdraw(amount, receiver, controller);
        assertEq(
            assetsBeforeReceiver + amount, assetBalance(receiver), "Receiver assets balance did not increase properly"
        );
        if (controller != receiver) {
            assertEq(
                assetsBeforeController,
                assetBalance(controller),
                "Controller assets balance should remain the same after redeem"
            );
        }
        if (operator != receiver) {
            assertEq(
                assetsBeforeOperator,
                assetBalance(operator),
                "Operator assets balance should remain the same after redeem"
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
        vault.settleDeposit();
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
        vault.close();
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

    function settleRedeem() internal {
        dealAmountAndApprove(vault.safe(), vault.newTotalAssets());
        uint256 redeemSettleIdBefore = vault.redeemSettleId();
        uint256 pendingRedeemAmount = vault.pendingRedeem();

        vm.startPrank(vault.safe());
        vault.settleRedeem();
        vm.stopPrank();

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
        IERC4626(asset).approve(address(vault), UINT256_MAX);
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
}
