# Overview

Welcome to the Lagoon Protocol Documentation! This page serves as a comprehensive introduction to the core concepts, components, and unique features that make Lagoon Protocol a powerful tool for decentralized asset management.

Find more info about Lagoon Protocol in the [documentation](https://docs.lagoon.finance/)

---

## Preface

You need

- macOS / Linux
- Foundry
- Docker (Recommended for production)

## Repository Structure

The repository is split in two parts, [`protocol`]('./src/protocol') and [`vault`]('./src/v0.2.0'). You will mainly be interested in `Vault.sol` and `ERC7540.sol` files.

```bash
src
├── protocol
│   ├── Events.sol
│   └── FeeRegistry.sol
└── v0.2.0
    ├── ERC7540.sol
    ├── FeeManager.sol
    ├── Roles.sol
    ├── Silo.sol
    ├── Vault.sol
    ├── Whitelistable.sol
    ├── interfaces
    │   ├── IERC7540.sol
    │   ├── IERC7540Deposit.sol
    │   ├── IERC7540Redeem.sol
    │   ├── IERC7575.sol
    │   └── IWETH9.sol
    └── primitives
        ├── Enums.sol
        ├── Errors.sol
        ├── Events.sol
        └── Struct.sol
```

# Getting started: Local Development

First, create a `.env` file.

```bash
cp .env.example .env
```

This `.env` is meant to be used for local `test` development, not for `packaging` (docker image builds) nor `deployments`.

Also, if you run scripts from your local setup make sure to correctly override `FOUNDRY_ETH_RPC_URL` else you could end up with bad surprises.

## How to build

```bash
forge build
```

## How to test

```bash
forge test --match-path "./test/v0.2.0/**/*.sol"
```

## How to deploy

First, create a `.env.deploy` file.

```bash
cp .env.deploy.example .env.deploy
```

Start a local fork environment

```bash
anvil --host 0.0.0.0 --fork-url $FORK_RPC_URL
```

An other alternative is to use the `Makefile`, it requires `FORK_RPC_URL` to be defined.

```bash
make start-fork
```

It will spawn anvil inside a container instead of running it into your host.

Then, loads the `.env.deploy` variables into your environment

```bash
set -a && source .env.deploy && set +a
```

And set `FOUNDRY_ETH_RPC_URL` to the network where you want to deploy

```bash
FOUNDRY_ETH_RPC_URL="http://localhost:8545"
```

Now you can run scripts to deploy a new beacon and vault proxy on your local anvil node

```bash
forge script --chain-id 1 --private-key $PRIVATE_KEY --rpc-url "http://localhost:8545" "script/deploy_beacon.s.sol"

BEACON="0x..." # define BEACON address when you have it

forge script --chain-id 1 --private-key $PRIVATE_KEY --rpc-url "http://localhost:8545" "script/deploy_vault.s.sol"
```

# Production packaging and deployment

First make sure you have a newly created Safe address available.

You can create one using the [safe-cli](https://github.com/safe-global/safe-cli) or through the [Safe UI](https://safe.global/)

## How to get the docker image to deploy

Pull the image from Github packages.

```
TODO:
```

Alternatively, create a `.env.build` file.

```bash
cp .env.build.example .env.build
```

And run

```bash
make build-image
```

## Deploy from an image container

First, create a `.env.deploy` file.

```bash
cp .env.deploy.example .env.deploy.mainnet
```

Let's start a local fork where we are going to deploy

```bash
ENV_DEPLOY=.env.deploy.mainnet make start-fork
```

Open a new shell window where you will deploy the vault.

First, you are able to simulate the vault deployment running the following command:

```bash
ENV_DEPLOY=.env.deploy.mainnet make beacon
```

Inside `.env.deploy.mainnet` define the `BEACON` address.

If the deployment simulation fails, make sure all the addresses you put in your `.env.deploy` file are correct.

Then, you can use the following command to broadcast the deployment to the local network we started before.

```bash
ENV_DEPLOY=.env.deploy.mainnet make deploy-beacon-pk
```

The same apply to deploy a vault proxy using the `vault` script.

```bash
ENV_DEPLOY=.env.deploy.mainnet make deploy-vault-pk
```

Make sure the `RPC_URL` variable points to the correct domain, when deploying from another container the domain should map to the container's local fork name. (example: `RPC_URL="http://local-fork:8545"`)

If you want to deploy the vault on mainnet you can change `RPC_URL` to point to a mainnet rpc url.

## Audits

The audit is stored in the [audits](./audits/)' folder.

## Licences

The primary license for Lagoon Protocol is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE).
