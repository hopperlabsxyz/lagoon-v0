// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {VaultHelper as VaultHelper_v0_5_0} from "../v0.5.0-opt-inProxy/VaultHelper.sol";
import {VaultHelper as VaultHelper_v0_6_0} from "../v0.6.0/VaultHelper.sol";
import {BaseTest} from "./Base.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {
    InitStruct as InitStruct_v0_5_0,
    OptinProxyFactory as OptinProxyFactory_v0_5_0
} from "@src/protocol-v2/OptinProxyFactory.sol";

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {DelayProxyAdmin} from "@src/proxy/DelayProxyAdmin.sol";
import {WhitelistState} from "@src/v0.6.0/primitives/Enums.sol";

contract TestWhitelistableStorageCollision is BaseTest {
    // Storage slot for WhitelistableStorage
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.Whitelistable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant WHITELISTABLE_STORAGE_SLOT = 0x083cc98ab296d1a1f01854b5f7a2f47df4425a56ba7b35f7faa3a336067e4800;
    // Slot 1: isActivated (v0.5.0) / whitelistState (v0.6.0)
    bytes32 constant WHITELIST_STATE_SLOT = bytes32(uint256(WHITELISTABLE_STORAGE_SLOT) + 1);

    function _createVault(
        bool enableWhitelist,
        bytes32 salt
    ) internal returns (VaultHelper_v0_5_0, DelayProxyAdmin) {
        vm.startPrank(dao.addr);
        protocolRegistry.updateDefaultLogic(address(vault_v0_5_0));
        vm.stopPrank();

        // setup the factory
        OptinProxyFactory_v0_5_0 factory = new OptinProxyFactory_v0_5_0(false);

        factory.initialize(address(protocolRegistry), WRAPPED_NATIVE_TOKEN, dao.addr);

        InitStruct_v0_5_0 memory initStruct = InitStruct_v0_5_0({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            enableWhitelist: enableWhitelist,
            managementRate: 1,
            performanceRate: 2,
            rateUpdateCooldown: 1 days
        });

        VaultHelper_v0_5_0 vault = VaultHelper_v0_5_0(
            OptinProxyFactory_v0_5_0(address(factory))
                .createVaultProxy({
                    _logic: address(0),
                    _initialOwner: initStruct.admin,
                    _initialDelay: 86_400,
                    _init: initStruct,
                    salt: salt
                })
        );
        DelayProxyAdmin proxyAdmin = DelayProxyAdmin(vm.computeCreateAddress(address(vault), 2));

        assertEq(vault.version(), "v0.5.0");
        assertEq(proxyAdmin.owner(), initStruct.admin);

        return (vault, proxyAdmin);
    }

    /// @notice Test migration from v0.5.0 isActivated = false (0) to v0.6.0 whitelistState = Blacklist (0)
    function test_storageCollision_boolFalse_to_enumBlacklist() public {
        // Create a vault with whitelist disabled (enableWhitelist = false)
        (VaultHelper_v0_5_0 _vault, DelayProxyAdmin delayProxyAdmin) = _createVault(false, keccak256("whitelist_false"));
        VaultHelper_v0_6_0 proxyV0_6_0 = VaultHelper_v0_6_0(address(_vault));
        address owner = delayProxyAdmin.owner();

        // Verify v0.5.0 state: isActivated should be false
        assertEq(_vault.isWhitelistActivated(), false, "v0.5.0: whitelist should be deactivated");

        // Read storage slot directly to verify bool = 0
        bytes32 storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 boolValue = uint8(uint256(storageValue));
        assertEq(boolValue, 0, "v0.5.0: storage slot should contain 0 (false)");

        // Upgrade to v0.6.0
        vm.prank(owner);
        delayProxyAdmin.submitImplementation(address(vault_v0_6_0));

        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        delayProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_vault)), address(vault_v0_6_0), "");
        assertEq(_vault.version(), "v0.6.0", "vault should be upgraded to v0.6.0");

        // Verify v0.6.0 state: whitelistState should be Blacklist (0)
        assertEq(
            proxyV0_6_0.isBlacklistActivated(),
            true,
            "v0.6.0: whitelistState should be Blacklist after upgrade from isActivated=false"
        );
        assertEq(proxyV0_6_0.isWhitelistActivated(), false, "v0.6.0: whitelistState should not be Whitelist");

        // Read storage slot directly to verify enum = 0 (Blacklist)
        storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 enumValue = uint8(uint256(storageValue));
        assertEq(enumValue, 0, "v0.6.0: storage slot should contain 0 (Blacklist)");
        assertEq(enumValue, uint8(WhitelistState.Blacklist), "v0.6.0: enum value should match Blacklist");

        // Test that isWhitelisted works correctly with Blacklist mode
        // In Blacklist mode, all addresses are whitelisted unless they are blacklisted
        address testUser = address(0x1234);
        assertEq(
            proxyV0_6_0.isWhitelisted(testUser), true, "v0.6.0: user should be whitelisted in Blacklist mode by default"
        );
    }

    /// @notice Test migration from v0.5.0 isActivated = true (1) to v0.6.0 whitelistState = Whitelist (1)
    function test_storageCollision_boolTrue_to_enumWhitelist() public {
        // Create a vault with whitelist enabled (enableWhitelist = true)
        (VaultHelper_v0_5_0 _vault, DelayProxyAdmin delayProxyAdmin) = _createVault(true, keccak256("whitelist_true"));
        VaultHelper_v0_6_0 proxyV0_6_0 = VaultHelper_v0_6_0(address(_vault));
        address owner = delayProxyAdmin.owner();

        // In v0.5.0, ensure whitelist is activated (isActivated = true)
        // By default, if enableWhitelist is true in init, it should be activated
        // Verify it's activated
        assertEq(_vault.isWhitelistActivated(), true, "v0.5.0: whitelist should be activated");

        // Read storage slot directly to verify bool = 1
        bytes32 storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 boolValue = uint8(uint256(storageValue));
        assertEq(boolValue, 1, "v0.5.0: storage slot should contain 1 (true)");

        // Upgrade to v0.6.0
        vm.prank(owner);
        delayProxyAdmin.submitImplementation(address(vault_v0_6_0));

        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        delayProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_vault)), address(vault_v0_6_0), "");
        assertEq(_vault.version(), "v0.6.0", "vault should be upgraded to v0.6.0");

        // Verify v0.6.0 state: whitelistState should be Whitelist (1)
        assertEq(
            proxyV0_6_0.isWhitelistActivated(),
            true,
            "v0.6.0: whitelistState should be Whitelist after upgrade from isActivated=true"
        );
        assertEq(proxyV0_6_0.isBlacklistActivated(), false, "v0.6.0: whitelistState should not be Blacklist");

        // Read storage slot directly to verify enum = 1 (Whitelist)
        storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 enumValue = uint8(uint256(storageValue));
        assertEq(enumValue, 1, "v0.6.0: storage slot should contain 1 (Whitelist)");
        assertEq(enumValue, uint8(WhitelistState.Whitelist), "v0.6.0: enum value should match Whitelist");

        // Test that isWhitelisted works correctly with Whitelist mode
        // In Whitelist mode, only whitelisted addresses are allowed
        address testUser = address(0x1234);
        assertEq(
            proxyV0_6_0.isWhitelisted(testUser),
            false,
            "v0.6.0: user should not be whitelisted in Whitelist mode by default"
        );

        // Add user to whitelist and verify
        address[] memory users = new address[](1);
        users[0] = testUser;
        vm.prank(whitelistManager.addr);
        proxyV0_6_0.addToWhitelist(users);
        assertEq(proxyV0_6_0.isWhitelisted(testUser), true, "v0.6.0: user should be whitelisted after being added");
    }

    /// @notice Test rollback scenario: upgrade to v0.6.0 Blacklist mode, then rollback to v0.5.0
    /// @dev Verifies that when whitelistState = Blacklist (0) in v0.6.0, rolling back to v0.5.0
    ///      should result in isActivated = false (deactivated state)
    function test_rollback_from_blacklist_to_v0_5_0() public {
        // Create a vault with whitelist disabled (enableWhitelist = false)
        (VaultHelper_v0_5_0 _vault, DelayProxyAdmin delayProxyAdmin) =
            _createVault(false, keccak256("rollback_blacklist"));
        VaultHelper_v0_6_0 proxyV0_6_0 = VaultHelper_v0_6_0(address(_vault));
        address owner = delayProxyAdmin.owner();

        // Verify v0.5.0 initial state: isActivated should be false
        assertEq(_vault.isWhitelistActivated(), false, "v0.5.0: whitelist should be deactivated initially");

        // Read storage slot directly to verify bool = 0
        bytes32 storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 boolValue = uint8(uint256(storageValue));
        assertEq(boolValue, 0, "v0.5.0: storage slot should contain 0 (false)");

        // Upgrade to v0.6.0
        vm.prank(owner);
        delayProxyAdmin.submitImplementation(address(vault_v0_6_0));

        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        delayProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_vault)), address(vault_v0_6_0), "");
        assertEq(_vault.version(), "v0.6.0", "vault should be upgraded to v0.6.0");

        // Verify v0.6.0 state: whitelistState should be Blacklist (0)
        assertEq(proxyV0_6_0.isBlacklistActivated(), true, "v0.6.0: whitelistState should be Blacklist");
        assertEq(proxyV0_6_0.isWhitelistActivated(), false, "v0.6.0: whitelistState should not be Whitelist");
        storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 enumValue = uint8(uint256(storageValue));
        assertEq(enumValue, 0, "v0.6.0: storage slot should contain 0 (Blacklist)");
        assertEq(enumValue, uint8(WhitelistState.Blacklist), "v0.6.0: enum value should match Blacklist");

        // Test that isWhitelisted works correctly with Blacklist mode
        // In Blacklist mode, all addresses are whitelisted unless they are blacklisted
        address testUser = address(0x1234);
        assertEq(
            proxyV0_6_0.isWhitelisted(testUser), true, "v0.6.0: user should be whitelisted in Blacklist mode by default"
        );

        // Rollback to v0.5.0
        vm.prank(owner);
        delayProxyAdmin.submitImplementation(address(vault_v0_5_0));

        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        delayProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_vault)), address(vault_v0_5_0), "");
        assertEq(_vault.version(), "v0.5.0", "vault should be rolled back to v0.5.0");

        // Verify storage slot still contains 0 (Blacklist) after rollback
        storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 storageAfterRollback = uint8(uint256(storageValue));
        assertEq(storageAfterRollback, 0, "v0.5.0: storage slot should still contain 0 after rollback");

        // Verify v0.5.0 state after rollback: isActivated should be false (deactivated)
        // In v0.5.0, when reading a bool from storage, 0 means false (deactivated)
        bool isActivatedAfterRollback = _vault.isWhitelistActivated();
        assertEq(
            isActivatedAfterRollback,
            false,
            "v0.5.0: isActivated should be false (deactivated) after rollback from Blacklist state"
        );

        // Verify that isWhitelisted works correctly (should return true for everyone when deactivated)
        // In v0.5.0, when isActivated is false, isWhitelisted returns true for all addresses
        assertEq(
            _vault.isWhitelisted(testUser), true, "v0.5.0: user should be whitelisted when whitelist is deactivated"
        );

        // Verify that a non-whitelisted user can still access (because whitelist is deactivated)
        address anotherUser = address(0x5678);
        assertEq(
            _vault.isWhitelisted(anotherUser),
            true,
            "v0.5.0: any user should be whitelisted when whitelist is deactivated"
        );
    }

    /// @notice Test rollback scenario: upgrade to v0.6.0 Whitelist mode, then rollback to v0.5.0
    /// @dev Verifies that when whitelistState = Whitelist (1) in v0.6.0, rolling back to v0.5.0
    ///      should result in isActivated = true (activated state)
    function test_rollback_from_whitelist_to_v0_5_0() public {
        // Create a vault with whitelist enabled (enableWhitelist = true)
        (VaultHelper_v0_5_0 _vault, DelayProxyAdmin delayProxyAdmin) =
            _createVault(true, keccak256("rollback_whitelist"));
        VaultHelper_v0_6_0 proxyV0_6_0 = VaultHelper_v0_6_0(address(_vault));
        address owner = delayProxyAdmin.owner();

        // Verify v0.5.0 initial state: isActivated should be true
        assertEq(_vault.isWhitelistActivated(), true, "v0.5.0: whitelist should be activated initially");

        // Read storage slot directly to verify bool = 1
        bytes32 storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 boolValue = uint8(uint256(storageValue));
        assertEq(boolValue, 1, "v0.5.0: storage slot should contain 1 (true)");

        // Upgrade to v0.6.0
        vm.prank(owner);
        delayProxyAdmin.submitImplementation(address(vault_v0_6_0));

        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        delayProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_vault)), address(vault_v0_6_0), "");
        assertEq(_vault.version(), "v0.6.0", "vault should be upgraded to v0.6.0");

        // Verify v0.6.0 state: whitelistState should be Whitelist (1)
        assertEq(proxyV0_6_0.isWhitelistActivated(), true, "v0.6.0: whitelistState should be Whitelist");
        assertEq(proxyV0_6_0.isBlacklistActivated(), false, "v0.6.0: whitelistState should not be Blacklist");
        storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 enumValue = uint8(uint256(storageValue));
        assertEq(enumValue, 1, "v0.6.0: storage slot should contain 1 (Whitelist)");
        assertEq(enumValue, uint8(WhitelistState.Whitelist), "v0.6.0: enum value should match Whitelist");

        // Test that isWhitelisted works correctly with Whitelist mode
        // In Whitelist mode, only whitelisted addresses are allowed
        address testUser = address(0x1234);
        assertEq(
            proxyV0_6_0.isWhitelisted(testUser),
            false,
            "v0.6.0: user should not be whitelisted in Whitelist mode by default"
        );

        // Rollback to v0.5.0
        vm.prank(owner);
        delayProxyAdmin.submitImplementation(address(vault_v0_5_0));

        vm.warp(block.timestamp + 10 days);
        vm.prank(owner);
        delayProxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(_vault)), address(vault_v0_5_0), "");
        assertEq(_vault.version(), "v0.5.0", "vault should be rolled back to v0.5.0");

        // Verify storage slot still contains 1 (Whitelist) after rollback
        storageValue = vm.load(address(_vault), WHITELIST_STATE_SLOT);
        uint8 storageAfterRollback = uint8(uint256(storageValue));
        assertEq(storageAfterRollback, 1, "v0.5.0: storage slot should still contain 1 after rollback");

        // Verify v0.5.0 state after rollback: isActivated should be true (activated)
        // In v0.5.0, when reading a bool from storage, 1 means true (activated)
        bool isActivatedAfterRollback = _vault.isWhitelistActivated();
        assertEq(
            isActivatedAfterRollback,
            true,
            "v0.5.0: isActivated should be true (activated) after rollback from Whitelist state"
        );

        // Verify that isWhitelisted works correctly (should return false for non-whitelisted users when activated)
        // In v0.5.0, when isActivated is true, isWhitelisted returns false for non-whitelisted addresses
        assertEq(
            _vault.isWhitelisted(testUser),
            false,
            "v0.5.0: non-whitelisted user should not be whitelisted when whitelist is activated"
        );
    }
}
