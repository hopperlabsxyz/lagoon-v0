#!/bin/bash

# How to use:
# - install forge with:       curl -L https://foundry.paradigm.xyz | bash
# - in a new terminal run:    foundryup
# - install deps with:        forge install
# - run the script with:      ./script/verify.sh

ADDRESS=
CONSTRUCTOR_ARGS=
ETHERSCAN_API_KEY=

BEACON_PATH=./lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy
CHAIN_ID=1
RUNS=200
COMPILER_VERSION=v0.8.26+commit.8a97fa7a

forge verify-contract \
  --chain-id $CHAIN_ID \
  --num-of-optimizations $RUNS \
  --watch \
  --constructor-args $CONSTRUCTOR_ARGS \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version $COMPILER_VERSION \
  $ADDRESS \
  "$BEACON_PATH"
