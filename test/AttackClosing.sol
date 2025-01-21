// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC7540InvalidOperator} from "@src/vault/ERC7540.sol";
import {Closed, NotClosing, NotOpen, State, Vault} from "@src/vault/Vault.sol";
import "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract TestInitiateClosing is BaseTest {
    uint256 user1AssetsBeginning = 0;
    uint256 user2AssetsBeginning = 0;
    uint256 user3AssetsBeginning = 0;

    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        State s = vault.state();
        require(s == State.Open, "vault should be open");
        dealAndApprove(user1.addr); // if we deal 100k assets
        dealAndApprove(user2.addr); // if we deal 100k assets
        dealAndApprove(user3.addr); // if we deal 100k assets

        uint256 user1Assets = assetBalance(user1.addr);
        user1AssetsBeginning = user1Assets; // 100k assets

        uint256 user2Assets = assetBalance(user2.addr);
        user2AssetsBeginning = user2Assets; // 100k assets

        uint256 user3Assets = assetBalance(user3.addr);
        user3AssetsBeginning = user3Assets; // 100k assets

        requestDeposit(user1Assets / 2, user1.addr); // 50k assets
        requestDeposit(user2Assets / 2, user2.addr); // 50k assets
        requestDeposit(user3Assets / 2, user3.addr); // 50k assets

        // user1: 50k shares claimable
        // user2: 50k shares claimable
        // user3: 50k shares claimable
        updateAndSettle(0);

        // User2 claims 50k shares
        vm.startPrank(user2.addr);
        vault.deposit(user2Assets / 2, user2.addr);

        // user2 ask for redemption on half of his shares
        vault.requestRedeem(25_000 * 10 ** vault.decimals(), user2.addr, user2.addr); // 25k shares pending
        vm.stopPrank();

        // User3 claims 50k shares
        vm.prank(user3.addr);
        vault.deposit(user3Assets / 2, user3.addr);

        // user1: 50k shares claimable
        // user2:
        //    - 25k assets claimable
        //    - 25k shares holding
        // user3: 50k shares holding
        updateAndSettle(150_000 * 10 ** vault.underlyingDecimals());

        vm.warp(block.timestamp + 30 days);

        assertEq(uint256(vault.state()), uint256(State.Open));

        // Invariant: We can't call close without initiating close
        vm.prank(safe.addr);
        vm.expectRevert(abi.encodeWithSelector(NotClosing.selector, State.Open));
        vault.close();

        // user 3 request deposit before vault goes into closing state
        requestDeposit(user3Assets / 2, user3.addr); // 50k assets
        // user 3 request redeem before vault goes into closing state on half of his shares
        requestRedeem(25_000 * 10 ** vault.decimals(), user3.addr); // 25k shares pending
        

        
        

        // assertEq(uint256(vault.state()), uint256(State.Closing));

        // // user1: 50k shares claimable
        // // user2:
        // //    - 25k assets claimable
        // //    - 25k shares holding
        // // user3:
        // //    - 25k shares holding
        // //    - 25k shares pending redeem
        // //    - 50k assets pending deposit
        // console.log("total assets       ", vault.totalAssets());
        // console.log("asset balance vault", assetBalance(address(vault)));
        // console.log("asset balance safe ", assetBalance(safe.addr));

        // vm.warp(block.timestamp + 1 days);
    }

    function test_aRequestRedeemAfterNewTTAUpdateMustNotBeLockedBecauseOfClosing() public {
        updateNewTotalAssets(vault.totalAssets());
        uint256 userShares = vault.balanceOf(user2.addr);
        requestRedeem(userShares, user2.addr);

        vm.prank(admin.addr);
        vault.initiateClosing();

        vm.prank(safe.addr);
        vault.close();


        assertNotEq(vault.claimableRedeemRequest(0, user2.addr), 0);
        assertEq(vault.claimableRedeemRequest(0, user2.addr), userShares);
        uint256 pendingRedeem = vault.pendingRedeemRequest(0, user2.addr);
        assertEq(pendingRedeem, 0);

        vm.startPrank(user2.addr);
        vault.redeem(1 * 10 ** vault.decimals(), user2.addr, user2.addr);
    }
}