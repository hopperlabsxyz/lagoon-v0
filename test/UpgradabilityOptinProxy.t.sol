// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {IVersion} from "./IVersion.sol";

import {Options, Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {Vault} from "@src/v0.5.0/Vault.sol";

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {OptinProxyFactory} from "@src/protocol-v2/OptinProxyFactory.sol";
import {LagoonVault} from "@src/proxy/OptinProxy.sol";

import {ProtocolRegistry} from "@src/protocol-v2/ProtocolRegistry.sol";
import {DelayProxyAdmin} from "@src/proxy/DelayProxyAdmin.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {InitStruct} from "@src/protocol-v2/OptinProxyFactory.sol";
import {Vault as Vault6} from "@src/v0.6.0/vault/Vault.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract Upgradable is Test {
    // ERC20 tokens
    ERC20 immutable underlying = ERC20(vm.envAddress("ASSET"));
    address immutable WRAPPED_NATIVE_TOKEN = vm.envAddress("WRAPPED_NATIVE_TOKEN");
    bool underlyingIsNativeToken = address(underlying) == WRAPPED_NATIVE_TOKEN;

    uint8 decimalsOffset = 0;

    string vaultName = "vault_name";
    string vaultSymbol = "vault_symbol";
    uint256 rateUpdateCooldown = 1 days;

    // Users
    VmSafe.Wallet owner = vm.createWallet("owner");
    VmSafe.Wallet safe = vm.createWallet("safe");
    VmSafe.Wallet valuationManager = vm.createWallet("valuationManager");
    VmSafe.Wallet admin = vm.createWallet("admin");
    VmSafe.Wallet feeReceiver = vm.createWallet("feeReceiver");
    VmSafe.Wallet dao = vm.createWallet("dao");
    VmSafe.Wallet whitelistManager = vm.createWallet("whitelistManager");
    bool doProxy = vm.envBool("PROXY");
    OptinProxyFactory factory;
    ProtocolRegistry protocolRegistry;
    address vault;

    VmSafe.Wallet[] users;

    address[] whitelistInit = new address[](0);
    bool enableWhitelist = true;

    // Wallet
    VmSafe.Wallet address0 = VmSafe.Wallet({addr: address(0), publicKeyX: 0, publicKeyY: 0, privateKey: 0});

    int256 immutable bipsDividerSigned = 10_000;

    function _beaconDeploy(
        string memory contractName,
        address _owner,
        Options memory opts
    ) internal returns (UpgradeableBeacon) {
        return UpgradeableBeacon(Upgrades.deployBeacon(contractName, _owner, opts));
    }

    function setUp() public {
        _deployProtocolRegistry();
        _deployFactory();
    }

    function _deployFactory() internal {
        factory = new OptinProxyFactory(false);
        factory.initialize(address(protocolRegistry), WRAPPED_NATIVE_TOKEN, dao.addr);
    }

    function _deployProtocolRegistry() internal {
        protocolRegistry = new ProtocolRegistry(false);
        protocolRegistry.initialize(dao.addr, dao.addr);
    }

    function test_upgradeable_optinProxy() public {
        address v5 = address(new Vault(false));

        vm.prank(dao.addr);
        protocolRegistry.updateDefaultRate(50);

        vm.prank(dao.addr);
        protocolRegistry.updateDefaultLogic(v5);

        InitStruct memory v = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: 200,
            performanceRate: 2000,
            enableWhitelist: enableWhitelist,
            rateUpdateCooldown: rateUpdateCooldown
        });

        // first we create a vault whome logic is a vault v0.5
        vault = factory.createVaultProxy({
            _logic: v5, _initialOwner: admin.addr, _init: v, salt: "0x1123", _initialDelay: 86_400
        });
        assertEq(Vault(vault).version(), "v0.5.0");

        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        DelayProxyAdmin adminContract = DelayProxyAdmin(address(uint160(uint256(vm.load(vault, bytes32(ADMIN_SLOT))))));
        // we update this vault to version v0.6
        address v6 = address(new Vault6(false));
        vm.prank(dao.addr);
        protocolRegistry.addLogic(v6);
        vm.prank(adminContract.owner());
        adminContract.submitImplementation(v6);
        vm.warp(block.timestamp + 2 days);
        vm.prank(adminContract.owner());
        adminContract.upgradeAndCall(ITransparentUpgradeableProxy(vault), v6, "");
        assertEq(Vault6(vault).version(), "v0.6.0");

        // we try to update contract to a not approve contract, it reverts
        address notApproved = address(new Vault6(false));
        vm.prank(adminContract.owner());
        adminContract.submitImplementation(notApproved);
        vm.warp(block.timestamp + 2 days);
        vm.prank(adminContract.owner());
        vm.expectRevert(LagoonVault.UpdateNotAllowed.selector);
        adminContract.upgradeAndCall(ITransparentUpgradeableProxy(vault), notApproved, "");

        // we try to do a vault call as the admin, it reverts
        vm.prank(address(adminContract));
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        Vault(vault).requestDeposit(1, address(0), address(0));

        // we give up ownership, now any contract can be used as logic
        vm.prank(dao.addr);
        protocolRegistry.renounceOwnership();

        vm.prank(adminContract.owner());
        adminContract.submitImplementation(notApproved);
        vm.warp(block.timestamp + 2 days);
        vm.prank(adminContract.owner());
        adminContract.upgradeAndCall(ITransparentUpgradeableProxy(vault), notApproved, "");
    }
}
