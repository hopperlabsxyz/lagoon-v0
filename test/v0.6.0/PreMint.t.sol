// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessMode} from "@src/v0.6.0/primitives/Enums.sol";
import {InitStruct} from "@src/v0.6.0/vault/Vault-v0.6.0.sol";

contract TestPreMint is BaseTest {
    function test_preMint_whenInitialTotalAssetsIsZero_shouldHaveZeroTotalAssetsAndTotalSupply() public {
        // Deploy a new vault with initialTotalAssets = 0

        InitStruct memory initStruct = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: 0,
            performanceRate: 0,
            accessMode: AccessMode.Blacklist,
            entryRate: 0,
            exitRate: 0,
            haircutRate: 0,
            securityCouncil: admin.addr,
            externalSanctionsList: address(0),
            initialTotalAssets: 0,
            superOperator: superOperator.addr
        });

        VaultHelper newVault = new VaultHelper(false);
        newVault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);

        // Assert that totalAssets and totalSupply are both 0
        assertEq(newVault.totalAssets(), 0, "totalAssets should be 0 when initialTotalAssets is 0");
        assertEq(newVault.totalSupply(), 0, "totalSupply should be 0 when initialTotalAssets is 0");
    }

    function test_preMint_whenInitialTotalAssetsIsNonZero_shouldSetTotalAssetsAndMintShares() public {
        console.log("safe", safe.addr);
        console.log("underlying", address(underlying));
        uint256 initialAssets = 1000 * 10 ** underlying.decimals();

        // Deploy a new vault with initialTotalAssets > 0
        InitStruct memory initStruct = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: safe.addr,
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: 0,
            performanceRate: 0,
            accessMode: AccessMode.Blacklist,
            entryRate: 0,
            exitRate: 0,
            haircutRate: 0,
            securityCouncil: admin.addr,
            externalSanctionsList: address(0),
            initialTotalAssets: initialAssets,
            superOperator: superOperator.addr
        });

        VaultHelper newVault = new VaultHelper(false);
        newVault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);

        // Assert that totalAssets equals initialTotalAssets
        assertEq(newVault.totalAssets(), initialAssets, "totalAssets should equal initialTotalAssets");

        // Calculate expected shares using convertToShares
        uint256 expectedShares = newVault.convertToSharesWithRounding(initialAssets, Math.Rounding.Floor);

        // Assert that totalSupply equals the converted shares
        assertEq(newVault.totalSupply(), expectedShares, "totalSupply should equal convertToShares(initialTotalAssets)");

        // Assert that the safe received the shares
        assertEq(newVault.balanceOf(safe.addr), expectedShares, "safe should receive the minted shares");
    }

    function test_preMint_whenSafeIsZeroAddressAndInitialTotalAssetsIsNonZero_shouldRevert() public {
        uint256 initialAssets = 1000 * 10 ** underlying.decimals();

        // Deploy a new vault with safe = address(0) and initialTotalAssets > 0
        InitStruct memory initStruct = InitStruct({
            underlying: underlying,
            name: vaultName,
            symbol: vaultSymbol,
            safe: address(0), // This should cause a revert
            whitelistManager: whitelistManager.addr,
            valuationManager: valuationManager.addr,
            admin: admin.addr,
            feeReceiver: feeReceiver.addr,
            managementRate: 0,
            performanceRate: 0,
            accessMode: AccessMode.Blacklist,
            entryRate: 0,
            exitRate: 0,
            haircutRate: 0,
            securityCouncil: admin.addr,
            externalSanctionsList: address(0),
            initialTotalAssets: initialAssets,
            superOperator: superOperator.addr
        });

        VaultHelper newVault = new VaultHelper(false);

        // Expect revert with ERC20InvalidReceiver error when trying to mint to address(0)
        vm.expectRevert(VaultInitializationFailed.selector);
        newVault.initialize(abi.encode(initStruct), address(protocolRegistry), WRAPPED_NATIVE_TOKEN);
    }
}
