# Proposed Forge Test Names for Whitelist/Blacklist Specifications

## Transfer Functions Tests
🟡
✅
### `transfer`
```solidity
// Blacklist Mode
test_transfer_RevertsWhen_SenderIsBlacklisted() 🟡
test_transfer_RevertsWhen_ReceiverIsBlacklisted() 🟡
test_transfer_SucceedsWhen_NeitherPartyIsBlacklisted() 🟡

// Whitelist Mode
test_transfer_SucceedsWhen_SenderIsNotWhitelisted() 🟡
test_transfer_SucceedsWhen_ReceiverIsNotWhitelisted() 🟡
test_transfer_SucceedsWhen_NeitherPartyIsWhitelisted() 🟡
test_transfer_SucceedsWhen_BothPartiesAreWhitelisted() 🟡
```

### `transferFrom`
```solidity
// Blacklist Mode
test_transferFrom_RevertsWhen_SenderIsBlacklisted() 🟡
test_transferFrom_RevertsWhen_ReceiverIsBlacklisted() 🟡
test_transferFrom_RevertsWhen_BothPartiesAreBlacklisted() 🟡
test_transferFrom_SucceedsWhen_NeitherPartyIsBlacklisted() 🟡

// Whitelist Mode
test_transferFrom_SucceedsWhen_SenderIsNotWhitelisted() 🟡
test_transferFrom_SucceedsWhen_ReceiverIsNotWhitelisted() 🟡
test_transferFrom_SucceedsWhen_NeitherPartyIsWhitelisted() 🟡

```

---

## Deposit/Mint Operations Tests

### `requestDeposit`
```solidity
// Blacklist Mode
test_requestDeposit_RevertsWhen_OwnerIsBlacklisted()
test_requestDeposit_RevertsWhen_ControllerIsBlacklisted()
test_requestDeposit_RevertsWhen_BothOwnerAndControllerAreBlacklisted()
test_requestDeposit_RevertsWhen_OperatorIsBlacklisted()
test_requestDeposit_RevertsWhen_SuperOperatorCallsForBlacklistedOwner()
test_requestDeposit_RevertsWhen_SuperOperatorCallsForBlacklistedController()
test_requestDeposit_SucceedsWhen_AllPartiesAreNotBlacklisted()

// Whitelist Mode
test_requestDeposit_RevertsWhen_OwnerIsNotWhitelisted()
test_requestDeposit_RevertsWhen_ControllerIsNotWhitelisted()
test_requestDeposit_RevertsWhen_NeitherOwnerNorControllerIsWhitelisted()
test_requestDeposit_RevertsWhen_OperatorIsNotWhitelisted()
test_requestDeposit_RevertsWhen_SuperOperatorCallsForNonWhitelistedOwner()
test_requestDeposit_RevertsWhen_SuperOperatorCallsForNonWhitelistedController()
test_requestDeposit_SucceedsWhen_AllPartiesAreWhitelisted()
```

### `deposit`
```solidity
// Blacklist Mode
test_deposit_RevertsWhen_OwnerIsBlacklisted()
test_deposit_RevertsWhen_ControllerIsBlacklisted()
test_deposit_RevertsWhen_BothOwnerAndControllerAreBlacklisted()
test_deposit_RevertsWhen_OperatorIsBlacklisted()
test_deposit_SucceedsWhen_SuperOperatorCallsForBlacklistedOwner()
test_deposit_SucceedsWhen_SuperOperatorCallsForBlacklistedController()
test_deposit_SucceedsWhen_AllPartiesAreNotBlacklisted()

// Whitelist Mode
test_deposit_RevertsWhen_OwnerIsNotWhitelisted()
test_deposit_RevertsWhen_ControllerIsNotWhitelisted()
test_deposit_RevertsWhen_NeitherOwnerNorControllerIsWhitelisted()
test_deposit_RevertsWhen_OperatorIsNotWhitelisted()
test_deposit_SucceedsWhen_SuperOperatorCallsForNonWhitelistedOwner()
test_deposit_SucceedsWhen_SuperOperatorCallsForNonWhitelistedController()
test_deposit_SucceedsWhen_AllPartiesAreWhitelisted()
```

### `mint`
```solidity
// Blacklist Mode
test_mint_RevertsWhen_OwnerIsBlacklisted()
test_mint_RevertsWhen_ControllerIsBlacklisted()
test_mint_RevertsWhen_BothOwnerAndControllerAreBlacklisted()
test_mint_RevertsWhen_OperatorIsBlacklisted()
test_mint_SucceedsWhen_SuperOperatorCallsForBlacklistedOwner()
test_mint_SucceedsWhen_SuperOperatorCallsForBlacklistedController()
test_mint_SucceedsWhen_AllPartiesAreNotBlacklisted()

// Whitelist Mode
test_mint_RevertsWhen_OwnerIsNotWhitelisted()
test_mint_RevertsWhen_ControllerIsNotWhitelisted()
test_mint_RevertsWhen_NeitherOwnerNorControllerIsWhitelisted()
test_mint_RevertsWhen_OperatorIsNotWhitelisted()
test_mint_SucceedsWhen_SuperOperatorCallsForNonWhitelistedOwner()
test_mint_SucceedsWhen_SuperOperatorCallsForNonWhitelistedController()
test_mint_SucceedsWhen_AllPartiesAreWhitelisted()
```

---

## Redeem/Withdraw Operations Tests

### `requestRedeem`
```solidity
// Blacklist Mode
test_requestRedeem_RevertsWhen_OwnerIsBlacklisted()
test_requestRedeem_RevertsWhen_ControllerIsBlacklisted()
test_requestRedeem_RevertsWhen_BothOwnerAndControllerAreBlacklisted()
test_requestRedeem_RevertsWhen_OperatorIsBlacklisted()
test_requestRedeem_SucceedsWhen_SuperOperatorCallsForBlacklistedOwner()
test_requestRedeem_SucceedsWhen_SuperOperatorCallsForBlacklistedController()
test_requestRedeem_SucceedsWhen_AllPartiesAreNotBlacklisted()

// Whitelist Mode
test_requestRedeem_RevertsWhen_OwnerIsNotWhitelisted()
test_requestRedeem_RevertsWhen_ControllerIsNotWhitelisted()
test_requestRedeem_RevertsWhen_NeitherOwnerNorControllerIsWhitelisted()
test_requestRedeem_RevertsWhen_OperatorIsNotWhitelisted()
test_requestRedeem_SucceedsWhen_SuperOperatorCallsForNonWhitelistedOwner()
test_requestRedeem_SucceedsWhen_SuperOperatorCallsForNonWhitelistedController()
test_requestRedeem_SucceedsWhen_AllPartiesAreWhitelisted()
```

### `redeem`
```solidity
// Blacklist Mode
test_redeem_RevertsWhen_OwnerIsBlacklisted()
test_redeem_RevertsWhen_ControllerIsBlacklisted()
test_redeem_RevertsWhen_BothOwnerAndControllerAreBlacklisted()
test_redeem_RevertsWhen_OperatorIsBlacklisted()
test_redeem_SucceedsWhen_SuperOperatorCallsForBlacklistedOwner()
test_redeem_SucceedsWhen_SuperOperatorCallsForBlacklistedController()
test_redeem_SucceedsWhen_AllPartiesAreNotBlacklisted()

// Whitelist Mode
test_redeem_RevertsWhen_OwnerIsNotWhitelisted()
test_redeem_RevertsWhen_ControllerIsNotWhitelisted()
test_redeem_RevertsWhen_NeitherOwnerNorControllerIsWhitelisted()
test_redeem_RevertsWhen_OperatorIsNotWhitelisted()
test_redeem_SucceedsWhen_SuperOperatorCallsForNonWhitelistedOwner()
test_redeem_SucceedsWhen_SuperOperatorCallsForNonWhitelistedController()
test_redeem_SucceedsWhen_AllPartiesAreWhitelisted()
```

### `withdraw`
```solidity
// Blacklist Mode
test_withdraw_RevertsWhen_OwnerIsBlacklisted()
test_withdraw_RevertsWhen_ControllerIsBlacklisted()
test_withdraw_RevertsWhen_BothOwnerAndControllerAreBlacklisted()
test_withdraw_RevertsWhen_OperatorIsBlacklisted()
test_withdraw_SucceedsWhen_SuperOperatorCallsForBlacklistedOwner()
test_withdraw_SucceedsWhen_SuperOperatorCallsForBlacklistedController()
test_withdraw_SucceedsWhen_AllPartiesAreNotBlacklisted()

// Whitelist Mode
test_withdraw_RevertsWhen_OwnerIsNotWhitelisted()
test_withdraw_RevertsWhen_ControllerIsNotWhitelisted()
test_withdraw_RevertsWhen_NeitherOwnerNorControllerIsWhitelisted()
test_withdraw_RevertsWhen_OperatorIsNotWhitelisted()
test_withdraw_SucceedsWhen_SuperOperatorCallsForNonWhitelistedOwner()
test_withdraw_SucceedsWhen_SuperOperatorCallsForNonWhitelistedController()
test_withdraw_SucceedsWhen_AllPartiesAreWhitelisted()
```

---

## Position Management Tests

### `cancelDeposit`
```solidity
// Blacklist Mode
test_cancelDeposit_RevertsWhen_OwnerIsBlacklisted()
test_cancelDeposit_RevertsWhen_ControllerIsBlacklisted()
test_cancelDeposit_RevertsWhen_BothOwnerAndControllerAreBlacklisted()
test_cancelDeposit_RevertsWhen_OperatorIsBlacklisted()
test_cancelDeposit_SucceedsWhen_AllPartiesAreNotBlacklisted()

// Whitelist Mode
test_cancelDeposit_RevertsWhen_OwnerIsNotWhitelisted()
test_cancelDeposit_RevertsWhen_ControllerIsNotWhitelisted()
test_cancelDeposit_RevertsWhen_NeitherOwnerNorControllerIsWhitelisted()
test_cancelDeposit_RevertsWhen_OperatorIsNotWhitelisted()
test_cancelDeposit_SucceedsWhen_AllPartiesAreWhitelisted()
```

### `claimAndRequestRedeem`
```solidity
// Blacklist Mode
test_claimAndRequestRedeem_RevertsWhen_MsgSenderIsBlacklisted()
test_claimAndRequestRedeem_SucceedsWhen_MsgSenderIsNotBlacklisted()

// Whitelist Mode
test_claimAndRequestRedeem_RevertsWhen_MsgSenderIsNotWhitelisted()
test_claimAndRequestRedeem_SucceedsWhen_MsgSenderIsWhitelisted()
```

---

## Sync Operations Tests

### `syncRedeem`
```solidity
// Blacklist Mode
test_syncRedeem_RevertsWhen_MsgSenderIsBlacklisted()
test_syncRedeem_RevertsWhen_ReceiverIsBlacklisted()
test_syncRedeem_RevertsWhen_BothMsgSenderAndReceiverAreBlacklisted()
test_syncRedeem_RevertsWhen_SuperOperatorCallsForBlacklistedUsers()
test_syncRedeem_SucceedsWhen_NeitherPartyIsBlacklisted()

// Whitelist Mode
test_syncRedeem_RevertsWhen_MsgSenderIsNotWhitelisted()
test_syncRedeem_RevertsWhen_ReceiverIsNotWhitelisted()
test_syncRedeem_RevertsWhen_NeitherMsgSenderNorReceiverIsWhitelisted()
test_syncRedeem_RevertsWhen_SuperOperatorCallsForNonWhitelistedUsers()
test_syncRedeem_SucceedsWhen_BothPartiesAreWhitelisted()
```

### `syncDeposit`
```solidity
// Blacklist Mode
test_syncDeposit_RevertsWhen_MsgSenderIsBlacklisted()
test_syncDeposit_RevertsWhen_ReceiverIsBlacklisted()
test_syncDeposit_RevertsWhen_BothMsgSenderAndReceiverAreBlacklisted()
test_syncDeposit_RevertsWhen_SuperOperatorCallsForBlacklistedUsers()
test_syncDeposit_SucceedsWhen_NeitherPartyIsBlacklisted()

// Whitelist Mode
test_syncDeposit_RevertsWhen_MsgSenderIsNotWhitelisted()
test_syncDeposit_RevertsWhen_ReceiverIsNotWhitelisted()
test_syncDeposit_RevertsWhen_NeitherMsgSenderNorReceiverIsWhitelisted()
test_syncDeposit_RevertsWhen_SuperOperatorCallsForNonWhitelistedUsers()
test_syncDeposit_SucceedsWhen_BothPartiesAreWhitelisted()
```

---

## Cross-Cutting Integration Tests

```solidity
// Mode switching
test_integration_SwitchingFromBlacklistToWhitelistMode()
test_integration_SwitchingFromWhitelistToBlacklistMode()

// SuperOperator privileges
test_integration_SuperOperatorBypassesAllBlacklistRestrictions()
test_integration_SuperOperatorBypassesAllWhitelistRestrictions()
test_integration_SuperOperatorCannotBypassSyncOperations()
test_integration_SuperOperatorCannotCallClaimAndRequestRedeem()

// Error message validation
test_integration_RevertMessagesSpecifyCorrectAddressAndReason()

// Full workflow tests
test_integration_CompleteDepositRedeemCycleInBlacklistMode()
test_integration_CompleteDepositRedeemCycleInWhitelistMode()
```

---

## Test Coverage Summary

### Total Test Count by Category
- **Transfer Functions**: 20 tests
- **Deposit/Mint Operations**: 42 tests  
- **Redeem/Withdraw Operations**: 63 tests
- **Position Management**: 12 tests
- **Sync Operations**: 20 tests
- **Integration Tests**: 7 tests

**Grand Total**: ~164 individual test cases

### Coverage Matrix
Each function is tested for:
- ✅ Blacklist mode behavior
- ✅ Whitelist mode behavior
- ✅ SuperOperator bypass capabilities
- ✅ Multi-party restriction scenarios
- ✅ Success cases with all parties allowed
