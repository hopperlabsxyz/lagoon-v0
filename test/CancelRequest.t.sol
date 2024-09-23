// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {Vault} from "@src/vault/Vault.sol";
import {RequestNotCancelable} from "@src/vault/ERC7540.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseTest} from "./Base.sol";

contract TestCancelRequest is BaseTest {
    function setUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        dealAndApprove(user1.addr);
        uint256 user1Assets = assetBalance(user1.addr);
        requestDeposit(user1Assets / 2, user1.addr);

        updateAndSettle(0);
        deposit(user1Assets / 2, user1.addr);
    }

    function test_cancelRequestDeposit() public {
        uint256 assetsBeforeRequest = assetBalance(user1.addr);
        requestDeposit(assetsBeforeRequest / 2, user1.addr);
        uint256 assetsBeforeCancel = assetBalance(user1.addr);
        vm.prank(user1.addr);
        vault.cancelRequestDeposit();
        uint256 assetsAfterCancel = assetBalance(user1.addr);
        assertLt(assetsBeforeCancel, assetsAfterCancel);
        assertEq(assetsAfterCancel, assetsBeforeRequest);
    }

    function test_cancelRequestDeposit_when0PendingRequest() public {
        vm.startPrank(user1.addr);
        vm.expectRevert();
        vault.cancelRequestDeposit();
        vm.stopPrank();
    }

    function test_cancelRequestDeposit_revertsWhenNewTotalAssetsHasBeenUpdated()
        public
    {
        uint256 assetsBeforeRequest = assetBalance(user1.addr);

        uint256 requestId = requestDeposit(assetsBeforeRequest / 2, user1.addr);

        updateNewTotalAssets(0);

        vm.prank(user1.addr);
        vm.expectRevert(
            abi.encodeWithSelector(RequestNotCancelable.selector, requestId)
        );
        vault.cancelRequestDeposit();
    }
}
