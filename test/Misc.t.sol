// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {BaseTest} from "./Base.t.sol";

contract TestMisc is BaseTest {
    function setUp() public {
        dealAndApprove(user1.addr);
    }

    function test_previewDeposit() public {
        vm.expectRevert();
        vault.previewDeposit(0);
    }

    function test_previewWithdraw() public {
        vm.expectRevert();
        vault.previewWithdraw(0);
    }

    function test_previewMint() public {
        vm.expectRevert();
        vault.previewMint(0);
    }

    function test_previewRedeem() public {
        vm.expectRevert();
        vault.previewRedeem(0);
    }

    function test_share() public view {
        address share = vault.share();
        assertEq(share, address(vault));
    }

    function test_decimals() public view {
        uint256 underlyingDecimals = underlying.decimals();
        uint256 vaultDecimals = vault.decimals();
        assertEq(underlyingDecimals, vaultDecimals);
    }

    function test_epochId() public {
        uint256 epochId = vault.epochId();
        assertEq(epochId, 1);
        updateAndSettle(0);
        epochId = vault.epochId();
        assertEq(epochId, 2);
    }

    function test_pendingSilo() public view {
        address pendingSilo = vault.pendingSilo();
        assertNotEq(pendingSilo, address(0));
        assertEq(
            type(uint256).max,
            underlying.allowance(pendingSilo, address(vault))
        );
    }

    function test_claimableSilo() public view {
        address claimableSilo = vault.claimableSilo();
        assertNotEq(claimableSilo, address(0));
        assertEq(
            type(uint256).max,
            underlying.allowance(claimableSilo, address(vault))
        );
    }
}
