// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Constants} from "./Constants.sol";
import {Vault} from "@src/Vault.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IERC4626, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "forge-std/Test.sol";

contract BaseTest is Test, Constants {
    function requestDeposit(address user, uint256 amount) internal {
        vm.prank(user);
        vault.requestDeposit(amount, user, user);
    }

    function dealAndApprove(address user) public {
        address asset = vault.asset();
        deal(user, type(uint256).max);
        dealAsset(
            vault.asset(),
            user,
            10000 * 10 ** IERC20Metadata(asset).decimals()
        );
        vm.prank(user1.addr);
        IERC4626(asset).approve(address(vault), UINT256_MAX);
    }

    function dealAsset(address asset, address owner, uint256 amount) public {
        if (asset == address(USDC)) {
            vm.prank(USDC_WHALE);
            USDC.transfer(owner, amount);
        } else {
            deal(asset, owner, amount);
        }
    }

    function assetBalance(address user) public view returns (uint256) {
        return IERC4626(vault.asset()).balanceOf(user);
    }
}
