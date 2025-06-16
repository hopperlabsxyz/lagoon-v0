#!/bin/bash

# How to use:
# - install forge with:       curl -L https://foundry.paradigm.xyz | bash
# - in a new terminal run:    foundryup
# - install deps with:        forge install
# - run the script with:      ./script/verify.sh

ADDRESS=
CONSTRUCTOR_ARGS=
ETHERSCAN_API_KEY=

CONTRACT_PATH=./src/v0.5.0/Vault.sol:Vault
CONTRACT_PATH=./src/v0.5.0/Silo.sol:Silo
CONTRACT_PATH=./src/BeaconProxyFactory.sol:BeaconProxyFactory
CONTRACT_PATH=./lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy
CONTRACT_PATH=./lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy
CONTRACT_PATH=./lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol:ProxyAdmin
CONTRACT_PATH=./src/protocol/FeeRegistry.sol:FeeRegistry

CHAIN_ID=43114
RUNS=1 # If you try to verify a contract deployed by a factory make sure to use the amount of runs used to deployed the said factory
COMPILER_VERSION=v0.8.26+commit.8a97fa7a

forge verify-contract \
  --chain-id $CHAIN_ID \
  --num-of-optimizations $RUNS \
  --watch \
  --constructor-args $CONSTRUCTOR_ARGS \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version $COMPILER_VERSION \
  $ADDRESS \
  "$CONTRACT_PATH"
