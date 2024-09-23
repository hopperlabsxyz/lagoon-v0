// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {State} from "./Enums.sol";

/// Vault ///
error NotOpen(State currentState);
error NotClosing(State currentState);
error NewTotalAssetsMissing();
error NotEnoughLiquidity(uint256 currentLiquidity, uint256 expectedLiquidity);

/// ERC7540 ///
error ERC7540PreviewDepositDisabled();
error ERC7540PreviewMintDisabled();
error ERC7540PreviewRedeemDisabled();
error ERC7540PreviewWithdrawDisabled();
error OnlyOneRequestAllowed();
error RequestNotCancelable(uint256 requestId);
error ERC7540InvalidOperator();
error ZeroPendingDeposit();
error ZeroPendingRedeem();
error RequestIdNotClaimable();
error CantDepositNativeToken();
error NotWhitelisted();

/// FeeManager ///
error AboveMaxRate(uint256 rate, uint256 maxRate);
error CooldownNotOver(uint256 timeLeft);

/// Roles ///
error OnlySafe(address safe);
error OnlyWhitelistManager(address whitelistManager);
error OnlyTotalAssetsManager(address totalAssetsManager);

/// WhitelistableUpgradeable ///
error MerkleTreeMode();
