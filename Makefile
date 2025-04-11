IMAGE_NAME := lagoon-v0

# only used if you want to build docker image
ifeq ($(VERSION_TAG),)
	VERSION_TAG := latest
endif

IMAGE := ghcr.io/hopperlabsxyz/$(IMAGE_NAME)

ifeq ($(ENV_BUILD),)
	ENV_BUILD := .env.build
endif

ifeq ($(ENV_DEPLOY),)
	ENV_DEPLOY := .env.deploy
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
FACTORY_SCRIPT := script/deploy_factory.s.sol:DeployBeaconProxyFactory 
FACTORY_SCRIPT := script/deploy_implementation.s.sol:DeployBeaconProxyFactory 

#################### UTILS #####################

load_dev_env:
	@echo "Using $(ENV_BUILD) environment"
	$(eval include $(ENV_BUILD))
	$(eval export $(set -a && source $(ENV_BUILD) && set +a))

load_prod_env:
	@echo "Using $(ENV_DEPLOY) environment"
	$(eval include $(ENV_DEPLOY))
	$(eval export $(set -a && source $(ENV_DEPLOY) && set +a))

clean:
	@forge clean

build:
	@forge build

clean-docker:
	docker rmi $(IMAGE):$(VERSION_TAG) || true

build-image: load_dev_env
	docker build \
		--build-arg GH_BRANCH=$(GH_BRANCH) \
	  --build-arg FOUNDRY_FFI=$(FOUNDRY_FFI) \
		--build-arg PROXY=$(PROXY) \
		--secret "id=RPC_URL" \
		--secret "id=PERSONAL_ACCESS_TOKEN" \
		--platform linux/x86_64 \
		--no-cache \
		--progress=plain \
		-t $(IMAGE):$(VERSION_TAG) \
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

################### PROTOCOL #################### 

# simulation
protocol: load_prod_env clean
	@echo "Deploying FeeRegistry..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(DEPLOYER_FLAGS) $(PROTOCOL_SCRIPT)
 
# pk broadcast
deploy-protocol-pk: load_prod_env
	@echo "Deploying FeeRegistry..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(PK_FLAGS) $(VERIFY_FLAGS) $(PROTOCOL_SCRIPT)

# ledger broadcast
deploy-protocol-ledger: load_prod_env clean
	@echo "Deploying FeeRegistry..."
	forge script $(LEDGER_FLAGS) $(VERIFY_FLAGS) $(PROTOCOL_SCRIPT)

################### VAULT ##################### 

# simulation
vault: load_prod_env
	@echo "Deploying Vault..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(DEPLOYER_FLAGS) $(VAULT_SCRIPT)

# pk broadcast 
deploy-vault-pk: load_prod_env
	@echo "Deploying Vault..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(PK_FLAGS) $(VERIFY_FLAGS) $(VAULT_SCRIPT)

# ledger broadcast
deploy-vault-ledger: load_prod_env clean
	@echo "Deploying Vault..."
	@forge script $(LEDGER_FLAGS) $(VERIFY_FLAGS) $(VAULT_SCRIPT)

####################### FACTORY #####################

# simulation
factory: load_prod_env
	@echo "Deploying Factory..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(DEPLOYER_FLAGS) $(FACTORY_SCRIPT)

# pk broadcast 
deploy-factory-pk: load_prod_env
	@echo "Deploying Factory..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(PK_FLAGS) $(VERIFY_FLAGS) $(FACTORY_SCRIPT)

# ledger broadcast
deploy-factory-ledger: load_prod_env clean
	@echo "Deploying Factory..."
	@forge script $(LEDGER_FLAGS) $(VERIFY_FLAGS) $(FACTORY_SCRIPT)
	
####################### IMPLEMENTATION #####################

# simulation
implementation: load_prod_env
	@echo "Deploying Implementation..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(DEPLOYER_FLAGS) $(IMPLEMENTATION_SCRIPT)

# pk broadcast 
deploy-implementation-pk: load_prod_env
	@echo "Deploying Implementation..."
	@$(DOCKER_RUN) $(IMAGE):$(VERSION_TAG) $(PK_FLAGS) $(VERIFY_FLAGS) $(IMPLEMENTATION_SCRIPT)


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
	deploy-vault-pk \
	factory\
	deploy-factory-ledger \
	deploy-factory-pk
