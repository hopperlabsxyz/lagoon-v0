# Roles and Capabilities

## Vault Admin <a href="#owner" id="owner"></a>

Only a single address can hold this role, and it is the responsibility of the vault creator to establish a governance scheme for this address.

The Vault Admin is the owner of the vault.

**Capabilities:**

* Change owner (2 steps: the new owner has to accept ownership).
* Without delay and as many time as wanted:
  * Change the Whitelist Manager.
  * Change the Total Assets Manager.
  * Change the Fee Receiver.
* Deactivate the vault whitelist. (note: once deactivated, it cannot be reactivated).
* Renounce ownership.
* Initiate vault closing (transitioning the vault from `Open` to `Closing`, after which the vault Safe can transition it from `Closing` to `Closed` by calling the `close()` method).
* Can pause/un-pause the vault

## Vault Creator

The vault creator is the role responsible for deploying the contract and setting up the initial parameters, including defining the governance structure for the vault. This role holds the authority to assign operational rules for the vault from its inception.

**Capabilities:**

* Set the vault underlying
* Set the vault name
* Set the vault symbol
* Set the vault Safe
* Set the Whitelist Manager
* Set the Total Assets Manager
* Set the Vault Admin
* Set the fee receiver
* Set the fee registry
* Set the wrapped native token
* Set the management rate
* Set the performance rate
* Activate the whitelist (whitelist can be activated only here)
* Set the initial whitelist (if applicable)
* Set the rate update cooldown

## Vault Safe

The Safe can be managed either through the multi-sign or by granting permission to an asset manager using the Zodiac Roles Modifier module.

The Zodiac Roles Modifier module allows the vault's governance to delegate specific permissions to various addresses, including asset managers, who can perform certain functions on behalf of the vault.

**Capabilities:**

* Can settle deposits
* Can settle redeems
* Can close the vault

**Important Warning**:

The governance of the vault is responsible for defining the governance scheme and the role of the Safe. This includes deciding who holds the Safe multi-sign and how it is managed.

&#x20;The Safe multi-sign should be chosen carefully to align with the vault's security and operational policies. It is critical that the governance structure is well-defined and secure, as it impacts the overall safety and effectiveness of the vault's operations.

## Total Assets Manager

The Total Assets Manager ensures the vault's asset value is accurate and up to date, which is essential for keeping NAV calculations correct. This allows investors to deposit and redeem assets at the right values.

**Capabilities:**

* Update vault total assets.&#x20;

The Total Assets Manager is typically a trusted entity (such as a smart contract or a role within governance) responsible for keeping the asset balances up to date.

## Whitelist Manager

The Whitelist Manager controls which addresses are authorized to interact with the vault by adding or removing them from the whitelist, but this applies only if the whitelist was activated during the vault's deployment.

**Capabilities:**

* Can add/revoke whitelisted addresses.
* Can disbale the whitelist. When deactivated, the contract does not enforce whitelist checks, allowing any user to request deposit/redeem.
* Can update the Merkle root. This allows the contract to whitelist users via an off-chain generated Merkle tree, ensuring a scalable way to manage large whitelists.

## Fee Receiver

The Fee Receiver is receiving management and performance fees from the vault based on the predefined fee structure.

**Capabilities:**

* N/A.

## Lagoon Protocol

The following capabilities only apply for the the `FeeRegistry` contract, which is not part of the vault.

**Capabilities:**

* Can set the protocol's fee rate for any vault, defining custom rates for specific vaults.
* Can update the address that receives protocol fees.
* Change owner of the `FeeRegistry` (2 steps: the new owner has to accept ownership).
* Renounce `FeeRegistry` ownership.
