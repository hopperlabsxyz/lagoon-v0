// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

contract TestMisc is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_previewDeposit() public {
        vm.expectRevert();
        vault.previewDeposit(0);
    }

    function test_previewWithdraw() public {
        vm.expectRevert();
        vault.previewWithdraw(0);
    }

    function test_previewMint() public {
        vm.expectRevert();
        vault.previewMint(0);
    }

    function test_previewRedeem() public {
        vm.expectRevert();
        vault.previewRedeem(0);
    }

    function test_share() public view {
        address share = vault.share();
        assertEq(share, address(vault));
    }

    function test_decimals() public view {
        uint256 underlyingDecimals = underlying.decimals();
        uint256 vaultDecimals = vault.decimals();
        assertEq(underlyingDecimals, vaultDecimals);
    }

    function test_redeemId() public {
        uint256 redeemId = vault.redeemId();
        assertEq(redeemId, 2);
        requestDeposit(10, user1.addr);
        updateAndSettle(1);
        redeemId = vault.redeemId();

        // redeemId didn't change because there is no redeem request
        assertEq(redeemId, 2);
        deposit(10, user1.addr);
        requestRedeem(vault.balanceOf(user1.addr), user1.addr);
        updateAndSettle(10);
        redeemId = vault.redeemId();
        assertEq(redeemId, 4);
    }

    function test_depositId() public {
        uint256 depositId = vault.depositId();
        assertEq(depositId, 1);
        requestDeposit(10, user1.addr);
        updateAndSettle(1);
        depositId = vault.depositId();
        assertEq(depositId, 3);
    }

    function test_pendingSilo() public view {
        address pendingSilo = vault.pendingSilo();
        assertNotEq(pendingSilo, address(0));
        assertEq(type(uint256).max, underlying.allowance(pendingSilo, address(vault)));
    }
}
