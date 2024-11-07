ifeq ($(ENV_DEV),)
	ENV_DEV := .env.dev
endif

ifeq ($(ENV_PROD),)
	ENV_PROD := .env.prod-arb1
endif

load_dev_env:
	@echo "Using development environment"
	$(eval include $(ENV_DEV))
	$(eval export $(shell sed 's/=.*//' $(ENV_DEV)))

load_prod_env:
	@echo "Using production environment"
	$(eval include $(ENV_PROD))
	$(eval export $(shell sed 's/=.*//' $(ENV_PROD)))

clean:
	forge clean

build:
	forge build

test: load_dev_env
	UNDERLYING_NAME=USDC forge test
	UNDERLYING_NAME=WRAPPED_NATIVE_TOKEN forge test

fmt:
	forge fmt

solhint:
	pnpm exec solhint 'src/**/*.sol'

pre-commit: fmt test solhint
	git add -A


################### PROTOCOL ################### 

protocol: load_prod_env clean
	forge script script/deploy_protocol.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployProtocol \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

protocol-broadcast: load_prod_env clean
	forge script script/deploy_protocol.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployProtocol \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--broadcast

protocol-verify: load_prod_env clean
	forge script script/deploy_protocol.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployProtocol \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify

protocol-broadcast-ledger: load_prod_env clean
	forge script script/deploy_protocol.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployProtocol \
		--ledger \
		--hd-paths  $(HD_PATH) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--broadcast

protocol-verify-ledger: load_prod_env clean
	forge script script/deploy_protocol.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployProtocol \
		--ledger \
		--hd-paths  $(HD_PATH) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify

################### BEACON ################### 

beacon: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployBeacon \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

beacon-broadcast: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployBeacon \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--broadcast

beacon-verify: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployBeacon \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify

beacon-broadcast-ledger: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployBeacon \
		--ledger \
		--hd-paths $(HD_PATH) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--broadcast

beacon-verify-ledger: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployBeacon \
		--ledger \
		--hd-paths  $(HD_PATH) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify

####### UPGRADE BEACON IMPLEMENTATION ####### 

# @dev: Use at your own risk, upgradability is NOT garanted /!\

upgrade-implementation: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc UpgradeBeaconImplementation \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

upgrade-implementation-broadcast: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc UpgradeBeaconImplementation \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--broadcast

upgrade-implementation-verify: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc UpgradeBeaconImplementation \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify

################### VAULT ################### 

vault: load_prod_env clean
	forge script script/deploy_vault.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployVault \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

vault-broadcast: load_prod_env clean
	forge script script/deploy_vault.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployVault \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--broadcast

vault-verify: load_prod_env clean
	forge script script/deploy_vault.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployVault \
		--account $(ACCOUNT_0) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify

vault-broadcast-ledger: load_prod_env clean
	forge script script/deploy_vault.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployVault \
		--ledger \
		--hd-paths  $(HD_PATH) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--broadcast

vault-verify-ledger: load_prod_env clean
	forge script script/deploy_vault.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--sender $(SENDER) \
		--tc DeployVault \
		--ledger \
		--hd-paths  $(HD_PATH) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		--verify

.PHONY: test \
	load_dev_env \
	load_prod_env \
	clean build \
	fmt \
	solhint \
	protocol \
	protocol-broadcast \
	protocol-verify \
	beacon \
	beacon-broadcast \
	beacon-verify \
	upgrade-implementation \
	upgrade-implementation-broadcast \
	upgrade-implementation-verify \
	vault \
	vault-broadcast \
	vault-verify \
	pre-commit
