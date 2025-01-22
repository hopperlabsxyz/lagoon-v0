// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";

contract TestPause is BaseTest {
    uint256 amount = 200 * 10 ** underlying.decimals();

    function setUp() public {
        setUpVault(0, 0, 0);

        dealAmountAndApproveAndWhitelist(user1.addr, amount);
        requestDeposit(amount / 2, user1.addr);
        updateAndSettle(0);
        vm.prank(vault.owner());
        vault.pause();
    }

    function test_pauseShouldPause() public view {
        assertTrue(vault.paused());
    }

    function test_unpauseShouldUnpause() public {
        vm.prank(vault.owner());

        vault.unpause();
        assertFalse(vault.paused());
    }

    function test_setOperator_whenPaused_shouldFail() public {
        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.setOperator(user1.addr, true);
    }

    function test_requestDeposit_whenPaused_shouldFail() public {
        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.requestDeposit(amount, user1.addr, user1.addr);

        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.requestDeposit(amount, user1.addr, user1.addr);
    }

    function test_deposit_whenPaused_shouldFail() public {
        vm.assertNotEq(vault.claimableDepositRequest(0, user1.addr), 0);

        vm.startPrank(user1.addr);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.deposit(1, user1.addr);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.deposit(1, user1.addr, user1.addr);
    }

    function test_mint_whenPaused_shouldFail() public {
        vm.assertNotEq(vault.claimableDepositRequest(0, user1.addr), 0);
        vm.startPrank(user1.addr);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.mint(1, user1.addr);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.mint(1, user1.addr, user1.addr);
    }

    function test_cancelRequestDeposit_whenPaused_shouldFail() public {
        vm.prank(vault.owner());
        vault.unpause();

        vm.prank(user1.addr);
        vault.requestDeposit(10, user1.addr, user1.addr);

        vm.prank(vault.owner());
        vault.pause();

        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.cancelRequestDeposit();
    }

    function test_requestRedeem_whenPaused_shouldFail() public {
        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.requestRedeem(2, user1.addr, user1.addr);

        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.requestRedeem(2, user1.addr, user1.addr);
    }

    function test_withdraw_whenPaused_shouldFail() public {
        vm.prank(vault.owner());
        vault.unpause();

        vm.startPrank(user1.addr);
        vault.deposit(vault.maxDeposit(user1.addr), user1.addr);
        vault.requestRedeem(1 * 10 ** vault.decimals(), user1.addr, user1.addr);
        vm.stopPrank();

        updateAndSettle(vault.totalAssets());

        vm.prank(vault.owner());
        vault.pause();

        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.withdraw(10, user1.addr, user1.addr);
    }

    function test_withdraw_whenPausedAndVaultClosed_shouldFail() public {
        vm.prank(vault.owner());
        vault.unpause();

        vm.startPrank(user1.addr);
        vault.deposit(vault.maxDeposit(user1.addr), user1.addr);
        vault.requestRedeem(1 * 10 ** vault.decimals(), user1.addr, user1.addr);

        vm.stopPrank();
        updateAndSettle(vault.totalAssets());

        updateNewTotalAssets(vault.totalAssets());

        vm.prank(vault.owner());
        vault.initiateClosing();

        dealAmountAndApprove(vault.safe(), vault.totalAssets());
        vm.startPrank(vault.safe());
        vault.close(vault.newTotalAssets());
        vm.stopPrank();

        vm.prank(vault.owner());
        vault.pause();

        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.withdraw(10, user1.addr, user1.addr);
    }

    function test_updateNewTotalAssets_whenPaused_shouldFail() public {
        uint256 _totalAssets = vault.totalAssets();

        vm.prank(vault.valuationManager());
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.updateNewTotalAssets(_totalAssets);
    }

    function test_settleDeposit_whenPaused_shouldFail() public {
        vm.prank(vault.owner());
        vault.unpause();

        uint256 _totalAssets = vault.totalAssets();
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(_totalAssets);

        vm.prank(vault.owner());
        vault.pause();

        vm.prank(vault.safe());
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.settleDeposit(1);
    }

    function test_settleRedeem_whenPaused_shouldFail() public {
        vm.prank(vault.owner());
        vault.unpause();

        uint256 _totalAssets = vault.totalAssets();
        vm.prank(vault.valuationManager());
        vault.updateNewTotalAssets(_totalAssets);

        vm.prank(vault.owner());
        vault.pause();

        vm.prank(vault.safe());
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.settleRedeem(1);
    }

    function test_claimSharesAndRequestRedeem_whenPaused_shouldFail() public {
        vm.prank(user1.addr);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.claimSharesAndRequestRedeem(2);
    }
}
