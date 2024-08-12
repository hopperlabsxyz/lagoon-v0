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
        vm.prank(operator);
        return vault.requestDeposit(amount, controller, owner);
    }

    function requestDeposit(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        vm.prank(user);
        return vault.requestDeposit(amount, user, user);
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
        vm.prank(owner);
        return vault.requestRedeem(amount, controller, owner);
    }

    function requestRedeem(
        uint256 amount,
        address controller,
        address owner,
        address operator
    ) internal returns (uint256) {
        vm.prank(operator);
        return vault.requestRedeem(amount, controller, owner);
    }

    function requestRedeem(
        uint256 amount,
        address user
    ) internal returns (uint256) {
        vm.prank(user);
        return vault.requestRedeem(amount, user, user);
    }

    function redeem(uint256 amount, address user) internal returns (uint256) {
        vm.prank(user);
        return vault.redeem(amount, user, user);
    }

    function redeem(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        vm.prank(operator);
        return vault.redeem(amount, receiver, controller);
    }

    function withdraw(uint256 amount, address user) internal returns (uint256) {
        vm.prank(user);
        return vault.withdraw(amount, user, user);
    }

    function withdraw(
        uint256 amount,
        address controller,
        address operator,
        address receiver
    ) internal returns (uint256) {
        vm.prank(operator);
        return vault.withdraw(amount, receiver, controller);
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
        whitelistMapModule.add(user);
    }

    function whitelist(address[] memory users) public {
        vm.prank(vault.adminRole());
        whitelistMapModule.add(users);
    }

    function unwhitelist(address user) public {
        vm.prank(vault.adminRole());
        whitelistMapModule.revoke(user);
    }

    function balance(address user) public view returns (uint256) {
        return vault.balanceOf(user);
    }
}
