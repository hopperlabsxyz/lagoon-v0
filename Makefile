ENV_DEV := .env.dev
# ENV_PROD := .env.prod-arb1
ENV_PROD := .env.prod-base


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
	forge test -vv

fmt:
	forge fmt

solhint:
	pnpm exec solhint 'src/**/*.sol'

protocol: load_prod_env clean
	forge script script/deploy_protocol.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--tc DeployProtocol \
		--account $(ACCOUNT) \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

beacon: load_prod_env clean
	forge script script/deploy_beacon.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--tc DeployBeacon \
		--account $(ACCOUNT) \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

vault: load_prod_env clean
	forge script script/deploy_vault.s.sol \
		--chain-id $(CHAIN_ID) \
		--rpc-url $(RPC_URL) \
		--tc DeployVault \
		--account $(ACCOUNT) \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

pre-commit: fmt test solhint
	git add -A

.PHONY: load_dev_env load_prod_env clean build test fmt solhint protocol beacon vault pre-commit
