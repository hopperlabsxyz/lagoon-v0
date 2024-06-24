// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault, IERC20} from "@src/Vault.sol";
import {BaseTest} from "./Base.t.sol";

contract TestFeeManager is BaseTest {

    function setUp() public {
    }

    function test_zero_bips() public view {
      assertEq(vault.managementFee(), 0);
      assertEq(vault.performanceFee(), 0);
      assertEq(vault.protocolFee(), 0);
    }

    function test_100_bips() public {
      setProtocolFee(100, address(this));
      setPerformanceFee(100, address(this));
      setManagementFee(100, address(this));

      assertEq(vault.managementFee(), 100);
      assertEq(vault.performanceFee(), 100);
      assertEq(vault.protocolFee(), 100);
    }
}
