// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./VaultHelper.sol";
import "forge-std/Test.sol";

import {BaseTest} from "./Base.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestMisc is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
        dealAndApproveAndWhitelist(user1.addr);
    }

    function test_previewDeposit() public {
        vm.expectRevert(ERC7540PreviewDepositDisabled.selector);
        vault.previewDeposit(0);
    }

    function test_previewWithdraw() public {
        vm.expectRevert(ERC7540PreviewWithdrawDisabled.selector);
        vault.previewWithdraw(0);
    }

    function test_previewMint() public {
        vm.expectRevert(ERC7540PreviewMintDisabled.selector);
        vault.previewMint(0);
    }

    function test_previewRedeem() public {
        vm.expectRevert(ERC7540PreviewRedeemDisabled.selector);
        vault.previewRedeem(0);
    }

    function test_share() public view {
        address share = vault.share();
        assertEq(share, address(vault));
    }

    function test_decimals() public view {
        uint256 underlyingDecimals = underlying.decimals();
        uint256 vaultDecimals = vault.decimals();
        assertEq(vaultDecimals, 18);
        assertEq(underlyingDecimals, 18 - vault.decimalsOffset());
    }

    function test_redeemId() public {
        uint256 redeemId = vault.redeemEpochId();
        assertEq(redeemId, 2);

        requestDeposit(10, user1.addr);
        updateAndSettle(1);
        redeemId = vault.redeemEpochId();

        // redeemId didn't change because there is no redeem request
        assertEq(redeemId, 2);
        deposit(10, user1.addr);
        requestRedeem(vault.balanceOf(user1.addr), user1.addr);
        updateAndSettle(10);
        redeemId = vault.redeemEpochId();
        assertEq(redeemId, 4);
    }

    function test_depositId() public {
        uint256 depositId = vault.depositEpochId();
        assertEq(depositId, 1);
        requestDeposit(10, user1.addr);
        updateAndSettle(1);
        depositId = vault.depositEpochId();
        assertEq(depositId, 3);
    }

    function test_pendingSilo() public view {
        address pendingSilo = vault.pendingSilo();
        assertNotEq(pendingSilo, address(0));
        assertEq(type(uint256).max, underlying.allowance(pendingSilo, address(vault)));
    }

    function test_supportsInterface() public view {
        assertTrue(vault.supportsInterface(0x2f0a18c5), "interface IERC7575 not supported");
        assertTrue(vault.supportsInterface(0xf815c03d), "interface IERC7575 share not supported");
        assertTrue(vault.supportsInterface(0xce3bbe50), "interface IERC7540Deposit not supported");
        assertTrue(vault.supportsInterface(0x620ee8e4), "interface IERC7540Redeem not supported");
        assertTrue(vault.supportsInterface(0xe3bc4e65), "interface IERC7540 not supported");
        assertTrue(vault.supportsInterface(type(IERC165).interfaceId), "interface IERC165 not supported");
    }

    function test_contractSize() public {
        uint256 size;
        address vaultAddr = address(new Vault(true));
        assembly {
            size := extcodesize(vaultAddr)
        }
        console.log("Vault size: %d", size);
        if (size > 24_576) {
            console.log("WARNING: Size diff: %d", size - 24_576);
        } else {
            console.log("Size diff: %d", 24_576 - size);
        }
        // assertLt(size, 24_576, "Contract size is too large");
    }

    function test_epochSettleId() public {
        assertEq(vault.epochSettleId(0), 0);
        assertEq(vault.epochSettleId(1), 0);
        assertEq(vault.epochSettleId(2), 0);

        updateAndSettle(0);

        assertEq(vault.epochSettleId(0), 0);
        assertEq(vault.epochSettleId(1), 1);
        assertEq(vault.epochSettleId(2), 2);
        assertEq(vault.epochSettleId(3), 0);
        assertEq(vault.epochSettleId(4), 0);

        dealAndApproveAndWhitelist(user1.addr);
        uint256 user1Balance = assetBalance(user1.addr);
        uint256 requestId1 = requestDeposit(user1Balance, user1.addr);
        assertEq(requestId1, 1);

        // this increment depositEpochId since there are pending deposit
        updateNewTotalAssets(10_000);

        dealAndApproveAndWhitelist(user2.addr);
        uint256 requestId2 = requestDeposit(user1Balance, user2.addr);
        assertEq(requestId2, 3);

        assertEq(vault.epochSettleId(0), 0);
        assertEq(vault.epochSettleId(1), 1);
        assertEq(vault.epochSettleId(2), 2);
        // settleId for epochId 3 is still uncertain
        assertEq(vault.epochSettleId(3), 0);
        assertEq(vault.epochSettleId(4), 0);

        updateNewTotalAssets(10_000);

        assertEq(vault.epochSettleId(0), 0);
        assertEq(vault.epochSettleId(1), 1);
        assertEq(vault.epochSettleId(2), 2);
        // settleId for epochId 3 points to settleId 1
        assertEq(vault.epochSettleId(3), 1);
        assertEq(vault.epochSettleId(4), 0);
    }

    function test_lastDepositRequestId() public {
        dealAndApproveAndWhitelist(user1.addr);
        uint256 user1Balance = assetBalance(user1.addr);
        uint256 requestId1 = requestDeposit(user1Balance, user1.addr);
        assertEq(vault.lastDepositRequestId(user1.addr), requestId1);

        dealAndApproveAndWhitelist(user1.addr);
        uint256 requestId2 = requestDeposit(user1Balance, user1.addr);
        assertEq(requestId1, requestId2);
        assertEq(vault.lastDepositRequestId(user1.addr), requestId2);

        updateAndSettle(0);

        dealAndApproveAndWhitelist(user1.addr);
        uint256 requestId3 = requestDeposit(user1Balance, user1.addr);
        assertNotEq(requestId2, requestId3);
        assertEq(vault.lastDepositRequestId(user1.addr), requestId3);
    }

    function test_lastRedeemRequestId() public {
        dealAndApproveAndWhitelist(user1.addr);
        uint256 user1Balance = assetBalance(user1.addr);
        uint256 requestId1 = requestDeposit(user1Balance, user1.addr);
        assertEq(vault.lastDepositRequestId(user1.addr), requestId1);

        dealAndApproveAndWhitelist(user1.addr);
        uint256 requestId2 = requestDeposit(user1Balance, user1.addr);
        assertEq(requestId1, requestId2);
        assertEq(vault.lastDepositRequestId(user1.addr), requestId2);

        updateAndSettle(0);

        dealAndApproveAndWhitelist(user1.addr);
        uint256 requestId3 = requestDeposit(user1Balance, user1.addr);
        assertNotEq(requestId2, requestId3);
        assertEq(vault.lastDepositRequestId(user1.addr), requestId3);

        updateAndSettle(2 * user1Balance);

        vm.prank(user1.addr);
        vault.deposit(user1Balance, user1.addr, user1.addr);

        uint256 requestId4 = requestRedeem(user1Balance * 10 ** vault.decimalsOffset(), user1.addr);
        assertEq(vault.lastRedeemRequestId(user1.addr), requestId4);

        uint256 requestId5 = requestRedeem(user1Balance * 10 ** vault.decimalsOffset(), user1.addr);
        assertEq(vault.lastRedeemRequestId(user1.addr), requestId5);

        assertEq(requestId5, requestId4);

        updateAndSettle(3 * user1Balance);

        uint256 requestId6 = requestRedeem(user1Balance * 10 ** vault.decimalsOffset(), user1.addr);
        assertEq(vault.lastRedeemRequestId(user1.addr), requestId6);

        assertNotEq(requestId5, requestId6);
    }

    function test_getRoleStorage() public view {
        Roles.RolesStorage memory rolesStorage = vault.getRolesStorage();
        assertEq(rolesStorage.whitelistManager, whitelistManager.addr);
        assertEq(rolesStorage.feeReceiver, feeReceiver.addr);
        assertEq(rolesStorage.safe, safe.addr);
        assertEq(address(rolesStorage.feeRegistry), address(feeRegistry));
        assertEq(rolesStorage.valuationManager, valuationManager.addr);
    }

    function test_version() public view {
        assertEq(keccak256(abi.encode(vault.version())), keccak256(abi.encode("v0.6.0")));
    }

    function test_factory() public view {
        if (!proxy) return;

        assertEq(factory.REGISTRY(), address(feeRegistry));
        assertEq(factory.WRAPPED_NATIVE(), address(WRAPPED_NATIVE_TOKEN));
        assertTrue(factory.isInstance(address(vault)));
        assertEq(factory.instances(0), address(vault));
    }

    function test_totalAssetsLifespan() public {
        assertEq(vault.totalAssetsLifespan(), 0);
        vm.prank(vault.safe());
        vault.updateTotalAssetsLifespan(1000);
        assertEq(vault.totalAssetsLifespan(), 1000);
    }
}
