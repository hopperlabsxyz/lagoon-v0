// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";

contract TestMint is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
    }

    function test_whitelistManager() public view {
        assertEq(vault.whitelistManager(), whitelistManager.addr);
    }

    function test_feeReceiver() public view {
        assertEq(vault.feeReceiver(), feeReceiver.addr);
    }

    function test_protocolFeeReceiver() public view {
        assertEq(vault.protocolFeeReceiver(), dao.addr);
    }

    function test_safe() public view {
        assertEq(vault.safe(), safe.addr);
    }

    function test_navManager() public view {
        assertEq(vault.navManager(), navManager.addr);
    }

    function test_feeRegistry() public view {
        assertEq(vault.feeRegistry(), address(feeRegistry));
    }

    function test_updateWhitelistManager() public {
        vm.prank(vault.owner());
        vault.updateWhitelistManager(address(0x42));

        assertEq(vault.whitelistManager(), address(0x42));
    }

    function test_updateFeeReceiver() public {
        vm.prank(vault.owner());
        vault.updateFeeReceiver(address(0x42));

        assertEq(vault.feeReceiver(), address(0x42));
    }

    function test_updateNewTotalAssetsManager() public {
        vm.prank(vault.owner());
        vault.updateNAVManager(address(0x42));

        assertEq(vault.navManager(), address(0x42));
    }

    function test_updateNewTotalAssetsManager_notOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.updateNAVManager(address(0x42));
    }
}
