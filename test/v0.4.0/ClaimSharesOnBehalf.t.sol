// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_claimSharesOnBehalf() public {
        uint256 userBalance = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);

        address[] memory controllers = new address[](1);

        controllers[0] = user1.addr;
        vm.prank(safe.addr);
        vault.claimSharesOnBehalf(controllers);

        uint256 shares = vault.convertToShares(userBalance, requestId);

        assertEq(shares, vault.balanceOf(user1.addr));
        assertEq(shares, userBalance * 10 ** vault.decimalsOffset());
    }

    function test_deposit_revertIfNotOperator() public {
        vm.prank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.deposit(42, user1.addr, user1.addr);
    }

    function test_deposit_revertIfRequestIdNotClaimable() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        vm.prank(user1.addr);
        vm.expectRevert(RequestIdNotClaimable.selector);
        vault.deposit(userBalance, user1.addr, user1.addr);
    }

    function test_deposit_shouldRevertIfInvalidReceiver() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 totalSupplyBefore = vault.totalSupply();
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        vm.prank(user1.addr);
        vault.deposit(userBalance, address(0));
        uint256 totalSupplyAfter = vault.totalSupply();
        assertEq(
            totalSupplyBefore,
            totalSupplyAfter,
            "supply before != supply after"
        );
    }
}
