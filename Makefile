IMAGE_NAME := lagoon-deployer

ifeq ($(ENV_TEST),)
	ENV_TEST := .env.dev
endif

ifeq ($(ENV_DEPLOY),)
	ENV_DEPLOY := .env.local-fork # local fork rpc-url
endif

ifeq ($(NETWORK_DOCKER),)
	NETWORK_DOCKER := local-fork-network 
endif

##################### FLAGS #####################

DOCKER_FLAGS := --rm \
								--platform linux/x86_64 \
								--network $(NETWORK_DOCKER) \
								--env-file $(ENV_DEPLOY)

DEPLOYER_FLAGS := --chain-id $$CHAIN_ID \
									--rpc-url $$RPC_URL \
									--sender $$SENDER

PK_FLAGS := $(DEPLOYER_FLAGS) \
						--private-key $$PRIVATE_KEY \
						--broadcast

LEDGER_FLAGS := $(DEPLOYER_FLAGS) \
								--ledger \
								--hd-paths $$HD_PATH \
								--broadcast

VERIFY_FLAGS := --etherscan-api-key $$ETHERSCAN_API_KEY \
								--verify 

#################### COMMANDS ####################

DOCKER_RUN := docker run $(DOCKER_FLAGS) 

#################### SCRIPTS ####################

FULL_SCRIPT := script/deploy_local_fork.s.sol:DeployFull
PROTOCOL_SCRIPT := script/deploy_protocol.s.sol:DeployProtocol
BEACON_SCRIPT := script/deploy_beacon.s.sol:DeployBeacon
VAULT_SCRIPT := script/deploy_vault.s.sol:DeployVault 

#################### UTILS #####################

load_dev_env:
	@echo "Using $(ENV_TEST) environment"
	$(eval include $(ENV_TEST))
	$(eval export $(set -a && source $(ENV_TEST) && set +a))

load_prod_env:
	@echo "Using $(ENV_DEPLOY) environment"
	$(eval include $(ENV_DEPLOY))
	$(eval export $(set -a && source $(ENV_DEPLOY) && set +a))

clean:
	@forge clean

build:
	@forge build

clean-docker:
	docker rmi $(IMAGE_NAME) || true

build-image: load_dev_env
	docker build \
		--build-arg VERSION_TAG=$(VERSION_TAG) \
		--secret "id=RPC_URL" \
		--secret "id=PERSONAL_ACCESS_TOKEN" \
		--platform linux/x86_64 \
		--no-cache \
		--progress=plain \
		-t $(IMAGE_NAME) \
		. # < do not remove the dot

test-image: build-image

test:
	forge test

fmt:
	forge fmt

solhint:
	pnpm exec solhint 'src/**/*.sol'

pre-commit: fmt test solhint
	git add -A

################### LOCAL FORK ##################

start-fork: load_prod_env
	docker compose --env-file $$ENV_DEPLOY up local-fork

stop-fork: load_prod_env
	docker compose --env-file $$ENV_DEPLOY down local-fork

########## PROTOCOL + BEACON + VAULT ############

# simulation
full: load_prod_env
		@echo "Deploying FeeRegistry + Beacon + Vault..."
		@$(DOCKER_RUN) $(IMAGE_NAME) $(DEPLOYER_FLAGS) $(FULL_SCRIPT)

# pk broadcast
deploy-full-pk: load_prod_env
		@echo "Deploying FeeRegistry + Beacon + Vault..."
		@$(DOCKER_RUN) $(IMAGE_NAME) $(PK_FLAGS) $(VERIFY_FLAGS) $(FULL_SCRIPT)

# ledger broadcast
deploy-full-ledger: load_prod_env clean
	@echo "Deploying FeeRegistry + Beacon + Vault..."
	@forge script $(LEDGER_FLAGS) $(VERIFY_FLAGS) $(FULL_SCRIPT)

################### PROTOCOL ONLY ################### 

# simulation
protocol: load_prod_env clean
	@echo "Deploying FeeRegistry..."
	@$(DOCKER_RUN) $(IMAGE_NAME) $(DEPLOYER_FLAGS) $(PROTOCOL_SCRIPT)
 
# pk broadcast
deploy-protocol-pk: load_prod_env
	@echo "Deploying FeeRegistry..."
	@$(DOCKER_RUN) $(IMAGE_NAME) $(PK_FLAGS) $(VERIFY_FLAGS) $(PROTOCOL_SCRIPT)

# ledger broadcast
deploy-protocol-ledger: load_prod_env clean
	@echo "Deploying FeeRegistry..."
	forge script $(LEDGER_FLAGS) $(VERIFY_FLAGS) $(PROTOCOL_SCRIPT)

################### BEACON ONLY ################### 

# simulation
beacon: load_prod_env clean
	@echo "Deploying Beacon..."
	@$(DOCKER_RUN) $(IMAGE_NAME) $(DEPLOYER_FLAGS) $(BEACON_SCRIPT)

# pk broadcast 
deploy-beacon-pk: load_prod_env
	@echo "Deploying Beacon..."
	@$(DOCKER_RUN) $(IMAGE_NAME) $(PK_FLAGS) $(VERIFY_FLAGS) $(BEACON_SCRIPT)

# ledger broadcast
deploy-beacon-ledger: load_prod_env clean
	@echo "Deploying Beacon..."
	@forge script $(LEDGER_FLAGS) $(VERIFY_FLAGS) $(BEACON_SCRIPT)

################### VAULT ONLY ################### 

# simulation
vault: load_prod_env
	@echo "Deploying Vault..."
	@$(DOCKER_RUN) $(IMAGE_NAME) $(DEPLOYER_FLAGS) $(VAULT_SCRIPT)

# pk broadcast 
deploy-vault-pk: load_prod_env
	@echo "Deploying Vault..."
	@$(DOCKER_RUN) $(IMAGE_NAME) $(PK_FLAGS) $(VERIFY_FLAGS) $(VAULT_SCRIPT)

# ledger broadcast
deploy-vault-ledger: load_prod_env clean
	@echo "Deploying Vault..."
	@forge script $(LEDGER_FLAGS) $(VERIFY_FLAGS) $(VAULT_SCRIPT)


.PHONY: load_dev_env \
	load_prod_env \
	clean \
	build \
	clean-docker \
	build-image \
	test-image \
	test \
	fmt \
	solhint \
	pre-commit \
	start-fork \
	stop-fork \
	full \
	deploy-full-ledger \
	deploy-full-pk \
	protocol \
	deploy-protocol-pk \
	deploy-protocol-ledger \
	beacon\
	deploy-beacon-ledger \
	deploy-beacon-pk \
	vault\
	deploy-vault-ledger \
	deploy-vault-pk
