// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Constants} from "./Constants.sol";
import {Vault} from "@src/Vault.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IERC4626, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "forge-std/Test.sol";

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
        uint256 requestDepBefore = vault.pendingDeposit();
        uint256 depositId = vault.depositId();
        vm.prank(operator);
        uint256 requestId = vault.requestDeposit(amount, controller, owner);
        assertEq(
            vault.pendingDeposit(),
            requestDepBefore + amount,
            "pendingDeposit value did not increase properly"
        );
        assertEq(
            depositId,
            requestId,
            "requestId should be equal to current depositId"
        );
        return requestId;
    }

    function requestDeposit(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        return requestDeposit(amount, user, user, user);
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

    function deposit(uint256 amount, address user) internal returns (uint256) {
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

    function mint(uint256 amount, address user) internal returns (uint256) {
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
        uint256 redeemId = vault.redeemId();
        vm.prank(operator);
        uint256 requestId = vault.requestRedeem(amount, controller, owner);
        assertEq(
            vault.pendingRedeem(),
            requestRedeemBefore + amount,
            "pendingRedeem value did not increase properly"
        );
        assertEq(
            redeemId,
            requestId,
            "requestId should be equal to current redeemId"
        );
        return redeemId;
    }

    function requestRedeem(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        return requestRedeem(amount, user, user, user);
    }

    function redeem(uint256 amount, address user) internal returns (uint256) {
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
            assetsBeforeReceiver + assets,
            assetBalance(receiver),
            "Receiver assets balance did not increase properly"
        );
        if (controller != receiver)
            assertEq(
                assetsBeforeController,
                assetBalance(controller),
                "Controller assets balance should remain the same after redeem"
            );
        if (operator != receiver)
            assertEq(
                assetsBeforeOperator,
                assetBalance(operator),
                "Operator assets balance should remain the same after redeem"
            );
        return assets;
    }

    function withdraw(uint256 amount, address user) internal returns (uint256) {
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
            assetsBeforeReceiver + amount,
            assetBalance(receiver),
            "Receiver assets balance did not increase properly"
        );
        if (controller != receiver)
            assertEq(
                assetsBeforeController,
                assetBalance(controller),
                "Controller assets balance should remain the same after redeem"
            );
        if (operator != receiver)
            assertEq(
                assetsBeforeOperator,
                assetBalance(operator),
                "Operator assets balance should remain the same after redeem"
            );
        return shares;
    }

    function updateTotalAssets(uint256 newTotalAssets) internal {
        vm.prank(vault.valorizationRole());
        vault.updateTotalAssets(newTotalAssets);
    }

    function settle() internal {
        dealAmountAndApproveAndWhitelist(
            vault.assetManagerRole(),
            vault.newTotalAssets()
        );
        vm.startPrank(vault.assetManagerRole());
        vault.settleDeposit();
        vm.stopPrank();
    }

    function updateAndSettle(uint256 newTotalAssets) internal {
        updateTotalAssets(newTotalAssets);
        vm.warp(block.timestamp + 1 days);
        settle();
    }

    function dealAndApproveAndWhitelist(address user) public {
        dealAmountAndApproveAndWhitelist(user, 100000);
    }

    function dealAmountAndApproveAndWhitelist(
        address user,
        uint256 amount
    ) public {
        address asset = vault.asset();
        deal(user, type(uint256).max);
        deal(
            vault.asset(),
            user,
            amount * 10 ** IERC20Metadata(asset).decimals()
        );
        vm.prank(user);
        IERC4626(asset).approve(address(vault), UINT256_MAX);
        whitelist(user);
    }

    function dealAndApprove(address user) public {
        dealAmountAndApprove(user, 100000);
    }

    function dealAmountAndApprove(address user, uint256 amount) public {
        address asset = vault.asset();
        deal(user, type(uint256).max);
        deal(
            vault.asset(),
            user,
            amount * 10 ** IERC20Metadata(asset).decimals()
        );
        vm.prank(user);
        IERC4626(asset).approve(address(vault), UINT256_MAX);
    }

    function assetBalance(address user) public view returns (uint256) {
        return IERC4626(vault.asset()).balanceOf(user);
    }

    function whitelist(address user) public {
        vm.prank(vault.adminRole());
        vault.addToWhitelist(user);
    }

    function whitelist(address[] memory users) public {
        vm.prank(vault.adminRole());
        vault.addToWhitelist(users);
    }

    function unwhitelist(address user) public {
        vm.prank(vault.adminRole());
        vault.revokeFromWhitelist(user);
    }

    function balance(address user) public view returns (uint256) {
        return vault.balanceOf(user);
    }
}
