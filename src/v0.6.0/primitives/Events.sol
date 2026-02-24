// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AccessMode, FeeType, State} from "./Enums.sol";
import {Rates} from "./Struct.sol";
import {Guardrails} from "./Struct.sol";

// ********************* VAULT ********************* //

/// @notice Emitted when a referral is made.
/// @param referral The address of the referral.
/// @param owner The address of the owner making the referral.
/// @param requestId The ID of the associated request.
/// @param assets The amount of assets involved in the referral.
event Referral(address indexed referral, address indexed owner, uint256 indexed requestId, uint256 assets);

/// @notice Emitted when the state of the vault is updated.
/// @param state The new state of the vault. Either Open, Closing or Close.
event StateUpdated(State state);

event SettleDeposit(
    uint40 indexed epochId,
    uint40 indexed settledId,
    uint256 totalAssets,
    uint256 totalSupply,
    uint256 assetsDeposited,
    uint256 sharesMinted
);

event SettleRedeem(
    uint40 indexed epochId,
    uint40 indexed settledId,
    uint256 totalAssets,
    uint256 totalSupply,
    uint256 assetsWithdrawed,
    uint256 sharesBurned
);

// ********************* WHITELISTABLE ********************* //

/// @notice Emitted when a whitelist entry is updated.
/// @param account The address of the account being updated.
/// @param authorized Indicates whether the account is authorized (true) or not (false).
event WhitelistUpdated(address indexed account, bool authorized);

/// @notice Emitted when a blacklist entry is updated.
/// @param account The address of the account being updated.
/// @param blacklisted Indicates whether the account is blacklisted (true) or not (false).
event BlacklistUpdated(address indexed account, bool blacklisted);

/// @notice Emitted when the whitelist is disabled.
event WhitelistDisabled();

/// @notice Emitted when the external sanctions list is updated.
/// @param oldExternalSanctionList The old external sanctions list.
/// @param newExternalSanctionList The new external sanctions list.
event ExternalSanctionsListUpdated(address oldExternalSanctionList, address newExternalSanctionList);

// ********************* ROLES ********************* //

/// @notice Emitted when the whitelist manager role is updated.
/// @param oldManager The address of the old whitelist manager.
/// @param newManager The address of the new whitelist manager.
event WhitelistManagerUpdated(address oldManager, address newManager);

/// @notice Emitted when the fee receiver role is updated.
/// @param oldReceiver The address of the old fee receiver.
/// @param newReceiver The address of the new fee receiver.
event FeeReceiverUpdated(address oldReceiver, address newReceiver);

/// @notice Emitted when the Valuation manager role is updated.
/// @param oldManager The address of the old Valuation manager.
/// @param newManager The address of the new Valuation manager.
event ValuationManagerUpdated(address oldManager, address newManager);

/// @notice Emitted when the safe role is updated.
/// @param oldSafe The address of the old safe.
/// @param newSafe The address of the new safe.
event SafeUpdated(address oldSafe, address newSafe);

/// @notice Emitted when the safe upgradeability is given up.
event SafeUpgradeabilityGivenUp();

/// @notice Emitted when the security council role is updated.
/// @param oldSecurityCouncil The address of the old security council.
/// @param newSecurityCouncil The address of the new security council.
event SecurityCouncilUpdated(address oldSecurityCouncil, address newSecurityCouncil);

/// @notice Emitted when the master operator role is updated.
/// @param oldSuperOperator The address of the old master operator.
/// @param newSuperOperator The address of the new master operator.
event SuperOperatorUpdated(address oldSuperOperator, address newSuperOperator);

// ********************* FEE_MANAGER ********************* //

/// @notice Emitted when the rates are updated.
/// @param oldRates The new rates.
/// @param newRate The new rates.
/// @param timestamp The timestamp at which the update will take effect.
event RatesUpdated(Rates oldRates, Rates newRate, uint256 timestamp);

/// @notice Emitted when the highWaterMark is updated.
/// @param oldHighWaterMark The old highWaterMark.
/// @param newHighWaterMark The new highWaterMark.
event HighWaterMarkUpdated(uint256 oldHighWaterMark, uint256 newHighWaterMark);

/// @notice Emitted when a fee is taken from the vault.
/// @param feeType The type of fee being taken.
/// @param shares The number of shares minted as fees.
/// @param rate The fee rate applied.
/// @param contextId The settleId for settlement fees (0 if not relevant).
/// @param managerShares The shares minted to the manager.
/// @param protocolShares The shares minted to the protocol.
event FeeTaken(
    FeeType indexed feeType,
    uint256 shares,
    uint16 rate,
    uint40 contextId,
    uint256 managerShares,
    uint256 protocolShares
);

/// @notice Emitted when haircut shares are burned during synchronous redeem.
/// @param owner The address whose shares were subject to haircut.
/// @param shares The number of shares taken as haircut.
/// @param rate The haircut rate applied.
event HaircutTaken(address indexed owner, uint256 shares, uint16 rate);

// ********************* ERC7540 ********************* //
/// @notice Emitted when the totalAssets variable is updated.
/// @param totalAssets The new total assets value.
event TotalAssetsUpdated(uint256 totalAssets);

/// @notice Emitted when the newTotalAssets variable is updated.
/// @param totalAssets The new newTotalAssets value.
event NewTotalAssetsUpdated(uint256 totalAssets);

/// @notice Emitted when a deposit request is canceled.
/// @param requestId The ID of the canceled request.
/// @param controller The address of the controller of the canceled request.
event DepositRequestCanceled(uint256 indexed requestId, address indexed controller);

/// @notice Emitted when the lifespan is updated.
/// @param oldLifespan The old lifespan.
/// @param newLifespan The new lifespan.
event TotalAssetsLifespanUpdated(uint128 oldLifespan, uint128 newLifespan);

/// @notice Same as a 4626 Deposit event
/// @param sender The address who gave its assets
/// @param owner The receiver of the shares
/// @param assets Amount of assets deposit
/// @param shares Amount of shares minted to owner
event DepositSync(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

/// @notice Emitted when the access mode is updated.
/// @param newMode The new access mode (Blacklist or Whitelist).
event AccessModeUpdated(AccessMode newMode);

/// @notice Emitted when the max cap is updated.
/// @param previousMaxCap The previous max cap.
/// @param maxCap The new max cap.
event MaxCapUpdated(uint256 previousMaxCap, uint256 maxCap);

/// @notice Emitted when the safe privileges are given up.
event GaveUpSafePrivileges();

/// @notice Same as a 4626 Withdraw event
/// @param sender The address who called the withdraw
/// @param receiver The receiver of the assets
/// @param owner The owner of the shares
/// @param assets Amount of assets withdrawn
/// @param shares Amount of shares redeemed
event WithdrawSync(
    address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
);

// ********************* GUARDRAILS_MANAGER ********************* //

/// @notice Emitted when the guardrails are updated.
/// @param oldGuardrails The old guardrails.
/// @param newGuardrails The new guardrails.
event GuardrailsUpdated(Guardrails oldGuardrails, Guardrails newGuardrails);

/// @notice Emitted when the activated status of the guardrails is updated.
/// @param activated The new activated status.
event GuardrailsStatusUpdated(bool activated);

// ********************* ERC20 ********************* //

/// @notice Emitted when the name of the ERC20 token is updated.
/// @param previousName The previous name of the ERC20 token.
/// @param newName The new name of the ERC20 token.
event NameUpdated(string previousName, string newName);

/// @notice Emitted when the symbol of the ERC20 token is updated.
/// @param previousSymbol The previous symbol of the ERC20 token.
/// @param newSymbol The new symbol of the ERC20 token.
event SymbolUpdated(string previousSymbol, string newSymbol);
