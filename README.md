# Overview

Welcome to the Lagoon Protocol Documentation! This page serves as a comprehensive introduction to the core concepts, components, and unique features that make Lagoon Protocol a powerful tool for decentralized asset management.

### What is Lagoon Protocol?

Lagoon Protocol is a decentralized asset management platform that enables asset managers to create Lagoon Vaults. These Vaults provide efficient, non-custodial, and risk-managed asset management solutions.

Built on a foundation of smart contract standards, Lagoon Protocol leverages the power of Gnosis Safe, Zodiac Roles Modifier, and other key components to create highly customizable and secure vaults for managing digital assets.

Lagoon Protocol enables the creation of decentralized Vaults (Lagoon Vaults) that support various roles, including Asset Managers, NAV Committees, Vault Creators and Fund Depositors. These Vaults are governed by smart contracts that allow for a wide range of DeFi strategies, from asset management to yield farming, all while maintaining a high level of security and control. The protocol's design prioritizes flexibility, enabling asset manager to configure their Vaults with specific DeFi protocol whitelists, separation of power, fee structures, and more.

### Key Innovations

Lagoon Protocol is built on a robust infrastructure that includes:

- **Gnosis Safe:** Serving as the secure vault for managing assets, ensuring that only authorized parties can execute transactions.
- **ERC-7540**: the asynchronous vault standard, to tokenized share of users, allowing users to deposit assets as underlaying into the vault and received share.
- **Zodiac Roles Modifier:** Provides granular role-based permissions, allowing for detailed governance and access control within each Vault.
- **Cross-Chain Interoperability:** Lagoon Protocol’s architecture, through Gnosis Safe, is designed to support multi-chain strategies, leveraging bridges to manage assets across different blockchain networks.
- **Modular Fees Management:** Allows Vault creators to define, update, or remove performance, management, and entry/exit fees, providing a tailored experience for each Vault.
- **Seamless Integration with Layer 2:** As part of our ongoing commitment to expand the DeFi ecosystem, Lagoon Protocol is fully integrated with Layer 2 compatible with Gnosis Safe, enabling low-cost, high-speed transactions and broadening access to DeFi strategies across multiple chains.

### Why Lagoon Protocol?

Lagoon Protocol is more than just a Vault management system. It represents a significant step forward in the evolution of decentralized finance by providing a flexible, secure, and scalable solution for managing digital assets. Whether you're a sophisticated asset manager, a NAV committee member, or a shareholder looking to optimize your DeFi strategies, Lagoon Protocol offers the tools and infrastructure you need to succeed.

### Who Should Use Lagoon Protocol?

- **Asset Managers** looking to execute sophisticated DeFi strategies with speed of adaptation and full control over asset security.
- **Institutional Investors** who require a secure, transparent, and customizable solution for managing large volumes of digital assets.
- **DeFi Enthusiasts** seeking a platform that supports a wide range of decentralized financial protocols.

### Getting Started

Ready to dive in? Use the navigation on the left to explore architecture, smart contract specifications, and more. Whether you're just getting started or looking to implement advanced vaults, Lagoon Protocol’s documentation will provide you with the knowledge and tools you need.

---

# Deployment Guide

This section provides a comprehensive guide on deploying essential components of the Lagoon Protocol, including the **FeeRegistry**, a **Gnosis Safe**, and a **Vault**.

## Prerequisites

Ensure the following setup is done before starting:

- **Foundry**: Make sure Foundry is installed and configured. If not, refer to the [Foundry documentation](https://book.getfoundry.sh/getting-started/installation).

## 1. Deploy the FeeRegistry Contract

Before setting up a `Gnosis Safe` and a `Vault`, you must first deploy the `FeeRegistry` contract.

### `.env` File Configuration

Ensure your `.env` file contains the following additional or modified variables:

```bash
# Contract-specific addresses
PROXY_ADMIN=<Proxy admin address>          # The address responsible for managing the proxy
DAO=<DAO address>                          # The DAO responsible for protocol management
```

### Steps to Deploy FeeRegistry

#### 1. Prepare the Environment

Before deploying, run the following command to source your environment variables and clean the project:

```bash
source .env && forge clean
```

#### 2. Execute the Deployment Script

```bash
forge script script/deploy_protocol.s.sol \
    --chain-id $CHAIN_ID \
    --rpc-url $RPC_URL \
    --tc DeployProtocol \
    --account defaultKey \
    --etherscan-api-key $ETHERSCAN_API_KEY
    --verify
```

- `--chain-id`: Specifies the chain ID of the target blockchain.
- `--rpc-url`: Provides the RPC URL to interact with the blockchain network.
- `--tc DeployProtocol`: Specifies the deployment script to execute (`DeployProtocol` in this case).
- `--account`: Specifies the account to use for deployment.
- `--etherscan-api-key`: Optional. If provided, this will verify the contract on Etherscan.
- `--verify`: Enables verification of the contract on Etherscan (requires API key).

#### 3. Check Deployment Logs

After running the script, you’ll see the deployment logs including the proxy address for the `FeeRegistry` contract:

```bash
FeeRegistry proxy address: 0x<Deployed_Proxy_Address>
```

## 2. Deploy the Gnosis Safe

After deploying the `FeeRegistry`, the next step is to create a `Gnosis Safe`, which will manage the assets used in a `Vault`.

For a detailed guide and to deploy your own Safe, visit the [official Gnosis Safe website](https://gnosis-safe.io/) and check out [this tutorial](https://docs.gnosischain.com/tools/wallets/safe).

## 3. Deploy the Vault Contract

Once the `Gnosis Safe` is set up, you can deploy the `Vault` contract.

### `.env` File Configuration

```bash
# Blockchain specific configurations
CHAIN_ID=<Your chain ID>          # The chain ID of the blockchain network
RPC_URL=<Your RPC URL>            # The RPC URL for connecting to the blockchain network
ETHERSCAN_API_KEY=<Your Etherscan API key>  # Optional for contract verification on Etherscan

# Vault specific details
UNDERLYING=<Underlying token address>        # The address of the vault underlying ERC20 token
WRAPPED_NATIVE_TOKEN=<Wrapped native token address>  # The address of the wrapped native token
PROXY_ADMIN=<Proxy admin address>            # The address that will administer the proxy
DAO=<DAO address>                            # The DAO responsible for managing the vault
SAFE=<SAFE address>                          # The address of the SAFE responsible for vault operations
FEE_RECEIVER=<Fee receiver address>          # The address to receive the vault fees
FEE_REGISTRY=<Fee registry address>          # The address of the fee registry

VAULT_NAME=<Vault name>                      # The name of the vault
VAULT_SYMBOL=<Vault symbol>                  # The symbol of the vault
```

### Steps to Deploy

#### 1. Prepare the Environment

Before deploying, run the following command to source your environment variables and clean the project:

```bash
source .env && forge clean
```

#### 2. Execute the Deployment Script

Once the environment is prepared, you can deploy the `Vault` contract using the `forge script` command. This command will deploy the `Vault` contract, using a transparent upgradeable proxy, to the blockchain specified by the RPC URL and chain ID.

```bash
forge script script/deploy_vault.s.sol   --chain-id $CHAIN_ID   --rpc-url $RPC_URL   --tc DeployVault   --account defaultKey   --etherscan-api-key $ETHERSCAN_API_KEY   --verify
```

- `--chain-id`: Specifies the chain ID of the target blockchain.
- `--rpc-url`: Provides the RPC URL to interact with the target blockchain.
- `--tc DeployVault`: Specifies the target script to run (`DeployVault` in this case).
- `--account`: Specifies the account (key) to use for deployment (use `defaultKey` if configured).
- `--etherscan-api-key`: Optional. If provided, this will verify the contract on Etherscan after deployment.
- `--verify`: Enables verification of the contract on Etherscan (requires the API key above).

#### 3. Check Deployment Logs

After running the deployment command, you should see output in the console with details about the deployment, including the address of the deployed `Vault` contract. The relevant line will look something like this:

```
Vault proxy address: 0x<Deployed_Proxy_Address>
```

#### 4. Contract Verification (Optional)

If you've provided the `ETHERSCAN_API_KEY` and used the `--verify` flag during deployment, the contract will automatically be verified on Etherscan.
