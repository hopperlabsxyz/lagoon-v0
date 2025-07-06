// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {BaseTest} from "../Base.sol";
import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol-v1/FeeRegistry.sol";

contract TestFeeRegistry is BaseTest {
    address mockVault = address(0x1);

    function setUp() public {
        feeRegistry = new FeeRegistry(false);
        feeRegistry.initialize(dao.addr, dao.addr);
    }

    function test_init() public view {
        assertEq(dao.addr, feeRegistry.owner());
    }

    function test_protocolRate() public {
        vm.prank(dao.addr);
        feeRegistry.updateDefaultRate(200);

        vm.prank(mockVault);
        uint256 protocolRate = feeRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        assertEq(feeRegistry.protocolRate(mockVault), 200, "Unexpected protocolRate(addres)");
        assertEq(feeRegistry.isCustomRate(mockVault), false, "Unexpected isCustomRate(address)");
    }

    function test_customRate() public {
        vm.startPrank(dao.addr);

        feeRegistry.updateDefaultRate(300);
        feeRegistry.updateCustomRate(mockVault, 200, true);
        vm.stopPrank();

        vm.prank(mockVault);
        uint256 protocolRate = feeRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        assertEq(feeRegistry.protocolRate(mockVault), 200, "Unexpected protocolRate(address)");
        assertEq(feeRegistry.protocolRate(), 300, "Unexpected protocolRate(void)");
        assertEq(feeRegistry.isCustomRate(mockVault), true, "Unexpected isCustomRate(void)");
    }

    function test_cancelCustomRate() public {
        vm.startPrank(dao.addr);
        feeRegistry.updateDefaultRate(300);
        feeRegistry.updateCustomRate(mockVault, 200, true);

        vm.stopPrank();

        vm.prank(mockVault);
        uint256 protocolRate = feeRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        vm.prank(dao.addr);
        feeRegistry.updateCustomRate(mockVault, 0, false);

        vm.prank(mockVault);
        protocolRate = feeRegistry.protocolRate();

        assertEq(protocolRate, 300, "Unexpected protocolRate(void)");

        assertEq(feeRegistry.protocolRate(mockVault), 300, "Unexpected protocolRate(addres)");
        assertEq(feeRegistry.isCustomRate(mockVault), false, "Unexpected isCustomRate(address)");
    }

    function test_updateProtocolFeeReceiver() public {
        vm.prank(dao.addr);
        feeRegistry.updateProtocolFeeReceiver(address(0x42));
        assertEq(feeRegistry.protocolFeeReceiver(), address(0x42));
    }

    function test_updateProtocolFeeReceiver_revertIfNotOwner() public {
        vm.expectRevert();
        feeRegistry.updateProtocolFeeReceiver(address(0x42));
    }
}
