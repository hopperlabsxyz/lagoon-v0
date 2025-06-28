// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {BaseTest} from "../Base.sol";
import {IERC20Metadata, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ProtocolRegistry} from "@src/protocol-v0.2.0/protocolRegistry.sol";

contract TestprotocolRegistry is BaseTest {
    address mockVault = address(0x1);

    function setUp() public {
        protocolRegistry = new ProtocolRegistry(false);
        protocolRegistry.initialize(dao.addr, dao.addr);
        vm.prank(dao.addr);
        protocolRegistry.addLogic("V0", implementation);
    }

    function test_init() public view {
        assertEq(dao.addr, protocolRegistry.owner());
    }

    function test_protocolRate() public {
        vm.prank(dao.addr);
        protocolRegistry.updateDefaultRate(200);

        vm.prank(mockVault);
        uint256 protocolRate = protocolRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        assertEq(protocolRegistry.protocolRate(mockVault), 200, "Unexpected protocolRate(addres)");
        assertEq(protocolRegistry.isCustomRate(mockVault), false, "Unexpected isCustomRate(address)");
    }

    function test_customRate() public {
        vm.startPrank(dao.addr);

        protocolRegistry.updateDefaultRate(300);
        protocolRegistry.updateCustomRate(mockVault, 200, true);
        vm.stopPrank();

        vm.prank(mockVault);
        uint256 protocolRate = protocolRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        assertEq(protocolRegistry.protocolRate(mockVault), 200, "Unexpected protocolRate(address)");
        assertEq(protocolRegistry.protocolRate(), 300, "Unexpected protocolRate(void)");
        assertEq(protocolRegistry.isCustomRate(mockVault), true, "Unexpected isCustomRate(void)");
    }

    function test_cancelCustomRate() public {
        vm.startPrank(dao.addr);
        protocolRegistry.updateDefaultRate(300);
        protocolRegistry.updateCustomRate(mockVault, 200, true);

        vm.stopPrank();

        vm.prank(mockVault);
        uint256 protocolRate = protocolRegistry.protocolRate();
        assertEq(protocolRate, 200, "Unexpected protocolRate(void)");

        vm.prank(dao.addr);
        protocolRegistry.updateCustomRate(mockVault, 0, false);

        vm.prank(mockVault);
        protocolRate = protocolRegistry.protocolRate();

        assertEq(protocolRate, 300, "Unexpected protocolRate(void)");

        assertEq(protocolRegistry.protocolRate(mockVault), 300, "Unexpected protocolRate(addres)");
        assertEq(protocolRegistry.isCustomRate(mockVault), false, "Unexpected isCustomRate(address)");
    }

    function test_updateProtocolFeeReceiver() public {
        vm.prank(dao.addr);
        protocolRegistry.updateProtocolFeeReceiver(address(0x42));
        assertEq(protocolRegistry.protocolFeeReceiver(), address(0x42));
    }

    function test_updateProtocolFeeReceiver_revertIfNotOwner() public {
        vm.expectRevert();
        protocolRegistry.updateProtocolFeeReceiver(address(0x42));
    }
}
