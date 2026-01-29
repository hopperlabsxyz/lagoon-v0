// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {DelayProxyAdmin} from "@src/proxy/DelayProxyAdmin.sol";
import {LagoonVault} from "@src/proxy/OptinProxy.sol";

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Test.sol";

contract DelayProxyAdminTest is Test {
    DelayProxyAdmin public proxyAdmin;
    address public owner = address(0x1);
    address public nonOwner = address(0x2);
    uint256 public initialDelay = 2 days;
    uint256 MIN_DELAY;
    uint256 MAX_DELAY;

    function setUp() public {
        vm.prank(owner);
        proxyAdmin = new DelayProxyAdmin(owner, initialDelay);
        MIN_DELAY = proxyAdmin.MIN_DELAY();
        MAX_DELAY = proxyAdmin.MAX_DELAY();
    }

    // Test constructor
    function test_Constructor_SetsOwner() public view {
        assertEq(proxyAdmin.owner(), owner);
    }

    function test_Constructor_SetsInitialDelay() public view {
        assertEq(proxyAdmin.delay(), initialDelay);
    }

    function test_Constructor_RevertsIfDelayTooLow() public {
        vm.expectRevert(abi.encodeWithSelector(DelayProxyAdmin.DelayTooLow.selector, MIN_DELAY));
        new DelayProxyAdmin(owner, MIN_DELAY - 1);
    }

    function test_Constructor_RevertsIfDelayTooHigh() public {
        vm.expectRevert(abi.encodeWithSelector(DelayProxyAdmin.DelayTooHigh.selector, MAX_DELAY));
        new DelayProxyAdmin(owner, MAX_DELAY + 1);
    }

    // Test submitDelay
    function test_SubmitDelay_UpdatesNewDelayAndDelayUpdateTime() public {
        uint256 newDelay = 3 days;
        vm.prank(owner);
        proxyAdmin.submitDelay(newDelay);

        assertEq(proxyAdmin.newDelay(), newDelay);
        assertEq(proxyAdmin.delayUpdateTime(), block.timestamp + initialDelay);
    }

    function test_SubmitDelay_EmitsEvent() public {
        uint256 newDelay = 3 days;
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DelayProxyAdmin.DelayUpdateSubmited(initialDelay, newDelay, block.timestamp + initialDelay);
        proxyAdmin.submitDelay(newDelay);
    }

    function test_SubmitDelay_RevertsIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        proxyAdmin.submitDelay(3 days);
    }

    function test_SubmitDelay_RevertsIfDelayTooLow() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(DelayProxyAdmin.DelayTooLow.selector, MIN_DELAY));
        proxyAdmin.submitDelay(MIN_DELAY - 1);
    }

    function test_SubmitDelay_RevertsIfDelayTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(DelayProxyAdmin.DelayTooHigh.selector, MAX_DELAY));
        proxyAdmin.submitDelay(MAX_DELAY + 1);
    }

    // Test updateDelay
    function test_UpdateDelay_UpdatesDelay() public {
        uint256 newDelay = 3 days;
        vm.prank(owner);
        proxyAdmin.submitDelay(newDelay);

        vm.warp(block.timestamp + initialDelay + 1);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DelayProxyAdmin.DelayUpdated(newDelay, initialDelay);
        proxyAdmin.updateDelay();

        assertEq(proxyAdmin.delay(), newDelay);
    }

    function test_UpdateDelay_RevertsIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        proxyAdmin.updateDelay();
    }

    function test_UpdateDelay_RevertsIfDelayNotOver() public {
        uint256 newDelay = 3 days;
        vm.prank(owner);
        proxyAdmin.submitDelay(newDelay);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(DelayProxyAdmin.DelayIsNotOver.selector));
        proxyAdmin.updateDelay();
    }

    // Test submitImplementation
    function test_SubmitImplementation_UpdatesImplementationAndUpdateTime() public {
        address newImplementation = address(0x123);
        vm.prank(owner);
        proxyAdmin.submitImplementation(newImplementation);

        assertEq(proxyAdmin.newImplementation(), newImplementation);
        assertEq(proxyAdmin.implementationUpdateTime(), block.timestamp + initialDelay);
    }

    function test_SubmitImplementation_EmitsEvent() public {
        address newImplementation = address(0x123);
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit DelayProxyAdmin.ImplementationUpdateSubmited(newImplementation, block.timestamp + initialDelay);
        proxyAdmin.submitImplementation(newImplementation);
    }

    function test_SubmitImplementation_RevertsIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        proxyAdmin.submitImplementation(address(0x123));
    }

    // Test upgradeAndCall
    function test_UpgradeAndCall_UpgradesProxy() public {
        // Deploy test proxy and implementations
        TestImplementation impl1 = new TestImplementation();
        TestImplementation2 impl2 = new TestImplementation2();

        // we make sure the implementations are allowed
        ProtocolRegistry registry = new ProtocolRegistry(false);
        registry.initialize(owner, owner);
        vm.prank(owner);
        registry.addLogic((address(impl1)));
        vm.prank(owner);
        registry.addLogic((address(impl2)));

        LagoonVault proxy = new LagoonVault({
            _logic: address(impl1),
            _initialOwner: owner,
            _logicRegistry: address(registry),
            _initialDelay: initialDelay,
            _data: abi.encodeWithSelector(TestImplementation.initialize.selector, 100)
        });

        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        proxyAdmin = DelayProxyAdmin(address(uint160(uint256(vm.load(address(proxy), bytes32(ADMIN_SLOT))))));

        // Submit new implementation
        vm.prank(owner);
        proxyAdmin.submitImplementation(address(impl2));

        // Warp to after delay period
        vm.warp(block.timestamp + initialDelay + 1);

        // // Upgrade proxy
        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(impl2), "");

        // // // Verify upgrade
        TestImplementation2 upgraded = TestImplementation2(address(proxy));
        upgraded.setValue(50);
        assertEq(upgraded.value(), 50); // Initial value preserved
        // assertEq(proxyAdmin.implementation(), address(impl2));
    }

    function test_UpgradeAndCall_ResetsImplementation() public {
        address newImplementation = address(0x123);
        vm.prank(owner);
        proxyAdmin.submitImplementation(newImplementation);

        vm.warp(block.timestamp + initialDelay + 1);

        // Mock proxy
        address mockProxy = address(0x456);
        vm.mockCall(
            mockProxy, abi.encodeWithSelector(ITransparentUpgradeableProxy.upgradeToAndCall.selector), abi.encode()
        );

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(mockProxy), newImplementation, "");

        assertEq(proxyAdmin.newImplementation(), address(0));
    }

    function test_UpgradeAndCall_RevertsIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(0x123)), address(0), "");
    }

    function test_UpgradeAndCall_RevertsIfDelayNotOver() public {
        address newImplementation = address(0x123);
        vm.prank(owner);
        proxyAdmin.submitImplementation(newImplementation);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(DelayProxyAdmin.DelayIsNotOver.selector));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(0x456)), newImplementation, "");
    }

    function test_UpgradeAndCall_RevertsIfCallTwiceInRaw() public {
        // Mock proxy
        MockProxy mockProxy = new MockProxy(address(proxyAdmin));
        assertEq(mockProxy.implementation(), address(0));
        assertEq(proxyAdmin.newImplementation(), address(0));

        address newImplementation = address(0x123);
        vm.prank(owner);
        proxyAdmin.submitImplementation(newImplementation);

        vm.warp(block.timestamp + initialDelay + 1);

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(mockProxy)), address(newImplementation), "");

        assertEq(mockProxy.implementation(), address(newImplementation));
        assertEq(proxyAdmin.newImplementation(), address(0));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(DelayProxyAdmin.DelayIsNotOver.selector));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(mockProxy)), address(newImplementation), "");
    }

    // Test initial state
    function test_InitialState() public view {
        assertEq(proxyAdmin.implementationUpdateTime(), type(uint256).max);
        assertEq(proxyAdmin.delayUpdateTime(), type(uint256).max);
        assertEq(proxyAdmin.newImplementation(), address(0));
        assertEq(proxyAdmin.newDelay(), 0);
    }
}

// Mock implementation for testing
contract TestImplementation {
    uint256 public value;

    function initialize(
        uint256 _value
    ) public {
        value = _value;
    }
}

contract TestImplementation2 {
    uint256 public value;

    function initialize(
        uint256 _value
    ) public {
        value = _value;
    }

    // For testing upgradeAndCall with data
    function setValue(
        uint256 _value
    ) public {
        value = _value;
    }
}

contract MockProxy {
    address public admin;
    address public implementation;

    constructor(
        address _admin
    ) {
        admin = _admin;
    }

    fallback() external {
        if (msg.sender == admin) {
            if (msg.sig != ITransparentUpgradeableProxy.upgradeToAndCall.selector) {
                revert("ProxyDeniedAdminAccess()");
            } else {
                // equivalent to TransparentUpgradeableProxy.dispatchUpgradeToAndCall
                // with a check to the registry first.
                (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
                implementation = newImplementation;
            }
        } else {
            revert("not admin");
        }
    }
}
