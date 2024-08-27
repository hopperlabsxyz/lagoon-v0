// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {IERC4626, IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseTest} from "../Base.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {FeeRegistry} from "@src/FeeRegistry.sol";

contract TestFeeRegistry is BaseTest {
    address mockVault = address(0x1);

    function setUp() public {
        feeRegistry = new FeeRegistry();
        feeRegistry.initialize(dao.addr, dao.addr);
    }

    function test_init() public view {
        assertEq(dao.addr, feeRegistry.owner());
    }

    function test_protocolRate() public {
        vm.prank(dao.addr);
        feeRegistry.setProtocolRate(200);

        vm.prank(mockVault);
        uint256 protocolRate = feeRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        assertEq(
            feeRegistry.protocolRate(mockVault),
            200,
            "Unexpected protocolRate(addres)"
        );
        assertEq(
            feeRegistry.isCustomRate(mockVault),
            false,
            "Unexpected isCustomRate(address)"
        );
        assertEq(
            feeRegistry.customRate(mockVault),
            0,
            "Unexpected customRate(address)"
        );
    }

    function test_customRate() public {
        vm.startPrank(dao.addr);
        feeRegistry.setProtocolRate(300);
        feeRegistry.setCustomRate(mockVault, 200);
        vm.stopPrank();

        vm.prank(mockVault);
        uint256 protocolRate = feeRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        assertEq(
            feeRegistry.protocolRate(mockVault),
            200,
            "Unexpected protocolRate(address)"
        );
        assertEq(
            feeRegistry.protocolRate(),
            300,
            "Unexpected protocolRate(void)"
        );
        assertEq(
            feeRegistry.isCustomRate(mockVault),
            true,
            "Unexpected isCustomRate(void)"
        );
        assertEq(
            feeRegistry.customRate(mockVault),
            200,
            "Unexpected customeRate(address)"
        );
    }

    function test_cancelCustomRate() public {
        vm.startPrank(dao.addr);
        feeRegistry.setProtocolRate(300);
        feeRegistry.setCustomRate(mockVault, 200);
        vm.stopPrank();

        vm.prank(mockVault);
        uint256 protocolRate = feeRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        vm.prank(dao.addr);
        feeRegistry.cancelCustomRate(mockVault);

        vm.prank(mockVault);
        protocolRate = feeRegistry.protocolRate();

        assertEq(protocolRate, 300, "Unexpected protocolRate(void)");

        assertEq(
            feeRegistry.protocolRate(mockVault),
            300,
            "Unexpected protocolRate(addres)"
        );
        assertEq(
            feeRegistry.isCustomRate(mockVault),
            false,
            "Unexpected isCustomRate(address)"
        );
        assertEq(
            feeRegistry.customRate(mockVault),
            200,
            "Unexpected customRate(address)"
        );
    }
}
