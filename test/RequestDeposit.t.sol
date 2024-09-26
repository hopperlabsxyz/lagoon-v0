// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CantDepositNativeToken, ERC7540InvalidOperator, OnlyOneRequestAllowed} from "@src/vault/ERC7540.sol";
import {Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";

contract TestRequestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
        whitelist(user1.addr);
        whitelist(user2.addr);
        whitelist(user3.addr);
    }

    function test_requestDeposit() public {
        uint256 userBalance = assetBalance(user1.addr);
        uint256 requestId = requestDeposit(userBalance, user1.addr);
        assertEq(vault.pendingDepositRequest(requestId, user1.addr), userBalance);
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDeposit_with_eth() public {
        uint256 userBalance = 10e18;
        string memory wtoken = "WRAPPED_NATIVE_TOKEN";
        bool shouldFail = keccak256(abi.encode(underlyingName)) != keccak256(abi.encode(wtoken));
        if (shouldFail) {
            vm.startPrank(user1.addr);
            vm.expectRevert(CantDepositNativeToken.selector);
            vault.requestDeposit{value: 1}(userBalance, user1.addr, user1.addr);
            vm.stopPrank();

            underlying = ERC20(WRAPPED_NATIVE_TOKEN);
            setUpVault(0, 0, 0);
            whitelist(user1.addr);
        }

        requestDeposit(userBalance, user1.addr, true);
        assertEq(assetBalance(address(vault)), 0);
        assertEq(assetBalance(address(vault.pendingSilo())), userBalance);
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDepositTwoTimes() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        assertEq(vault.pendingDepositRequest(vault.depositId(), user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDeposit_notEnoughBalance() public {
        uint256 userBalance = assetBalance(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.requestDeposit(userBalance + 1, user1.addr, user1.addr);
    }

    function test_requestDeposit_withClaimableBalance() public {
        uint256 userBalance = assetBalance(user1.addr);

        uint256 requestId_1 = requestDeposit(userBalance / 2, user1.addr);

        updateAndSettle(0);

        assertEq(requestId_1 + 2, vault.depositId(), "wrong deposit id");
        assertEq(
            vault.lastDepositRequestId_debug(user1.addr), // keep track of the last deposit id of the user, only one
            // requestId is allowed by settle period by user
            requestId_1,
            "wrong internal lastDepositRequestId"
        );
        assertEq(vault.lastDepositEpochIdSettled_debug(), requestId_1, "wrong internal lastDepositTotalAssetsIdSettle");

        assertEq(vault.maxDeposit(user1.addr), userBalance / 2, "wrong claimable deposit value");

        assertEq(vault.balanceOf(address(vault)), userBalance / 2, "wrong amount of claimable shares");

        requestDeposit(userBalance / 2, user1.addr);

        assertEq(vault.maxDeposit(user1.addr), 0, "wrong claimable deposit value");
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance / 2, "wrong pending deposit value");

        // we automatically claim for the user if he has claimable shares
        assertEq(vault.balanceOf(user1.addr), userBalance / 2, "wrong shares balance");
    }

    // @dev Once one of the request of the user has been taken into a TotalAssets
    //      he has to wait for settlement before being able to request again
    function test_only_one_request_allowed_per_settle_id() public {
        uint256 userBalance = assetBalance(user1.addr);

        requestDeposit(userBalance / 2, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(OnlyOneRequestAllowed.selector);
        vault.requestDeposit(userBalance / 2, user1.addr, user1.addr);
    }

    function test_requestDeposit_withClaimableBalance_with_eth() public {
        uint256 userBalance = 10e18;
        string memory wtoken = "WRAPPED_NATIVE_TOKEN";

        bool shouldWork = keccak256(abi.encode(underlyingName)) == keccak256(abi.encode(wtoken));
        if (shouldWork) {
            requestDeposit(userBalance / 2, user1.addr);
            updateAndSettle(0);
            assertEq(vault.maxDeposit(user1.addr), userBalance / 2, "wrong claimable deposit value");
            requestDeposit(userBalance / 2, user1.addr, true);
            assertEq(vault.maxDeposit(user1.addr), 0, "wrong claimable deposit value");
            assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance / 2, "wrong pending deposit value");
            assertEq(vault.balanceOf(user1.addr), userBalance / 2, "wrong shares balance");
        }
    }

    function test_requestDeposit_asAnOperator() public {
        address owner = user1.addr;
        address operator = user2.addr;
        address controller = user3.addr;

        uint256 ownerBalance = assetBalance(owner);
        uint256 operatorBalance = assetBalance(operator);
        uint256 controllerBalance = assetBalance(controller);
        vm.prank(owner);
        vault.setOperator(operator, true);
        requestDeposit(ownerBalance, controller, owner, operator);
        assertEq(operatorBalance, assetBalance(operator), "operator balance should not change");
        assertEq(controllerBalance, assetBalance(controller), "controller balance should not change");
        assertEq(
            ownerBalance,
            vault.pendingDepositRequest(0, controller),
            "owner balance should be the controller pending deposit request"
        );
        assertEq(assetBalance(owner), 0, "owner balance should be 0");
    }

    function test_requestDeposit_asAnOperatorNotAllowed() public {
        address owner = user1.addr;
        address operator = user2.addr;
        address controller = user3.addr;
        uint256 ownerBalance = assetBalance(owner);
        vm.startPrank(operator);
        vm.expectRevert();
        vault.requestDeposit(ownerBalance, controller, owner);
    }

    function test_requestDeposit_asAnOperatorButOwnerNotEnoughApprove() public {
        address owner = user2.addr;
        address operator = user1.addr;
        address controller = user3.addr;
        uint256 ownerBalance = assetBalance(owner);
        vm.prank(owner);
        vault.setOperator(operator, true);
        vm.startPrank(operator);
        // vm.expectRevert();
        vault.requestDeposit(ownerBalance, controller, owner);
    }

    function test_requestDeposit_revertIfNotOperator() public {
        vm.prank(user2.addr);
        vm.expectRevert(ERC7540InvalidOperator.selector);
        vault.requestDeposit(42, user1.addr, user1.addr);
    }

    function test_requestDeposit_ShouldBeAbleToDepositAgainWhenIndeterminationIsRaidedAtSettlement() public {
        vm.prank(user1.addr);
        vault.requestDeposit(42, user1.addr, user1.addr);

        vm.prank(user1.addr);
        vault.requestDeposit(42, user1.addr, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(OnlyOneRequestAllowed.selector);
        vault.requestDeposit(42, user1.addr, user1.addr);

        settle();

        vm.prank(user1.addr);
        vault.requestDeposit(42, user1.addr, user1.addr);
    }
}
