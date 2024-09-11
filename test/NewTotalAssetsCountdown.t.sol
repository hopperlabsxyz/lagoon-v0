// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.sol";

contract TestDeposit is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_initialCountdownIs0() public view {
        assertEq(vault.newTotalAssetsCountdown(), 0);
    }

    function test_countdownStartAndChangeOverTimeAfterNavupdate() public {
        updateTotalAssets(0);
        assertEq(
            vault.newTotalAssetsCountdown(),
            1 days,
            "wrong initial countdown"
        );
        vm.warp(block.timestamp + (1 days / 2));
        assertEq(
            vault.newTotalAssetsCountdown(),
            1 days / 2,
            "countdown does not change over time"
        );
        vm.warp(block.timestamp + 1 days);
        assertEq(
            vault.newTotalAssetsCountdown(),
            0,
            "final countdown is wrong"
        );
    }
}
