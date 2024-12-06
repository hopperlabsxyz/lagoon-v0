# What is Lagoon Protocol?

Lagoon Protocol is a decentralized platform for creating and managing secure, non-custodial Vaults. These Vaults allow asset managers to implement various DeFi strategies like yield farming while maintaining control and flexibility. Built on smart contracts and tools like Gnosis Safe and Zodiac Roles modifiers, Lagoon Vaults are highly customizable, supporting different roles such as managers, fund depositors, and valuation oracles.

Find more info about Lagoon Protocol in the [documentation](https://docs.lagoon.finance/)

---

## Repository Structure

The repository is split in two parts, [`protocol`]('./protocol') and [`vault`]('./vault'). The vault repository contains most of the code of the Lagoon vault logic. You will mainly be interested in `Vault.sol` and `ERC7540.sol` files.

```bash
src
├── protocol
│   ├── Events.sol
│   └── FeeRegistry.sol
└── vault
    ├── ERC7540.sol
    ├── FeeManager.sol
    ├── Roles.sol
    ├── Silo.sol
    ├── Vault.sol
    ├── Whitelistable.sol
    ├── interfaces
    │   ├── IERC7540.sol
    │   ├── IERC7540Deposit.sol
    │   ├── IERC7540Redeem.sol
    │   ├── IERC7575.sol
    │   └── IWETH9.sol
    └── primitives
        ├── Enums.sol
        ├── Errors.sol
        ├── Events.sol
        └── Struct.sol
```

## Getting Started

In order to deploy a new vault you will have to create a new `BeaconProxy` that will point to the vault logic.

Before starting, make sure you have `docker daemon` up and running on your machine.

Now, let's build our docker image. To do so, copy the `.env.example` file into a `.env.dev` file and provide the `FOUNDRY_ETH_RPC_URL` variable with a valid `mainnet` rpc url.

Then, run the following command to build the image:

```bash
make build-image
```

First make sure you have a newly created Safe available.

```bash
to do, explain how to deploy a safe using docker container
```

The image now can be used to deploy new vault proxies.

For that you will need another env file. Let's copy the `.env.prod-example` file into a `.env.prod-base` file and fill it with your vault details.

Let's deploy the vault on a local fork for now, to do so we need to provide a valid mainnet `FORK_RPC_URL` rpc url.

We can start the forked env with the following command:

```bash
ENV_PROD=.env.prod-base make start-fork
```

Open a new shell window where you will deploy the vault.

First, you are able to simulate the vault deployment running the following command:

```bash
ENV_PROD=.env.prod-base make vault
```

If the deployment simulation fails, make sure all the addresses you put in your `.env.prod` file are correct.

Then, you can use the following command to broadcast the deployment to the local network we started before.

Make sure the `RPC_URL` variable points to the correct domain, when deploying from another container the domain should map to the container's local fork name. (example: `RPC_URL="http://local-fork:8545"`)

```bash
ENV_PROD=.env.prod-base make deploy-vault-pk
```

If you want to deploy the vault on mainnet you can change `RPC_URL` to point to a mainnet rpc url and run `ENV_PROD=.env.prod-base make deploy-vault-pk` again.

## Audits

The audit is stored in the [audits](./audits/)' folder.

## Licences

The primary license for Lagoon Protocol is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE).
