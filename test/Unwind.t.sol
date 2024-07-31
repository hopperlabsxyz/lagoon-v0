// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import {ERC7540InsufficientAssets} from "@src/ERC7540.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {VmSafe} from "forge-std/Vm.sol";
using Math for uint256;

contract TestUnwind is BaseTest {
    function setUp() public {
        deactivateWhitelist();
    }

    /**
     * Here the idea is to make sure that at every new epoch, the toUnwind value is increased
     *
     */
    function test_toUnwindVariables() public {
        dealAndApprove(user1.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        requestDeposit(user1Assets / 2, user1.addr);
        dealAndApprove(user2.addr);

        updateAndSettle(0);
        assertEq(vault.oldestEpochIdUnwinded(), 1);

        uint256 toUnwindGeneral = vault.toUnwind();
        assertEq(
            toUnwindGeneral,
            vault.toUnwind(1),
            "toUnwind should be equal to toUnwind(1) when epoch 2"
        );
        deposit(user1Assets / 2, user1.addr);
        user1Assets = assetBalance(user1.addr);

        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Assets = IERC20(vault.asset()).balanceOf(user2.addr);

        requestRedeem(user1Shares, user1.addr);
        requestDeposit(user2Assets, user2.addr);
        uint256 totalAssets = vault.totalAssets();

        updateAndSettle(totalAssets.mulDiv(150, 100));
        assertEq(vault.oldestEpochIdUnwinded(), 2);
        // the assets in depositRequest are enough to do the unwind, so this value should increase

        assertEq(
            toUnwindGeneral + vault.toUnwind(2),
            vault.toUnwind(),
            "totalToUnwind should be equal to previous value to unwind plus value to unwind 2"
        );

        redeem(user1Shares, user1.addr);
        assertEq(
            vault.availableToWithdraw(2),
            0,
            "availableToWithdraw should be 0"
        );
        deposit(user2Assets, user2.addr);
    }

    function test_userTryToRedeem_WithAssetsInVault_ButNotForHisEpochId()
        public
    {
        //set up, 2 users have fund in the vault
        dealAndApprove(user1.addr);
        dealAndApprove(user2.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        uint256 user2Assets = assetBalance(user2.addr);
        requestDeposit(user1Assets, user1.addr);
        requestDeposit(user2Assets, user2.addr);
        updateAndSettle(0);
        assertEq(vault.oldestEpochIdUnwinded(), 1); // since to unwind is zero,

        // they get their shares
        deposit(user1Assets, user1.addr);
        deposit(user2Assets, user2.addr);

        uint256 user1Shares = vault.balanceOf(user1.addr);
        uint256 user2Shares = vault.balanceOf(user2.addr);

        // user1 requests redeem
        requestRedeem(user1Shares, user1.addr);
        uint256 totalAssets = vault.totalAssets();
        updateAndSettle(totalAssets.mulDiv(150, 100));
        assertEq(vault.oldestEpochIdUnwinded(), 1); // nothing has been unwind yet
        uint256 toUnwind = vault.toUnwind();

        // we make the assetManager really unwind
        unwind();
        assertEq(vault.oldestEpochIdUnwinded(), 3); // we unwind everything so we reach
        // assertEq(vault.)
        assertEq(vault.toUnwind(), 0, "unwind should be at zero");
        assertEq(vault.toUnwind(1), 0, "unwind should be at zero");

        // now user2 request redeem
        requestRedeem(user2Shares, user2.addr);
        updateAndSettle(totalAssets.mulDiv(150, 100)); // nav is the same

        //now user 2 will ask to redeem but won't be able
        assertEq(
            vault.maxRedeem(user2.addr),
            0,
            "user 2 should be able to redeem 0"
        );
        vm.expectRevert(ERC7540InsufficientAssets.selector);
        redeem(user2Shares, user2.addr);
        assertGt(
            vault.maxRedeem(user1.addr),
            0,
            "user 1 should be able to redeem "
        );

        // user 1 should be able to redeem all his shares
        redeem(user1Shares, user1.addr);
        assertEq(
            toUnwind,
            assetBalance(user1.addr),
            "user1 should have receive all the assets available"
        );
        // making the asset manager unwind not enough
        uint256 restToUnwind = vault.toUnwind();
        unwind(vault.toUnwind() / 2);
        assertEq(
            vault.oldestEpochIdUnwinded(),
            3,
            "after partial unwind oldestEpochIdUnwinded should be 3"
        ); // we unwind everything so we reach
        assertEq(
            vault.toUnwind(),
            restToUnwind / 2,
            "restToUnwind should have been devided by 2"
        );
    }

    function test_assetManagerCompletelyUnwindMultipleEpoch() public {
        //set up, 4 users have funds in the vault
        VmSafe.Wallet[4] memory users = [user1, user2, user3, user4];
        for (uint256 i; i < users.length; i++) {
            dealAndApprove(users[i].addr);
            uint256 userAssets = assetBalance(users[i].addr);
            requestDeposit(userAssets, users[i].addr);
        }
        updateAndSettle(0);

        assertEq(vault.oldestEpochIdUnwinded(), 1); // since to unwind is zero,
        assertEq(vault.epochId(), 2);

        // they get their shares
        for (uint256 i; i < users.length; i++) {
            uint256 maxDep = vault.maxDeposit(users[i].addr);
            deposit(maxDep, users[i].addr);
        }

        // they asked to redeem
        uint256[4] memory userShares;
        for (uint256 i; i < users.length; i++) {
            userShares[i] = vault.balanceOf(users[i].addr);
            requestRedeem(userShares[i], users[i].addr);
            uint256 totalAssets = vault.totalAssets();
            updateAndSettle(totalAssets.mulDiv(101, 100)); // + 1%
            assertEq(vault.epochId(), 2 + i + 1);

            assertEq(vault.oldestEpochIdUnwinded(), 1); // nothing has been unwind yet
            assertEq(
                vault.maxRedeem(users[i].addr),
                0,
                "user should not be able to redeem"
            );
        }

        assertApproxEqAbs(vault.totalAssets(), 0, 1);

        unwind();
        assertEq(vault.oldestEpochIdUnwinded(), 6);
        for (uint256 i; i < users.length; i++) {
            uint256 maxRedeem = vault.maxRedeem(users[i].addr);
            assertApproxEqAbs(
                maxRedeem,
                userShares[i],
                1,
                "users should be able to redeem minimum at all their shares - 1"
            );
            redeem(userShares[i], users[i].addr);
        }
    }

    function test_assetManagerUnwindMultipleEpochExpectLastPartially() public {
        //set up, 4 users have funds in the vault
        VmSafe.Wallet[4] memory users = [user1, user2, user3, user4];
        for (uint256 i; i < users.length; i++) {
            dealAndApprove(users[i].addr);
            uint256 userAssets = assetBalance(users[i].addr);
            requestDeposit(userAssets, users[i].addr);
        }
        updateAndSettle(0);

        assertEq(vault.oldestEpochIdUnwinded(), 1); // since to unwind is zero,

        // they get their shares
        for (uint256 i; i < users.length; i++) {
            uint256 maxDep = vault.maxDeposit(users[i].addr);
            deposit(maxDep, users[i].addr);
        }

        // they asked to redeem
        uint256[4] memory userShares;
        for (uint256 i; i < users.length; i++) {
            userShares[i] = vault.balanceOf(users[i].addr);
            requestRedeem(userShares[i], users[i].addr);
            uint256 totalAssets = vault.totalAssets();
            updateAndSettle(totalAssets.mulDiv(101, 100)); // + 1%

            assertEq(vault.oldestEpochIdUnwinded(), 1); // nothing has been unwind yet
            assertEq(
                vault.maxRedeem(users[i].addr),
                0,
                "user should not be able to redeem"
            );
        }

        assertApproxEqAbs(vault.totalAssets(), 0, 1);
        uint256 toUnwind = vault.toUnwind();
        assertEq(vault.epochId(), 6);

        // assetManager will unwind 90% of toUnwind.
        unwind(toUnwind.mulDiv(90, 100));
        for (uint256 i; i < users.length - 1; i++) {
            uint256 maxRedeem = vault.maxRedeem(users[i].addr);
            assertApproxEqAbs(
                maxRedeem,
                userShares[i],
                1,
                "users should be able to redeem minimum at all their shares - 1"
            );
            redeem(userShares[i], users[i].addr);
        }

        assertEq(
            vault.oldestEpochIdUnwinded(),
            4,
            "epoch 4 should be the last epoch fully unwinded"
        );
    }

    function test_assetManagerUnwindMultipleEpochExpectLast() public {
        //set up, 4 users have funds in the vault
        VmSafe.Wallet[4] memory users = [user1, user2, user3, user4];
        for (uint256 i; i < users.length; i++) {
            dealAndApprove(users[i].addr);
            uint256 userAssets = assetBalance(users[i].addr);
            requestDeposit(userAssets, users[i].addr);
        }
        updateAndSettle(0);

        assertEq(vault.oldestEpochIdUnwinded(), 1); // since to unwind is zero,

        // they get their shares
        for (uint256 i; i < users.length; i++) {
            uint256 maxDep = vault.maxDeposit(users[i].addr);
            deposit(maxDep, users[i].addr);
        }

        // they asked to redeem
        uint256[4] memory userShares;
        for (uint256 i; i < users.length; i++) {
            userShares[i] = vault.balanceOf(users[i].addr);
            requestRedeem(userShares[i], users[i].addr);
            uint256 totalAssets = vault.totalAssets();
            updateAndSettle(totalAssets.mulDiv(101, 100)); // + 1%

            assertEq(vault.oldestEpochIdUnwinded(), 1); // nothing has been unwind yet
            assertEq(
                vault.maxRedeem(users[i].addr),
                0,
                "user should not be able to redeem"
            );
        }

        assertApproxEqAbs(vault.totalAssets(), 0, 1);
        assertEq(vault.epochId(), 6);
        uint256 toUnwind = vault.toUnwind() - vault.toUnwind(5);

        // assetManager will not unwind last epoch.
        unwind(toUnwind);
        for (uint256 i; i < users.length - 1; i++) {
            uint256 maxRedeem = vault.maxRedeem(users[i].addr);
            assertApproxEqAbs(
                maxRedeem,
                userShares[i],
                1,
                "users should be able to redeem minimum at all their shares - 1"
            );
            redeem(userShares[i], users[i].addr);
        }

        assertEq(
            vault.oldestEpochIdUnwinded(),
            4,
            "epoch 4 should be the last epoch fully unwinded"
        );
        assertEq(vault.maxRedeem(users[3].addr), 0);
    }
}
