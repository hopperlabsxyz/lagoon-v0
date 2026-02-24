## Whitelist / Blacklist Behaviour Specification

This document specifies how whitelist / blacklist modes affect user permissions and how the `superOperator` can bypass restrictions.

### Concepts & Roles

- **Blacklist mode**: A *blacklist* is enforced; blacklisted users are fully frozen as defined below.
- **Whitelist mode**: A *whitelist* is enforced; only whitelisted users are allowed to perform restricted operations, but transfers remain open (for DeFi integrations).
- **Mode exclusivity**: Blacklist mode and whitelist mode are **mutually exclusive**; only one of them can be active at a time.
- **Owner**: The address considered as the owner of the position / shares / assets involved in the operation.
- **Controller**: The address that will controls the request.
- **User**: Unless stated otherwise, “user” refers to both the owner and the controller involved in a given call.
- **Operator**: The address that can perform the operation on behalf of the user, it is msg.sender.
- **SuperOperator**: A privileged address that can perform certain operations on behalf of users that are otherwise not allowed by whitelist / blacklist constraints.

---

### Behaviour in Blacklist Mode

- **Transfers**
  - **Rule**: A transfer **MUST NOT** happen if **either** the sender or the receiver is a blacklisted user.
  - **Implication**: For regular users, both `from` and `to` addresses MUST be non-blacklisted. The `superOperator` can override this (see below).

- **User-facing operations (blocked when user is blacklisted)**
  - **requestDeposit**
  - **requestRedeem**
  - **deposit**
  - **mint**
  - **redeem**
  - **withdraw**
  - **cancelDeposit**
  - **claimAndRequestRedeem**
  - **syncRedeem**
  - **syncDeposit**

  - **Rule**: In blacklist mode, any of the above operations **MUST REVERT** if **either**:
    - the **owner** is blacklisted, **or**
    - the **controller** is blacklisted
    - and the **operator** is not the `superOperator` or the **operator** is blacklisted.

---

### Behaviour in Whitelist Mode

- **Transfers**
  - **Rule**: A transfer **MAY** happen regardless of whitelist status of the sender and recipient; both **whitelisted** and **non‑whitelisted** addresses are allowed.
  - **Rationale**: This is to allow DeFi integrations that require free movement of tokens between addresses that are not fully onboarded.

- **User-facing operations (blocked when user is not whitelisted)**
  - **requestDeposit**
  - **requestRedeem**
  - **deposit**
  - **mint**
  - **redeem**
  - **withdraw**
  - **cancelDeposit**
  - **claimAndRequestRedeem**
  - **syncRedeem**
  - **syncDeposit**


  - **Rule**: In whitelist mode, any of the above operations **MUST REVERT** if either:
    - the **owner** is **not whitelisted**, **or**
    - the **controller** is **not whitelisted**
    - and the **operator** is not the `superOperator` or the **operator** is not whitelisted.
  - **Effect**: Non‑whitelisted users are **fully frozen** for these operations (cannot deposit, redeem, withdraw, etc.), except via `superOperator`.


---

### SuperOperator Behaviour (Both Modes)

In both blacklist and whitelist modes, the `superOperator` has extended capabilities to act for users that are otherwise not allowed.

- **SuperOperator capabilities (both modes)**
  - **requestRedeem**, **redeem**, **withdraw**
  - **deposit**, **mint**


- **Rule (operations)**: The `superOperator` **MUST BE ABLE TO** call each of the above operations **even if** the owner / controller is:
  - blacklisted in blacklist mode, **or**
  - not whitelisted in whitelist mode,
  - **unless** this would violate external regulatory or protocol-level hard constraints explicitly defined elsewhere.

- **Rule (transfers)**:
  - In **blacklist mode**, the `superOperator` **CAN** initiate transfers **from and to any address**, including blacklisted ones.
  - In **whitelist mode**, the `superOperator` **CAN** initiate transfers **from and to any address** as well.

- **Rule**: `superOperator` calls **MUST** still respect:
  - Hard protocol invariants (e.g. pause state, fees etc.),


- **superOperator** can't be used for *requestDeposit*, *syncDeposit*, *syncRedeem*, *claimSharesAndRequestRedeem* operations.

- **superOperator** can be used for **cancelRequestDeposit** operations except if the user is blacklisted or not whitelisted.


## Summary of Behaviour

1. **Modes are exclusive**: only whitelist *or* blacklist mode is active at a time.
2. **Transfers**:
   - Whitelist mode: transfers allowed between any addresses; operations restricted to whitelisted users.
   - Blacklist mode: regular users cannot transfer from/to blacklisted addresses; `superOperator` can transfer from/to any address.
3. **Operations**: All restricted operations revert if owner, controller or operator is not allowed (blacklisted / not whitelisted), except when executed by `superOperator`.
4. **SuperOperator**: Can perform all listed operations and transfers on behalf of disallowed users in both modes, subject only to “cannot ever interact” hard flags. Some operations are not allowed to be performed by the superOperator because they are not necessary.
