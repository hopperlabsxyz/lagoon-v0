// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Silo} from "@src/vault0.1/Silo.sol";
import {Vault} from "@src/vault0.1/Vault.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";

contract TestSilo is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
    }

    function test_constructorGivesInfiniteApprovalToMsgSender() public {
        vm.prank(user1.addr);
        Silo silo = new Silo(underlying, address(0));
        uint256 allowance = underlying.allowance(address(silo), user1.addr);
        assertEq(allowance, type(uint256).max);
    }

    function test_vaultHasInfiniteApprovalOnPendingSilo() public view {
        uint256 allowance = underlying.allowance(vault.pendingSilo(), address(vault));
        assertEq(allowance, type(uint256).max);
    }
}
