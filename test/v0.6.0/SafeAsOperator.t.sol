// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Here are the various situations to test:
// [x] requestDeposit() for pfr. Gave up. should revert
// [x] requestDepositWithReferral() for pfr. Gave up. should revert
// [x] requestRedeem() for pfr. Gave up. should revert
// [x] deposit() for pfr. Gave up. should revert
// [x] mint() for pfr. Gave up. should revert
// [x] redeem() for pfr. Gave up. should revert
// [x] withdraw() for pfr. Gave up. should revert
// [x] requestDeposit() for pfr. should revert
// [x] requestDepositWithReferral() for pfr. should revert
// [x] requestRedeem() for pfr. should revert
// [x] deposit() for pfr. should revert
// [x] mint() for pfr. should revert
// [x] redeem() for pfr. should revert
// [x] withdraw() for pfr. should revert
// [x] requestDeposit() for user. Gave up. should revert
// [x] requestDepositWithReferral() for user. Gave up. should revert
// [x] requestRedeem() for user. Gave up. should succeed
// [x] deposit() for user. Gave up. should succeed
// [x] mint() for user. Gave up. should succeed
// [x] redeem() for user. Gave up. should succeed
// [x] withdraw() for user. Gave up. should succeed
// [x] requestDeposit() for user. should revert
// [x] requestDepositWithReferral() for user. should revert
// [x] requestRedeem() for user. should succeed
// [x] deposit() for user. should succeed
// [x] mint() for user. should succeed
// [x] redeem() for user. should succeed
// [x] withdraw() for user. should succeed

contract TestSafeAsOperator is BaseTest {
    address protocolFeeReceiver;

    function setUp() public {
        setUpVault(0, 0, 0);
        protocolFeeReceiver = vault.protocolFeeReceiver();
        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);
        dealAndApproveAndWhitelist(user3.addr);
        dealAndApproveAndWhitelist(user4.addr);
        dealAndApproveAndWhitelist(user5.addr);
        dealAndApproveAndWhitelist(user6.addr);
        dealAndApproveAndWhitelist(protocolFeeReceiver);
    }

    function test_giveUpOperatorPrivileges_onlyOwner() public {
        vm.prank(user1.addr);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user1.addr));
        vault.giveUpOperatorPrivileges();
    }

    function test_safeAsOperator_afterGivingUpOperatorPrivileges_shouldRevert() public {
        // owner decides to give up this right
        assertFalse(vault.gaveUpOperatorPrivileges(), "gaveUpOperatorPrivileges should be false");
        vm.prank(vault.owner());
        vault.giveUpOperatorPrivileges();
        assertTrue(vault.gaveUpOperatorPrivileges(), "gaveUpOperatorPrivileges should be true");

        _callAllFunctionsExpectRevert(user2.addr, user2.addr);
    }

    function test_safeAsOperator_forProtocolFeeReceiver_shouldRevert() public {
        _callAllFunctionsExpectRevert(protocolFeeReceiver, protocolFeeReceiver);

        vm.prank(vault.owner());
        vault.giveUpOperatorPrivileges();
        _callAllFunctionsExpectRevert(protocolFeeReceiver, protocolFeeReceiver);
    }

    function test_safeAsOperator_forUser() public {
        requestDeposit(100 * 10 ** vault.underlyingDecimals(), user2.addr);
        updateAndSettle(0);

        vm.prank(user2.addr);
        vault.claimSharesAndRequestRedeem(50 * 10 ** decimals);
        requestDeposit(100 * 10 ** vault.underlyingDecimals(), user2.addr);
        updateAndSettle(100);

        _callAllFunctionsExpectSuccess(user2.addr, user2.addr);

        address operator = safe.addr;
        address controller = user2.addr;
        vm.prank(operator);
        vault.requestDeposit(100, controller, controller);

        vm.prank(operator);
        vault.requestDeposit(100, controller, controller, controller);
    }

    // since onlyOperator is called at the begining we can bulk test all functions that should revert
    function _callAllFunctionsExpectRevert(
        address controller,
        address referral
    ) public {
        address operator = safe.addr;
        vm.prank(operator);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.requestDeposit(100, controller, controller);

        vm.prank(operator);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.requestDeposit(100, controller, controller, referral);

        vm.prank(operator);
        // in the case of requestRedeem, if the msg.sender is not an operator, the contract will try to spend the
        // allowance of controller -> operator
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, operator, 0, 100));
        vault.requestRedeem(100, controller, controller);

        vm.prank(operator);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.deposit(100, controller, controller);

        vm.prank(operator);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.mint(100, controller, controller);

        vm.prank(operator);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.redeem(100, controller, controller);

        vm.prank(operator);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.withdraw(100, controller, controller);
    }

    function _callAllFunctionsExpectSuccess(
        address operator,
        address controller
    ) public {
        vm.prank(operator);
        vault.redeem(1, controller, controller);

        vm.prank(operator);
        vault.withdraw(1, controller, controller);

        vm.prank(operator);
        vault.requestRedeem(1, controller, controller);

        vm.prank(operator);
        vault.deposit(1, controller, controller);

        vm.prank(operator);
        vault.mint(1, controller, controller);
    }
}

