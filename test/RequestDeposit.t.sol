// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";
import {CantDepositNativeToken} from "@src/ERC7540.sol";

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
        requestDeposit(userBalance, user1.addr);
        assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
        assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
    }

    function test_requestDeposit_with_eth() public {
        uint256 userBalance = 10e18;
        string memory wtoken = "WRAPPED_NATIVE_TOKEN";
        bool shouldFail = keccak256(abi.encode(underlyingName)) !=
            keccak256(abi.encode(wtoken));
        if (!shouldFail) {
            requestDeposit(userBalance, user1.addr, true);
            assertEq(assetBalance(address(vault)), 0);
            assertEq(assetBalance(address(vault.pendingSilo())), userBalance);
            assertEq(vault.pendingDepositRequest(0, user1.addr), userBalance);
            assertEq(vault.claimableRedeemRequest(0, user1.addr), 0);
        }
    }

    function test_requestDepositTwoTimes() public {
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        requestDeposit(userBalance / 2, user1.addr);
        assertEq(
            vault.pendingDepositRequest(vault.depositId(), user1.addr),
            userBalance
        );
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
        requestDeposit(userBalance / 2, user1.addr);
        updateAndSettle(0);
        assertEq(
            vault.maxDeposit(user1.addr),
            userBalance / 2,
            "wrong claimable deposit value"
        );
        requestDeposit(userBalance / 2, user1.addr);
        assertEq(
            vault.maxDeposit(user1.addr),
            0,
            "wrong claimable deposit value"
        );
        assertEq(
            vault.pendingDepositRequest(0, user1.addr),
            userBalance / 2,
            "wrong pending deposit value"
        );
        assertEq(
            vault.balanceOf(user1.addr),
            userBalance / 2,
            "wrong shares balance"
        );
    }

    function test_requestDeposit_withClaimableBalance_with_eth() public {
        uint256 userBalance = 10e18;
        string memory wtoken = "WRAPPED_NATIVE_TOKEN";

        bool shouldFail = keccak256(abi.encode(underlyingName)) !=
            keccak256(abi.encode(wtoken));
        if (!shouldFail) {
            requestDeposit(userBalance / 2, user1.addr);
            updateAndSettle(0);
            assertEq(
                vault.maxDeposit(user1.addr),
                userBalance / 2,
                "wrong claimable deposit value"
            );
            requestDeposit(userBalance / 2, user1.addr, true);
            assertEq(
                vault.maxDeposit(user1.addr),
                0,
                "wrong claimable deposit value"
            );
            assertEq(
                vault.pendingDepositRequest(0, user1.addr),
                userBalance / 2,
                "wrong pending deposit value"
            );
            assertEq(
                vault.balanceOf(user1.addr),
                userBalance / 2,
                "wrong shares balance"
            );
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
        assertEq(
            operatorBalance,
            assetBalance(operator),
            "operator balance should not change"
        );
        assertEq(
            controllerBalance,
            assetBalance(controller),
            "controller balance should not change"
        );
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
}
