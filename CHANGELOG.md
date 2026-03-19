# Changelog

All notable changes to the Lagoon Protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.6.0] - Unreleased

### Added

- **Entry & exit fees** — Entry fees deducted from shares at deposit settlement; exit fees deducted from shares at redeem settlement and on vault close withdrawals. Rates are capped and can only decrease once set.
- **Synchronous redeem with haircut** — New `syncRedeem` function for instant ERC-4626-style withdrawals. A haircut fee (max 20%) is redistributed to remaining holders via share burning. Can be toggled by the Safe via `setIsSyncRedeemAllowed`. Disabled during closing/closed states.
- **Async-only vault mode** — Vaults can enforce async-only operation, blocking sync redeems entirely.
- **Slippage protection** — `minimumAssets` parameter on `syncRedeem` to protect against unfavorable execution.
- **Access control overhaul (`Accessable`)** — Replaces the previous `Whitelistable` contract with mutually exclusive Whitelist and Blacklist modes. Blacklist mode fully freezes blacklisted users (transfers and operations). Whitelist mode restricts operations to whitelisted users while keeping transfers open for DeFi composability.
- **ChainAnalysis sanctions list integration** — External compliance check via on-chain sanctions oracle.
- **SuperOperator role** — Privileged address that can act on behalf of restricted users (blacklisted or non-whitelisted) for `requestRedeem`, `redeem`, `withdraw`, `deposit`, `mint`, and `transferFrom` (without allowance). Cannot perform `requestDeposit`, `syncDeposit`, `syncRedeem`, or `claimAndRequestRedeem`.
- **Guardrails system** — Security Council can define upper and lower APR bounds on `totalAssets` evolution. `updateNewTotalAssets` reverts if the price-per-share change exceeds limits. Can be activated, deactivated, or bypassed by the Security Council.
- **Security Council role** — New role for managing guardrails configuration and emergency totalAssets updates. Address updatable by the Owner.
- **MaxCap system** — Safe can set a maximum asset cap enforced on `syncDeposit`, `requestDeposit`, and native ETH deposits. Default: `type(uint256).max`.
- **Batch claim on behalf** — `claimSharesOnBehalf(address[])` and `claimAssetsOnBehalf(address[])` allow the Safe to batch-claim for multiple controllers.
- **High water mark reset** — Ability to reset the performance fee high water mark.
- **Vault metadata updates** — Owner can update vault name and symbol post-deployment via `updateName` and `updateSymbol`.
- **Average-based management fee computation** — Management fees now computed on the average of previous and new `totalAssets` for fairer fee accrual over the period.
- **TotalAssets expiry** — Safe can invalidate the current `totalAssets` valuation via `expireTotalAssets`, forcing async-only mode. Lifespan is configurable via `updateTotalAssetsLifespan`.
- **Pre-mint / vault initialization** — `totalAssets` can be initialized at deployment for migration from previous vaults; shares minted to the Safe without actual asset transfer.
- **Protocol v3 factory** — New `OptinProxyFactory` under `protocol-v3/` supporting v0.6.0 vault deployment.
- **Comprehensive test suite** — Full coverage under `test/v0.6.0/` for all new features including async-only mode, sync redeem, fees, guardrails, MaxCap, SuperOperator, blacklist/whitelist, storage collisions, and compliance.

### Changed

- **Library extraction for bytecode reduction** — Core logic moved to libraries: `ERC7540Lib`, `FeeLib`, `RolesLib`, `AccessableLib`, `GuardrailsLib`, `VaultLib`, `ERC20Lib`, `PausableLib`.
- **VaultInit separation** — Initialization logic extracted to `VaultInit.sol`, deployed separately and delegate-called by the vault during `initialize`.
- **Management fee initial timestamp** — `lastFeeTime` now initialized to the deployment block timestamp instead of first settlement.
- **Checks-Effects-Interactions** — Adjusted operation ordering to respect the CEI pattern.

### Removed

- **Old vault versions** — Removed source code and tests for v0.1.0, v0.2.0, v0.3.0, and v0.4.0.
- **Fee rate update cooldown** — Cooldown mechanism removed entirely.
- **Deactivated whitelist mode** — Only Whitelist and Blacklist modes remain; the previous "deactivated" state is no longer supported.

### Fixed

- **NM-0822 Finding 1** — Enforce `maxCap` for native ETH deposits.
- **NM-0822 Finding 2** — Align EIP-7201 storage annotations.
- **TOB audit recommendations** — Prevent `requestRedeem` for controller `address(0)`; verify implementation address during upgrades.
- **ERC7201 custom storage tag** — Corrected namespace tag.
- **NatSpec documentation** — Fixed inconsistencies across contracts.

### Security

- Entry and exit fee rates can only decrease (never increase) after initial configuration.
- `updateNewTotalAssets` blocked while `syncRedeem` is allowed to prevent valuation manipulation.
- SuperOperator cannot interact with the `protocolFeeReceiver`.
- Access checks enforced inside `_mint`, `_deposit`, `_withdraw`, and `_redeem` internal functions.
