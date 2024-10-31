ENV_PROD_BASE := .env.prod-base
ENV_PROD_ARB1 := .env.prod-arb1

build:; forge build
test:; forge test -vv

.PHONY: build
