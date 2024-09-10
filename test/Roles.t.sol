// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

contract TestMint is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
    }

    function test_whitelistManager() public view {
        assertEq(vault.whitelistManager(), whitelistManager.addr);
    }

    function test_feeReceiver() public view {
        assertEq(vault.feeReceiver(), feeReceiver.addr);
    }

    function test_protocolFeeReceiver() public view {
        assertEq(vault.protocolFeeReceiver(), dao.addr);
    }

    function test_safe() public view {
        assertEq(vault.safe(), safe.addr);
    }

    function test_valorizationManager() public view {
        assertEq(vault.valorizationManager(), valorizator.addr);
    }

    function test_feeRegistry() public view {
        assertEq(vault.feeRegistry(), address(feeRegistry));
    }

    function test_updateWhitelistManager() public {
        vm.prank(vault.owner());
        vault.updateWhitelistManager(address(0x42));

        assertEq(vault.whitelistManager(), address(0x42));
    }

    function test_updateFeeReceiver() public {
        vm.prank(vault.owner());
        vault.updateFeeReceiver(address(0x42));

        assertEq(vault.feeReceiver(), address(0x42));
    }
}
