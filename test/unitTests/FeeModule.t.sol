// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";

import {FeeModule} from "@src/FeeModule.sol";

uint256 constant BPS = 10_000;
uint256 constant EXIT_RATE = 100; // 1 %
uint256 constant ENTRY_RATE = 100; // 1 %
uint256 constant MANAGEMENT_RATE = 200; // 2 %
uint256 constant PERFORMANCE_RATE = 2000; // 20 %

contract TestImmutableTest is Test {
    FeeModule fee;

    function setUp() public {
        fee = new FeeModule(
            BPS,
            EXIT_RATE,
            ENTRY_RATE,
            MANAGEMENT_RATE,
            PERFORMANCE_RATE
        );
    }

    function test_constructor() public view {
        assertEq(fee.managementRate(), MANAGEMENT_RATE);
        assertEq(fee.performanceRate(), PERFORMANCE_RATE);
        assertEq(fee.entryRate(), ENTRY_RATE);
        assertEq(fee.exitRate(), EXIT_RATE);
        assertEq(fee.bps(), BPS);
    }

    function test_calculateManagementFee() public {}
}
