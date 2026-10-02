// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DelayProxyAdmin} from "@src/proxy/DelayProxyAdmin.sol";
import {Vault} from "@src/v0.5.2/Vault.sol";
import {Test} from "forge-std/Test.sol";

interface IVmEvm {
    function setEvmVersion(
        string calldata
    ) external;
}

interface IRegistry {
    function owner() external view returns (address);
    function addLogic(
        address
    ) external;
}

/// Simulates the v0.5.2 deployment and a client upgrading a live mainnet vault to it.
contract UpgradeToV052Fork is Test {
    address constant DEPLOYER = 0xcBCC2EbDC6Cb5ED8b6449b961d43F69E0AF3319e;
    address constant EXPECTED_IMPL = 0x8fa0e10Ab7603402874Da14C5434979EE6eeC08A; // DEPLOYER nonce 37
    IRegistry constant REGISTRY = IRegistry(0x6dA4D1859bA1d02D095D2246142CdAd52233e27C);
    Vault constant VAULT = Vault(0x01f461a0bBb218Bc1943aa027c5bBC424391E541); // live v0.5.0 vault
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function test_deployAndUpgrade() public {
        vm.skip(block.chainid != 1);
        // Live mainnet contracts use Cancun opcodes; the repo builds for Shanghai.
        IVmEvm(address(vm)).setEvmVersion("cancun");

        // 1. Lagoon deploys the implementation.
        vm.prank(DEPLOYER);
        address impl = address(new Vault(true));
        assertEq(impl, EXPECTED_IMPL);
        assertEq(Vault(impl).version(), "v0.5.2");

        // 2. Lagoon whitelists it in the protocol registry.
        vm.prank(REGISTRY.owner());
        REGISTRY.addLogic(impl);

        // 3. The vault's proxy admin owner submits, waits the timelock, upgrades.
        DelayProxyAdmin admin = DelayProxyAdmin(address(uint160(uint256(vm.load(address(VAULT), ADMIN_SLOT)))));
        address adminOwner = admin.owner();
        uint256 totalAssets = VAULT.totalAssets();
        uint256 totalSupply = VAULT.totalSupply();
        address owner = VAULT.owner();

        vm.prank(adminOwner);
        admin.submitImplementation(impl);
        vm.warp(block.timestamp + admin.delay());
        vm.prank(adminOwner);
        admin.upgradeAndCall(ITransparentUpgradeableProxy(address(VAULT)), impl, "");

        assertEq(VAULT.version(), "v0.5.2");
        assertEq(VAULT.totalAssets(), totalAssets);
        assertEq(VAULT.totalSupply(), totalSupply);
        assertEq(VAULT.owner(), owner);

        // 4. The vault owner can now close and reopen.
        vm.startPrank(owner);
        VAULT.initiateClosing();
        VAULT.cancelClosing();
        vm.expectRevert();
        VAULT.cancelClosing(); // only while Closing
        vm.stopPrank();

        emit log_named_address("vault", address(VAULT));
        emit log_named_address("proxy admin", address(admin));
        emit log_named_address("proxy admin owner", adminOwner);
        emit log_named_uint("timelock delay (s)", admin.delay());
    }
}
