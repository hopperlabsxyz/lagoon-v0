## `cancelRequestRedeem` Specification

### Purpose
Allows cancellation of a pending redeem request, returning shares from the `pendingSilo` back to the controller before settlement occurs.

### Function Signature
```solidity
function cancelRequestRedeem(address controller) external
```

### Access Control
- **Modifier:** `onlyOperatorOrSuperOperator(controller)`
  - The controller themselves can cancel (`msg.sender == controller`)
  - A registered operator of the controller can cancel
  - The superOperator can cancel on behalf of any user **except** the `protocolFeeReceiver`
- **Pause protection:** Implicit via `ERC20._transfer` in the share transfer (reverts with `EnforcedPause`)
- **No whitelist/blacklist check:** Blacklisted users can cancel their pending redeem requests

### Preconditions
- The controller must have a pending redeem request in the **current epoch** (`lastRedeemRequestId[controller] == redeemEpochId`)
- `updateNewTotalAssets` must **not** have been called since the request was made (which would have advanced the epoch)

### Behavior
1. Reads the controller's `lastRedeemRequestId` and verifies it matches the current `redeemEpochId`
2. Reads the pending share amount from `epochs[requestId].redeemRequest[controller]`
3. Zeros out the request: `epochs[requestId].redeemRequest[controller] = 0`
4. Transfers shares back from `pendingSilo` to `controller` via `transmitFrom` (uses `ERC20._transfer` internally to bypass approval and access-control hooks)
5. Emits `RedeemRequestCanceled(requestId, controller, requestedAmount)`

### Reverts
| Condition | Error |
|-----------|-------|
| Caller is not controller, operator, or superOperator | `ERC7540InvalidOperator` |
| SuperOperator acting on `protocolFeeReceiver` | `ERC7540InvalidOperator` |
| Request epoch doesn't match current epoch (already settled, never requested, or NAV updated) | `RequestNotCancelable(requestId)` |
| Vault is paused | `EnforcedPause` |

### Event
```solidity
event RedeemRequestCanceled(uint256 indexed requestId, address indexed controller, uint256 requestedAmount)
```
