//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {VaultHelper} from "./VaultHelper.sol";
import {Vault} from "@src/Vault.sol";
import {FeeRegistry} from "@src/FeeRegistry.sol";
import {FeeModule} from "@src/FeeModule.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Upgrades, Options} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "forge-std/console.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

abstract contract Constants is Test {
    // ERC20 tokens
    string network = vm.envString("NETWORK");
    ERC20Permit immutable USDC =
        ERC20Permit(vm.envAddress(string.concat("USDC_", network)));
    ERC20 immutable WETH =
        ERC20(vm.envAddress(string.concat("WETH_", network)));
    ERC20 immutable WBTC =
        ERC20(vm.envAddress(string.concat("WBTC_", network)));
    ERC20 immutable ETH = ERC20(vm.envAddress(string.concat("ETH_", network)));

    uint8 decimalsOffset = 0;

    //ERC20 whales
    address immutable USDC_WHALE =
        vm.envAddress(string.concat("USDC_WHALE", "_", network));

    string underlyingName = vm.envString("UNDERLYING_NAME");
    VaultHelper vault;
    FeeRegistry feeRegistry;
    FeeModule feeModule;
    string vaultName = "vault_";
    string vaultSymbol = "hop_vault_";

    //Underlying
    ERC20 immutable underlying =
        ERC20(vm.envAddress(string.concat(underlyingName, "_", network)));
    ERC20Permit immutable underlyingPermit;

    // Users
    VmSafe.Wallet user1 = vm.createWallet("user1");
    VmSafe.Wallet user2 = vm.createWallet("user2");
    VmSafe.Wallet user3 = vm.createWallet("user3");
    VmSafe.Wallet user4 = vm.createWallet("user4");
    VmSafe.Wallet user5 = vm.createWallet("user5");
    VmSafe.Wallet user6 = vm.createWallet("user6");
    VmSafe.Wallet user7 = vm.createWallet("user7");
    VmSafe.Wallet user8 = vm.createWallet("user8");
    VmSafe.Wallet user9 = vm.createWallet("user9");
    VmSafe.Wallet user10 = vm.createWallet("user10");
    VmSafe.Wallet owner = vm.createWallet("owner");
    VmSafe.Wallet assetManager = vm.createWallet("assetManager");
    VmSafe.Wallet valorizator = vm.createWallet("valorizator");
    VmSafe.Wallet admin = vm.createWallet("admin");
    VmSafe.Wallet feeReceiver = vm.createWallet("feeReceiver");
    VmSafe.Wallet dao = vm.createWallet("dao");

    VmSafe.Wallet[] users;

    address[] whitelistInit = new address[](0);

    // Wallet
    VmSafe.Wallet address0 =
        VmSafe.Wallet({
            addr: address(0),
            publicKeyX: 0,
            publicKeyY: 0,
            privateKey: 0
        });

    int256 immutable bipsDividerSigned = 10_000;

    constructor() {
        vaultName = string.concat(vaultName, underlyingName);
        vaultSymbol = string.concat(vaultSymbol, underlyingName);

        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(ETH), "ETH");
        vm.label(address(WBTC), "WBTC");

        users.push(user1);
        users.push(user2);
        users.push(user3);
        users.push(user4);
        users.push(user5);
        users.push(user6);
        users.push(user7);
        users.push(user8);
        users.push(user9);
        users.push(user10);
    }

    function _beaconDeploy(
        string memory contractName,
        address _owner
    ) internal returns (UpgradeableBeacon) {
        Options memory deploy;
        deploy.constructorData = abi.encode(true);
        return UpgradeableBeacon(Upgrades.deployBeacon(contractName, _owner));
    }

    function _proxyDeploy(
        UpgradeableBeacon beacon,
        ERC20 _underlying,
        string memory _vaultName,
        string memory _vaultSymbol,
        uint256 _managementRate,
        uint256 _performanceRate
    ) internal returns (VaultHelper) {
        bool enableWhitelist = true;
        address[] memory whitelist = new address[](0);

        Vault.InitStruct memory v = Vault.InitStruct({
            underlying: _underlying,
            name: _vaultName,
            symbol: _vaultSymbol,
            dao: dao.addr,
            assetManager: assetManager.addr,
            valorization: valorizator.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            feeModule: address(feeModule),
            feeRegistry: address(feeRegistry),
            managementRate: _managementRate,
            performanceRate: _performanceRate,
            cooldown: 1 days,
            enableWhitelist: enableWhitelist,
            whitelist: whitelist
        });

        BeaconProxy proxy = BeaconProxy(
            payable(
                Upgrades.deployBeaconProxy(
                    address(beacon),
                    abi.encodeCall(Vault.initialize, v)
                )
            )
        );

        return VaultHelper(address(proxy));
    }

    function setUpVault(
        uint256 _protocolRate,
        uint256 _managementRate,
        uint256 _performanceRate
    ) internal {
        bool proxy = vm.envBool("PROXY");

        feeRegistry = new FeeRegistry();
        feeRegistry.initialize(dao.addr);
        feeModule = new FeeModule();
        vm.prank(dao.addr);
        feeRegistry.setProtocolRate(_protocolRate);

        UpgradeableBeacon beacon;
        if (proxy) {
            beacon = _beaconDeploy("Vault.sol", owner.addr);
            vault = _proxyDeploy(
                beacon,
                underlying,
                vaultName,
                vaultSymbol,
                _managementRate,
                _performanceRate
            );
        } else {
            vm.startPrank(owner.addr);
            bool enableWhitelist = true;

            vault = new VaultHelper(false);

            Vault.InitStruct memory v = Vault.InitStruct({
                underlying: underlying,
                name: vaultName,
                symbol: vaultSymbol,
                dao: dao.addr,
                assetManager: assetManager.addr,
                valorization: valorizator.addr,
                admin: admin.addr,
                feeReceiver: feeReceiver.addr,
                feeModule: address(feeModule),
                feeRegistry: address(feeRegistry),
                managementRate: _managementRate,
                performanceRate: _performanceRate,
                cooldown: 1 days,
                enableWhitelist: enableWhitelist,
                whitelist: whitelistInit
            });
            vault.initialize(v);
            vm.stopPrank();
        }
        vm.label(address(vault), vaultName);
        vm.label(vault.pendingSilo(), "vault.pendingSilo");
        vm.label(vault.claimableSilo(), "vault.claimableSilo");
    }
}
