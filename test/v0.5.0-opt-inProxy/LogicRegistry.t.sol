// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {BaseTest} from "./Base.sol";

import {ILogicRegistry} from "@src/protocol-v2/ILogicRegistry.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {LogicRegistry, ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";

import {Test} from "forge-std/Test.sol";

import {console} from "forge-std/console.sol";

contract LogicRegistryTest is BaseTest {
    ProtocolRegistry public logicRegistry;
    address public nonOwner = address(0x2);
    address public logic1 = address(0x10);
    address public logic2 = address(0x11);
    address public logic3 = address(0x12);

    function setUp() public {
        logicRegistry = new ProtocolRegistry(false);
        logicRegistry.initialize(owner.addr, owner.addr);
        console.log(logicRegistry.owner());
    }

    function test_Initialization() public view {
        assertEq(logicRegistry.owner(), owner.addr);
        assertEq(address(logicRegistry.defaultLogic()), address(0));
    }

    function test_AddLogic() public {
        vm.startPrank(owner.addr);

        vm.expectEmit(true, false, false, false, address(logicRegistry));
        emit ILogicRegistry.LogicAdded(logic1);

        logicRegistry.addLogic(logic1);

        assertTrue(logicRegistry.canUseLogic(address(0), logic1));
        vm.stopPrank();
    }

    function test_AddLogic_RevertIfNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));

        logicRegistry.addLogic(logic1);
        vm.stopPrank();
    }

    function test_RemoveLogic() public {
        vm.startPrank(owner.addr);
        logicRegistry.addLogic(logic1);

        vm.expectEmit(true, true, true, true, address(logicRegistry));
        emit ILogicRegistry.LogicRemoved(logic1);
        logicRegistry.removeLogic(logic1);

        assertFalse(logicRegistry.canUseLogic(address(0), logic1));
        vm.stopPrank();
    }

    function test_RemoveLogic_RevertIfNotOwner() public {
        vm.startPrank(owner.addr);
        logicRegistry.addLogic(logic1);
        vm.stopPrank();

        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));

        logicRegistry.removeLogic(logic1);
        vm.stopPrank();
    }

    function test_UpdateDefaultLogic() public {
        vm.startPrank(owner.addr);
        logicRegistry.addLogic(logic1);

        vm.expectEmit(true, true, true, true);
        emit ILogicRegistry.DefaultLogicUpdated(address(0), logic1);
        logicRegistry.updateDefaultLogic(logic1);

        assertEq(logicRegistry.defaultLogic(), logic1);
        vm.stopPrank();
    }

    function test_UpdateDefaultLogic_AddsLogicIfNotWhitelisted() public {
        vm.startPrank(owner.addr);

        vm.expectEmit(true, true, true, true);
        emit ILogicRegistry.LogicAdded(logic1);

        vm.expectEmit(true, true, true, true);
        emit ILogicRegistry.DefaultLogicUpdated(address(0), logic1);

        logicRegistry.updateDefaultLogic(logic1);

        assertEq(logicRegistry.defaultLogic(), logic1);
        assertTrue(logicRegistry.canUseLogic(address(0), logic1));
        vm.stopPrank();
    }

    function test_UpdateDefaultLogic_RevertIfNotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));

        logicRegistry.updateDefaultLogic(logic1);
        vm.stopPrank();
    }

    function test_CanUseLogic() public {
        vm.startPrank(owner.addr);
        logicRegistry.addLogic(logic1);
        logicRegistry.addLogic(logic2);
        logicRegistry.removeLogic(logic2);

        assertTrue(logicRegistry.canUseLogic(address(0), logic1));
        assertFalse(logicRegistry.canUseLogic(address(0), logic2));
        assertFalse(logicRegistry.canUseLogic(address(0), logic3));
        vm.stopPrank();
    }

    function test_DefaultLogic() public {
        vm.startPrank(owner.addr);
        logicRegistry.addLogic(logic1);
        logicRegistry.updateDefaultLogic(logic1);

        assertEq(logicRegistry.defaultLogic(), logic1);
        vm.stopPrank();
    }
}
