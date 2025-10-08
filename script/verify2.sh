#!/bin/bash

# verify2.sh - Like verify.sh but better :)
#
# How to use:
# - install forge with:       curl -L https://foundry.paradigm.xyz | bash
# - in a new terminal run:    foundryup
# - install deps with:        forge install
# - run the script with:      ./script/verify.sh

# Examples:
#   ./script/verify.sh                     # Interactive mode
#   ./script/verify.sh -c 1 -a 0x123... -k YOUR_API_KEY  # Verify Vault contract
#   ./script/verify.sh --help              # Show help

# Default values
ADDRESS=""
CONSTRUCTOR_ARGS=""
ETHERSCAN_API_KEY=""
CHAIN_ID=1
RUNS=1 # If you try to verify a contract deployed by a factory make sure to use the amount of runs used to deployed the said factory
COMPILER_VERSION="v0.8.26+commit.8a97fa7a"
SELECTED_CONTRACT=""
INTERACTIVE=true

# Available contracts
declare -a CONTRACTS=(
  "./src/v0.5.0/Vault.sol:Vault"
  "./src/v0.5.0/Silo.sol:Silo"
  "./src/proxy/OptinProxy.sol:OptinProxy"
  "./src/BeaconProxyFactory.sol:BeaconProxyFactory"
  "./dependencies/@openzeppelin-contracts-5.0.0/proxy/beacon/BeaconProxy.sol:BeaconProxy"
  "./dependencies/@openzeppelin-contracts-5.0.0/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy"
  "./dependencies/@openzeppelin-contracts-5.0.0/proxy/transparent/ProxyAdmin.sol:ProxyAdmin"
  "./src/protocol-v1/FeeRegistry.sol:FeeRegistry"
  "./src/protocol-v2/ProtocolRegistry.sol:ProtocolRegistry"

)

# Function to display help
show_help() {
  echo "Usage: ./script/verify.sh [OPTIONS]"
  echo ""
  echo "A simple CLI for verifying smart contracts on Etherscan"
  echo ""
  echo "Options:"
  echo "  -h, --help                 Show this help message"
  echo "  -c, --contract NUMBER      Select contract by number (1-${#CONTRACTS[@]})"
  echo "  -a, --address ADDRESS      Contract address to verify"
  echo "  -r, --args ARGS            Constructor arguments (hex encoded)"
  echo "  -k, --key API_KEY          Etherscan API key"
  echo "  -i, --chain-id ID          Chain ID (default: 1 for EthMainnet)"
  echo "  -o, --runs NUMBER          Number of optimization runs (default: 1)"
  echo "  -v, --compiler VERSION     Compiler version (default: v0.8.26+commit.8a97fa7a)"
  echo ""
  echo "Examples:"
  echo "  ./script/verify.sh                     # Interactive mode"
  echo "  ./script/verify.sh -c 1 -a 0x123... -k YOUR_API_KEY  # Verify Vault contract"
  echo ""
}

# Function to display contract selection menu
show_contract_menu() {
  echo "Available contracts:"
  echo "-------------------"
  for i in "${!CONTRACTS[@]}"; do
    echo "$((i + 1)). ${CONTRACTS[$i]}"
  done
  echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  -h | --help)
    show_help
    exit 0
    ;;
  -c | --contract)
    if [[ $2 =~ ^[0-9]+$ ]] && [ $2 -ge 1 ] && [ $2 -le ${#CONTRACTS[@]} ]; then
      SELECTED_CONTRACT=${CONTRACTS[$2 - 1]}
      INTERACTIVE=false
    else
      echo "Error: Invalid contract number. Must be between 1 and ${#CONTRACTS[@]}."
      exit 1
    fi
    shift 2
    ;;
  -a | --address)
    ADDRESS=$2
    INTERACTIVE=false
    shift 2
    ;;
  -r | --args)
    CONSTRUCTOR_ARGS=$2
    shift 2
    ;;
  -k | --key)
    ETHERSCAN_API_KEY=$2
    shift 2
    ;;
  -i | --chain-id)
    CHAIN_ID=$2
    shift 2
    ;;
  -o | --runs)
    RUNS=$2
    shift 2
    ;;
  -v | --compiler)
    COMPILER_VERSION=$2
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

# Interactive mode if needed
if [ "$INTERACTIVE" = true ]; then
  # Select contract
  show_contract_menu
  read -p "Select contract (1-${#CONTRACTS[@]}): " contract_num

  if [[ $contract_num =~ ^[0-9]+$ ]] && [ $contract_num -ge 1 ] && [ $contract_num -le ${#CONTRACTS[@]} ]; then
    SELECTED_CONTRACT=${CONTRACTS[$contract_num - 1]}
  else
    echo "Error: Invalid selection. Exiting."
    exit 1
  fi

  # Get contract address
  read -p "Enter contract address: " ADDRESS

  # Get constructor arguments (optional)
  read -p "Enter constructor arguments (hex encoded, leave empty if none): " CONSTRUCTOR_ARGS

  # Get Etherscan API key
  read -p "Enter Etherscan API key: " ETHERSCAN_API_KEY

  # Optional: chain ID
  read -p "Enter chain ID [default: $CHAIN_ID]: " chain_input
  if [ ! -z "$chain_input" ]; then
    CHAIN_ID=$chain_input
  fi
fi

# Validate required inputs
if [ -z "$SELECTED_CONTRACT" ]; then
  echo "Error: No contract selected."
  exit 1
fi

if [ -z "$ADDRESS" ]; then
  echo "Error: Contract address is required."
  exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
  echo "Error: Etherscan API key is required."
  exit 1
fi

# Display verification information
echo ""
echo "Verification Details:"
echo "--------------------"
echo "Contract:         $SELECTED_CONTRACT"
echo "Address:          $ADDRESS"
echo "Chain ID:         $CHAIN_ID"
echo "Optimization:     $RUNS runs"
echo "Compiler Version: $COMPILER_VERSION"
echo ""
echo "Starting verification..."
echo ""

# Prepare constructor args parameter
CONSTRUCTOR_ARGS_PARAM=""
if [ ! -z "$CONSTRUCTOR_ARGS" ]; then
  CONSTRUCTOR_ARGS_PARAM="--constructor-args $CONSTRUCTOR_ARGS"
fi


# Run forge verify-contract
forge verify-contract \
  --chain-id $CHAIN_ID \
  --num-of-optimizations $RUNS \
  --watch \
  $CONSTRUCTOR_ARGS_PARAM \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version $COMPILER_VERSION \
  $ADDRESS \
  "$SELECTED_CONTRACT"

