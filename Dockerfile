ARG NODE_VERSION=22.11.0
FROM node:${NODE_VERSION}-alpine AS node

# Use the latest foundry image
FROM ghcr.io/foundry-rs/foundry:v0.3.0

RUN apk add --no-cache git bash

# OZ scripts expect npx; we take it from official node image
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

# Verify installation
RUN node -v && npm -v && npx -v


# Can be overriden through .env.build (default env is set in Makefile)
ARG GH_BRANCH="main"
ARG FOUNDRY_FFI=true
ARG PROXY=true

RUN echo "Branch: ${GH_BRANCH}"

# Not meant to be overriden
ARG ASSET=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
ARG WRAPPED_NATIVE_TOKEN=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

# Infomation purpose only
ARG USDC_MAINNET=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
ARG WETH_MAINNET=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
ARG ETH_MAINNET=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
ARG WBTC_MAINNET=0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599

# clone vault repo
RUN --mount=type=secret,id=PERSONAL_ACCESS_TOKEN \
  PERSONAL_ACCESS_TOKEN=$(cat /run/secrets/PERSONAL_ACCESS_TOKEN) && \
  git clone --branch ${GH_BRANCH} "https://$PERSONAL_ACCESS_TOKEN@github.com/hopperlabsxyz/lagoon-v0" vault

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
