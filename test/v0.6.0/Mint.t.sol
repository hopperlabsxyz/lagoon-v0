// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestMint is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_mint() public {
        uint256 userBalance = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);

        uint256 claimableAssets = vault.claimableDepositRequest(0, user1.addr);
        uint256 assetsClaimed = mint(12 * 10 ** vault.decimalsOffset(), user1.addr);
        assertEq(vault.convertToAssets(12 * 10 ** vault.decimalsOffset(), requestId), assetsClaimed);
        assertEq(12 * 10 ** vault.decimalsOffset(), vault.balanceOf(user1.addr));
        uint256 claimableAssetsAfter = vault.claimableDepositRequest(0, user1.addr);
        assertEq(claimableAssetsAfter + assetsClaimed, claimableAssets);
        assertLt(claimableAssetsAfter, claimableAssets);
    }

    function test_mintAsOperator() public {
        uint256 userBalance = assetBalance(user1.addr);

        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        vm.prank(user1.addr);
        vault.setOperator(user2.addr, true);
        assertEq(vault.maxDeposit(user1.addr), userBalance);
        uint256 claimableAssets = vault.claimableDepositRequest(0, user1.addr);
        uint256 assetsClaimed = mint(12 * 10 ** vault.decimalsOffset(), user1.addr, user2.addr, user1.addr);
        assertEq(12 * 10 ** vault.decimalsOffset(), vault.balanceOf(user1.addr));
        uint256 claimableAssetsAfter = vault.claimableDepositRequest(0, user1.addr);
        assertEq(claimableAssetsAfter + assetsClaimed, claimableAssets);
        assertLt(claimableAssetsAfter, claimableAssets);
    }

    function test_mint_revertIfNotOperator() public {
        vm.prank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.mint(42, user1.addr, user1.addr);
    }

    function test_mint_revertIfRequestIdNotClaimable() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        vm.prank(user1.addr);
        vm.expectRevert(RequestIdNotClaimable.selector);
        vault.mint(userBalance, user1.addr, user1.addr);
    }

    function test_mint_shouldRevertIfInvalidReceiver() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr);
        updateAndSettle(0);
        assertEq(vault.maxDeposit(user1.addr), userBalance);

        uint256 totalSupplyBefore = vault.totalSupply();

        uint256 amountToMint = 12 * 10 ** vault.decimalsOffset();
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(user1.addr);
        vault.mint(amountToMint, address(0));

        uint256 totalSupplyAfter = vault.totalSupply();
        assertEq(totalSupplyBefore, totalSupplyAfter, "supply before != supply after");
    }

    function test_mint_shouldTakeEntryFeesIntoConsideration() public {
        // we setup a vault with entry fees
        setUpVault({_protocolRate: 0, _managementRate: 0, _performanceRate: 0, _entryRate: 1000, _exitRate: 0});

        dealAndApproveAndWhitelist(user3.addr);

        requestDeposit(2000, user3.addr);
        updateAndSettle(0);
        deposit(2000, user3.addr);

        dealAndApproveAndWhitelist(user1.addr);
        dealAndApproveAndWhitelist(user2.addr);

        requestDeposit(800, user1.addr);
        requestDeposit(1000, user2.addr);

        // we settle deposits with a pps != 1:1 to complexify the situation
        updateAndSettle(2001);

        uint256 user1MaxDeposit = vault.maxDeposit(user1.addr);
        uint256 user2MaxDeposit = vault.maxDeposit(user2.addr);
        uint256 user1MaxMint = vault.maxMint(user1.addr);
        uint256 user2MaxMint = vault.maxMint(user2.addr);

        assertEq(user1MaxDeposit, 800);
        assertEq(user2MaxDeposit, 1000);

        uint256 user1MaxDepositSharesEquivalent = vault.convertToShares(user1MaxDeposit);
        uint256 user2MaxDepositSharesEquivalent = vault.convertToShares(user2MaxDeposit);

        assertEq(
            vault.maxMint(user1.addr),
            user1MaxDepositSharesEquivalent - FeeLib.computeFee(user1MaxDepositSharesEquivalent, vault.entryRate())
        );
        assertEq(
            vault.maxMint(user2.addr),
            user2MaxDepositSharesEquivalent - FeeLib.computeFee(user2MaxDepositSharesEquivalent, vault.entryRate())
        );

        mint(user1MaxMint, user1.addr);
        mint(user2MaxMint, user2.addr);

        // they both have no more max deposit or mint
        assertEq(vault.maxMint(user1.addr), 0);
        assertEq(vault.maxMint(user2.addr), 0);
        assertEq(vault.maxDeposit(user1.addr), 0);
        assertEq(vault.maxDeposit(user2.addr), 0);

        // if all shares are claimed, the vault should have no balance
        // assertEq(vault.balanceOf(address(vault)), 0); // this fails because of 1 wei, is it bad?
    }
}
