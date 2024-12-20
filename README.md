# Overview

Welcome to the Lagoon Protocol Documentation! This page serves as a comprehensive introduction to the core concepts, components, and unique features that make Lagoon Protocol a powerful tool for decentralized asset management.

Find more info about Lagoon Protocol in the [documentation](https://docs.lagoon.finance/)

---

## Preface

You need

- macOS / Linux
- Foundry
- Docker

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

Now, let's build our docker image. To do so, copy the `.env.example` file into a `.env.dev` file and provide the `RPC_URL` variable with a valid `mainnet` rpc url.

```bash
cp .env.example .env.dev
# Makefile is going to hammer the RPC hard, so you need a commercial RPC or your own node, 
# otherwise the build will crash.
# Recommended vendor: drpc.org
echo 'RPC_URL="https://lb.drpc.org/ogrpc?network=ethereum&dkey=... "' >> .env.dev

# Get Classic Personal access token from https://github.com/settings/tokens
# Scope: repo
echo 'PERSONAL_ACCESS_TOKEN=ghp_...' >> .env.dev
```

Then, run the following command to build the image:

```bash
make build-image
```

## Deploying a development vault

This will deploy Safe and vault in the Ethereum mainnet fork. If you want to deploy a real vault, see instructions below.

- Useful for local development
- Shows dependencies what is needed to deploy your own vault: 
  These instructions each step in detail so you can understand what's going on
- Runs on the Anvil mainnet fork
- Anvil default accounts are set as an owner for all access controls
- We need to do some minor translation between localhost addresses and Docker container networking

First make sure you have a newly created Safe available. You can create one using the [safe-cli](https://github.com/safe-global/safe-cli) or through the [Safe UI](https://safe.global/)

```bash
# Read the existing .env.dev file as the shell variables
export $(grep -v '^#' .env.dev | xargs)

# Start a mainnet fork
anvil --fork-url $RPC_URL

# Leave anvil running in this terminal
```

Hop to another terminal.

Then deploy a Safe multi-signature wallet needed for vault using [safe-cli container](https://github.com/safe-global/safe-cli).

```bash
export FORK_RPC_URL=http://127.0.0.1:8545

# Hardcoded in Anvil
export ANVIL_DEFAULT_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export ANVIL_DEFAULT_ACCOUNT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# We need Docker localhost translation
docker run \
  --network=host \
  -it \
  safeglobal/safe-cli \
  safe-creator \
  --owners $ANVIL_DEFAULT_ACCOUNT \
  --threshold 1 \
  http://host.docker.internal:8545 $ANVIL_DEFAULT_PRIVATE_KEY
  
# Get this from the command output above
export SAFE_ADDRESS=0xC3b606107f4248d741494bC42aA4F6b88F94d3E8

# Update our .env file with the fork deployed addresses.
# We set Anvil account 0 on every key holder needed.
echo "SAFE=$SAFE_ADDRESS" >> .env.dev
echo "FEE_RECEIVER=$ANVIL_DEFAULT_ACCOUNT" >> .env.dev
echo "ADMIN=$ANVIL_DEFAULT_ACCOUNT" >> .env.dev
echo "VALUATION_MANAGER=$ANVIL_DEFAULT_ACCOUNT" >> .env.dev

# Configure USDC
echo "UNDERLYING=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" >> .env.dev

# Configure WETH
echo "WRAPPED_NATIVE_TOKEN=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" >> .env.dev

# Mainnet addresses for Lagoon
```

Then we need to deploy [Beacon](https://www.rareskills.io/post/beacon-proxy)
that can later upgrade the vault smart contract if needed:

```bash
export FOUNDRY_ETH_RPC_URL="http://host.docker.internal:8545"

echo "BEACON_OWNER=$ANVIL_DEFAULT_ACCOUNT" >> .env.dev

docker run \
  --rm \
  --platform linux/x86_64 \
  --network host \
  --env-file .env.dev \
  -e FOUNDRY_ETH_RPC_URL \
  lagoon-deployer \
  --chain-id 8545 \
  --rpc-url $FOUNDRY_ETH_RPC_URL \
  --sender $ANVIL_DEFAULT_ACCOUNT \
  --unlocked \
   --broadcast \
  script/deploy_beacon.s.sol:DeployBeacon
  
# Read the output above of the above command and 
# save Beacon address in the .env.dev 
echo "BEACON=0xD69BC314bdaa329EB18F36E4897D96A3A48C3eeF" >> .env.dev
```

Now you can deploy a vault on Anvil:

```bash
export FOUNDRY_ETH_RPC_URL="http://host.docker.internal:8545"

# Grab the fee registry on mainnet
echo "NAME=VaultyVaultExample" >> .env.dev
echo "SYMBOL=EXAM" >> .env.dev
echo "FEE_REGISTRY=0x6dA4D1859bA1d02D095D2246142CdAd52233e27C" >> .env.dev

# Anyone can deposit
echo "ENABLE_WHITELIST=false" >> .env.dev

# Fees - 2%/20% model
echo "MANAGEMENT_RATE=200" >> .env.dev
echo "PERFORMANCE_RATE=2000" >> .env.dev
echo "RATE_UPDATE_COOLDOWN=86400" >> .env.dev
echo "WHITELIST_MANAGER=$ANVIL_DEFAULT_ACCOUNT" >> .env.dev

# Reads config from .env.dev as set above
docker run \
  --rm \
  --platform linux/x86_64 \
  --network host \
  --env-file .env.dev \
  -e FOUNDRY_ETH_RPC_URL \
  lagoon-deployer \
  --chain-id 8545 \
  --rpc-url $FOUNDRY_ETH_RPC_URL \
  --sender $ANVIL_DEFAULT_ACCOUNT \
  --unlocked \
  --broadcast \
  script/deploy_vault.s.sol:DeployVault 
```

Now you should see output like:

```
  --- deployVault() ---
  Beacon:               0xD69BC314bdaa329EB18F36E4897D96A3A48C3eeF
  Underlying:           0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  Wrapped_native_token: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
  Fee_registry:         0x6dA4D1859bA1d02D095D2246142CdAd52233e27C
  Name:                 VaultyVaultExample
  Symbol:               EXAM
  Enable_whitelist:     false
  Management_rate:      200
  Performance_rate:     2000
  Rate_update_cooldown: 86400
  Safe:                 0xC3b606107f4248d741494bC42aA4F6b88F94d3E8
  Fee_receiver:         0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  Admin:                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  Whitelist_manager:    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  Valuation_manager:    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
  Vault proxy address:  0x6712008CCD96751d586FdBa0DEf5495E0E22D904
```

Now let's read data back from the deployed vault:

```shell
# We are no longer using Dockerised commands, but local cast command.
export FOUNDRY_ETH_RPC_URL="http://127.0.0.1:8545"
# We call vault through Beacon proxy.
export VAULT=0x6712008CCD96751d586FdBa0DEf5495E0E22D904
cast call $VAULT "name()(string)"  
```

This outputs 

## Deploying a production vault

First make sure you have a newly created Safe available. You can create one using the [safe-cli](https://github.com/safe-global/safe-cli) or through the [Safe UI](https://safe.global/)

The image now can be used to deploy new vault proxies.

For that you will need another env file. Let's copy the `.env.prod-example` file into a `.env.prod-base` file and fill it with your vault details.

Let's deploy the vault on a local fork for now, to do so we need to provide a valid mainnet `FORK_RPC_URL` rpc url.

We can start the forked env with the following command:

```bash
ENV_DEPLOY=.env.prod-base make start-fork
```

Open a new shell window where you will deploy the vault.

First, you are able to simulate the vault deployment running the following command:

```bash
ENV_DEPLOY=.env.prod-base make vault
```

If the deployment simulation fails, make sure all the addresses you put in your `.env.prod` file are correct.

Then, you can use the following command to broadcast the deployment to the local network we started before.

Make sure the `RPC_URL` variable points to the correct domain, when deploying from another container the domain should map to the container's local fork name. (example: `RPC_URL="http://local-fork:8545"`)

```bash
ENV_DEPLOY=.env.prod-base make deploy-vault-pk
```

If you want to deploy the vault on mainnet you can change `RPC_URL` to point to a mainnet rpc url and run `ENV_DEPLOY=.env.prod-base make deploy-vault-pk` again.

## Audits

The audit is stored in the [audits](./audits/)' folder.

## Licences

The primary license for Lagoon Protocol is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE).
