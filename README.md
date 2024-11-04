# Overview

Welcome to the Lagoon Protocol Documentation! This page serves as a comprehensive introduction to the core concepts, components, and unique features that make Lagoon Protocol a powerful tool for decentralized asset management.

## What is Lagoon Protocol?

Lagoon Protocol is a decentralized asset management platform that enables asset managers to create Lagoon Vaults. These Vaults provide efficient, non-custodial, and risk-managed asset management solutions.

Built on a foundation of smart contract standards, Lagoon Protocol leverages the power of Gnosis Safe, Zodiac Roles Modifier, and other key components to create highly customizable and secure vaults for managing digital assets.

Lagoon Protocol enables the creation of decentralized Vaults (Lagoon Vaults) that support various roles, including Asset Managers, NAV Committees, Vault Creators and Fund Depositors. These Vaults are governed by smart contracts that allow for a wide range of DeFi strategies, from asset management to yield farming, all while maintaining a high level of security and control. The protocol's design prioritizes flexibility, enabling asset manager to configure their Vaults with specific DeFi protocol whitelists, separation of power, fee structures, and more.

## Key Innovations

Lagoon Protocol is built on a robust infrastructure that includes:

- **Gnosis Safe:** Serving as the secure vault for managing assets, ensuring that only authorized parties can execute transactions.
- **ERC-7540**: the asynchronous vault standard, to tokenized share of users, allowing users to deposit assets as underlaying into the vault and received share.
- **Zodiac Roles Modifier:** Provides granular role-based permissions, allowing for detailed governance and access control within each Vault.
- **Cross-Chain Interoperability:** Lagoon Protocol’s architecture, through Gnosis Safe, is designed to support multi-chain strategies, leveraging bridges to manage assets across different blockchain networks.
- **Modular Fees Management:** Allows Vault creators to define, update, or remove performance, management, and entry/exit fees, providing a tailored experience for each Vault.
- **Seamless Integration with Layer 2:** As part of our ongoing commitment to expand the DeFi ecosystem, Lagoon Protocol is fully integrated with Layer 2 compatible with Gnosis Safe, enabling low-cost, high-speed transactions and broadening access to DeFi strategies across multiple chains.

## Why Lagoon Protocol?

Lagoon Protocol is more than just a Vault management system. It represents a significant step forward in the evolution of decentralized finance by providing a flexible, secure, and scalable solution for managing digital assets. Whether you're a sophisticated asset manager, a NAV committee member, or a shareholder looking to optimize your DeFi strategies, Lagoon Protocol offers the tools and infrastructure you need to succeed.

## Who Should Use Lagoon Protocol?

- **Asset Managers** looking to execute sophisticated DeFi strategies with speed of adaptation and full control over asset security.
- **Institutional Investors** who require a secure, transparent, and customizable solution for managing large volumes of digital assets.
- **DeFi Enthusiasts** seeking a platform that supports a wide range of decentralized financial protocols.

## Getting Started

Ready to dive in? Use the navigation on the left to explore architecture, smart contract specifications, and more. Whether you're just getting started or looking to implement advanced vaults, Lagoon Protocol’s documentation will provide you with the knowledge and tools you need.

---

# Deployment Guide

This section provides a comprehensive guide on deploying essential components of the Lagoon Protocol, including the **FeeRegistry**, a **Gnosis Safe**, and a **Vault**.

## Prerequisites

Ensure the following setup is done before starting:

- **Foundry**: Make sure Foundry is installed and configured. If not, refer to the [Foundry documentation](https://book.getfoundry.sh/getting-started/installation).

- Creating an `.env.prod-[chain]` file (replacing `[chain]` by the the name of the chain where you want to deploy)

Ensure your `.env.prod-[chain]` file contains the following additional or modified variables:

```bash

CHAIN_ID=42161 # arb1 chain id
RPC_URL="https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
ETHERSCAN_API_KEY='YOUR_ETHERSCAN_API_KEY'
```

## 1. Deploy the FeeRegistry Contract

Before setting up a `Gnosis Safe` and a `Vault`, you must first deploy the `FeeRegistry` contract.

### Steps to Deploy FeeRegistry

#### 1. Prepare the Environment

Ensure your `.env.prod-[chain]` file contains the following additional or modified variables:

```bash
DAO=0x...
PROTOCOL_FEE_RECEIVER=0x...
PROXY_ADMIN=0x...
```

#### 2. Execute the Deployment Script

```bash
# simulate deployment
make protocol

# broadcast to network
make protocol-broadcast

# verify on etherscan
make protocol-verify
```

#### 3. Check Deployment Logs

After running the script, you’ll see the deployment logs including the proxy address for the `FeeRegistry` contract:

```bash
FeeRegistry proxy address: 0x...
```

## 2. Deploy the Gnosis Safe

After deploying the `FeeRegistry`, the next step is to create a `Gnosis Safe`, which will manage the assets used in a `Vault`.

For a detailed guide and to deploy your own Safe, visit the [official Gnosis Safe website](https://gnosis-safe.io/) and check out [this tutorial](https://docs.gnosischain.com/tools/wallets/safe).

## 3. Deploy the Vault Contract

Once the `Gnosis Safe` is set up, you can deploy the `Vault` contract.

### `.env.prod-[chain]` File Configuration

Ensure your `.env.prod-[chain]` file contains the following additional or modified variables:

```bash
## --------  VAULT BEACON  ------------ ##

BEACON_OWNER=0x...

## --------  VAULT PROXY  ------------ ##

## General ##

UNDERLYING=0x...
WRAPPED_NATIVE_TOKEN=0x...
FEE_REGISTRY=0x...
BEACON=0x...
NAME="Test WETH"
SYMBOL="tWETH"
ENABLE_WHITELIST=false

## Fees ##

MANAGEMENT_RATE=0
PERFORMANCE_RATE=20
RATE_UPDATE_COOLDOWN=7

## Roles ##

SAFE=0x...
FEE_RECEIVER=0x...
ADMIN=0x...
WHITELIST_MANAGER=0x...
VALUATION_MANAGER=0x...
```

### Steps to Deploy

#### 1. Make sure to have beacon deployed

Before deploying vault proxy, make sure to deploy the vault beacon if haven't already done so:

```bash
# simulate deployment
make beacon

# broadcast to network
make beacon-broadcast

# verify on etherscan
make beacon-verify
```

#### 2. Execute the Deployment Script

Once the environment is prepared, you can deploy the `Vault` contract using the `make vault` command. This command will deploy the `Vault` contract, using a beacon proxy, to the blockchain specified by the `RPC_URL` and `CAHIN_ID`.

```bash
# simulate deployment
make vault

# broadcast to network
make vault-broadcast

# verify on etherscan
make vault-verify
```

#### 3. Check Deployment Logs

After running the deployment command, you should see output in the console with details about the deployment, including the address of the deployed `Vault` contract. The relevant line will look something like this:

```
Vault proxy address: 0x...
```

# Contributing

Ensure that you copied `.env.example` to `.env.dev` and that you provided a valid `FOUNDRY_ETH_RPC_URL`

Then you can run `make test` to run the full test suit.
