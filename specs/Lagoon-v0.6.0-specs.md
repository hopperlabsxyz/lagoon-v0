# Lagoon Protocol v0.6.0 Specifications

## Entry Fee

- **General description:** The entry fee is a fee that is charged when a user deposits funds into a vault.
- **How it works:** It should be taken from the shares given to the user. It should only be taken at the settlement of the deposit.
- **Max Value:** 10%.

## Exit Fee

- **General description:** The exit fee is a fee that is charged when a user withdraws funds from a vault.
- **How it works:** It should be taken from the shares sent back by the user to the vault when he does a redemption request. It should only be taken at the settlement of the withdrawal.
- **Special note:** When a vault gets closed, the exit fee is not taken immediately. It should be taken from all the users when they withdraw. SuperOperator can withdraw the assets on behalf of users.
- **Max Value:** 10%.

## Synchronous Redeem

- **General description:** The synchronous withdrawal is a withdrawal that mimic the ERC4626 withdrawal system. It can be disabled by the Safe. It should arrive after exit fees.
- **How it works:** Same as synchronous deposit. It expects totalAssets to not be expired and activated. It can be subject to a haircut. See haircut section.
- **Special note:** When a vault is closed or closing, this special synchronous withdrawal with haircut is not allowed.

## Haircut

- **General description:** The haircut is a fee that is charged when a user withdraws in a synchronous fashion from a vault. The fee is redistributed to the other users by burning the shares.
- **How it works:** It is taken as a percentage of the shares sent back by the user to the vault when he does a synchronous withdrawal, it is computed after the exit fee.
- **Special note:** When a vault is closed or closing, the synchronous withdrawal with haircut is not allowed.
- **Max Value:** 10%.

## Redeem on Behalf

- **General description:** The redeem on behalf is a feature that allows the Safe to redeem shares on behalf of any user.
- **Special note:** As the Safe it should not be possible to redeem on behalf of a user that is not allowed: blacklisted or not whitelisted. See blacklist/whitelist mode specification.

## MaxCap system

- **General description:** The max cap system is a system that allows the Safe to set a maximum number of assets that can held by the vault.
- **How it works:** In any deposit related operation: syncDeposit and requestDeposit, a check is made to be sure that:
  - current total assets + request deposit amount + pending deposit assets <= max cap
- **Special note:** The redemptions requests are not taken into account in the max cap check. Updating totalAssets to a value superior to the max cap is allowed.
- **Default value:** uint256.max

## Guardrails

- **General description:** The guardrails are a system that allows the Security Council to set a maximum and minimum rate of evolution of the total assets over 1 year (APR). It can be switched off by the Security Council. If the evolution is outside the guardrails limits, the update of newTotalAssets is reverted.
- **How it works:** In any update of totalAssets, a check is made to be sure that the price per share evolution will evolve among the guardrails limits. Upper limit can exclusivily be positive, lower limit can be positive or negative.

## Security Council

- **General description:** The Security Council is an address that can activate and deactivate the guardrails system, define the guardrails limits and bypass the guardrails system to update the total assets.
- The security council address can be update by the owner.

## Refacto management fee computation

- **General description:** Currently we compute management fees using the update value of totalAssets. This is not fair because the assets under management were not this amount during the entire previous period. We compute the average assets under management during the previous period using the previous totalAssets and the new totalAssets.

## Migration from whitelistable to Accessable

- **General description:** Accessable contract overides the whitelistable contract. It allows to switch between blacklist and whitelist mode and to use an external sanctions list.
- **Special note:** Update should lead to the following migrations:
  - deactivated whitelist -> blacklist
  - activated whitelist -> whitelist

## More restrictive allowed user management

- **General description:** Provided by the Accessable contract we enforce in a stricter way the allowed users but differ depending on the mode. See Accessable-and-superOperator.md for more details.

## SuperOperator

- **General description:** The super operator is an address that can perform certain operations on behalf of users and this even on behalf of users not allowed by whitelist / blacklist constraints. See Accessable-and-superOperator.md for more details.

## Vault total Assets initialisation

- **General description:** The total assets of the vault can be initialized at the deployment of the vault. It is used to ease the migration from a previous vault. Minted shares be sent to the Safe. No actual assets are transferred to the vault.

## Update name, symbol and Safe

- **General description:** The name, symbol and Safe can be updated by the owner.



## General considerations about the code

- We had to move a lot of the existing code from contracts to libraries to reduce bytecode size. For the same reason, we have move the initialisation function outside of the vault into a separate contract, vaultInit, deployed at construction and delegate called by the vault in its initialize function.