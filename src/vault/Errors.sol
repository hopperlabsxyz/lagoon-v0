// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

/// Vault ///
error NotOpen();
error NotClosing();
error NotClosed();
error NewTotalAssetsMissing();
error NotEnoughLiquidity();

/// ERC7540 ///
error ERC7540PreviewDepositDisabled();
error ERC7540PreviewMintDisabled();
error ERC7540PreviewRedeemDisabled();
error ERC7540PreviewWithdrawDisabled();
error OnlyOneRequestAllowed();
error RequestNotCancelable();
error ERC7540InvalidOperator();
error ZeroPendingDeposit();
error ZeroPendingRedeem();
error RequestIdNotClaimable();
error CantDepositNativeToken();

/// FeeManager ///
error AboveMaxRate(uint256 rate, uint256 maxRate);
error CooldownNotOver();

/// Roles ///
error OnlySafe();
error OnlyWhitelistManager();
error OnlyTotalAssetsManager();

/// WhitelistableUpgradeable ///

error NotWhitelisted(address account);
error MerkleTreeMode();
