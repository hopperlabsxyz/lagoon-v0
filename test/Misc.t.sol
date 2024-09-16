// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165, ERC7540PreviewRedeemDisabled, ERC7540PreviewDepositDisabled, ERC7540PreviewMintDisabled, ERC7540PreviewWithdrawDisabled} from "@src/ERC7540.sol";

import {BaseTest} from "./Base.sol";

contract TestMisc is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_previewDeposit() public {
        vm.expectRevert(ERC7540PreviewDepositDisabled.selector);
        vault.previewDeposit(0);
    }

    function test_previewWithdraw() public {
        vm.expectRevert(ERC7540PreviewWithdrawDisabled.selector);
        vault.previewWithdraw(0);
    }

    function test_previewMint() public {
        vm.expectRevert(ERC7540PreviewMintDisabled.selector);
        vault.previewMint(0);
    }

    function test_previewRedeem() public {
        vm.expectRevert(ERC7540PreviewRedeemDisabled.selector);
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
        assertEq(
            type(uint256).max,
            underlying.allowance(pendingSilo, address(vault))
        );
    }

    function test_supportsInterface() public view {
        assertTrue(
            vault.supportsInterface(0x2f0a18c5),
            "interface IERC7575 not supported"
        );
        assertTrue(
            vault.supportsInterface(0xf815c03d),
            "interface IERC7575 share not supported"
        );
        assertTrue(
            vault.supportsInterface(0xce3bbe50),
            "interface IERC7540Deposit not supported"
        );
        assertTrue(
            vault.supportsInterface(0x620ee8e4),
            "interface IERC7540Redeem not supported"
        );
        assertTrue(
            vault.supportsInterface(0xe3bc4e65),
            "interface IERC7540 not supported"
        );
        assertTrue(
            vault.supportsInterface(type(IERC165).interfaceId),
            "interface IERC165 not supported"
        );
    }
}
