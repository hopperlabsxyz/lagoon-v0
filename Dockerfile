ARG NODE_VERSION=22.11.0
FROM node:${NODE_VERSION}-alpine AS node

# Use the latest foundry image
FROM ghcr.io/foundry-rs/foundry:v0.3.0

RUN apk add --no-cache git

# OZ scripts expect npx; we take it from official node image
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

# Verify installation
RUN node -v && npm -v && npx -v


# default code used
ARG VERSION_TAG="v0.2.1"

# dev env
ARG FOUNDRY_FFI=true
ARG PROXY=true
ARG NETWORK=MAINNET
ARG USDC_MAINNET=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
ARG WETH_MAINNET=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
ARG ETH_MAINNET=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
ARG WRAPPED_NATIVE_TOKEN_MAINNET=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
ARG WBTC_MAINNET=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
ARG VAULT_NAME="MVP_HOPPER"
ARG VAULT_SYMBOL="MVP"

# clone vault repo
RUN --mount=type=secret,id=PERSONAL_ACCESS_TOKEN \
  PERSONAL_ACCESS_TOKEN=$(cat /run/secrets/PERSONAL_ACCESS_TOKEN) && \
  git clone --branch feat/v0.3.0 "https://$PERSONAL_ACCESS_TOKEN@github.com/hopperlabsxyz/lagoon-v0" vault

# Copy our source code into the container
WORKDIR /vault

RUN npm install

# build vault
RUN forge clean
RUN forge build
RUN --mount=type=secret,id=RPC_URL \
  FOUNDRY_ETH_RPC_URL=$(cat /run/secrets/RPC_URL) \
  UNDERLYING_NAME=USDC forge test \
  && \
  FOUNDRY_ETH_RPC_URL=$(cat /run/secrets/RPC_URL) \
  UNDERLYING_NAME=WRAPPED_NATIVE_TOKEN forge test

# set OZ bash path to /bin/sh
ENV OPENZEPPELIN_BASH_PATH="/bin/sh"

ENTRYPOINT [ "forge", "script" ]
