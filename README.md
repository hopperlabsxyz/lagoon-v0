# Lagoon Protocol - Smart Contracts

Source code for the Lagoon Protocol ERC7540-compliant tokenized vault.

For documentation, visit [docs.lagoon.finance](https://docs.lagoon.finance/).

## Repository Structure

```
src/
├── protocol-v1/     # BeaconProxyFactory, FeeRegistry
├── protocol-v2/     # OptinProxyFactory, ProtocolRegistry, LogicRegistry
├── protocol-v3/     # OptinProxyFactory v3
├── proxy/           # OptinProxy, DelayProxyAdmin
├── v0.5.1/          # Vault v0.5.1 (ERC7540)
└── v0.6.0/          # Vault v0.6.0 (modular libraries)
```

## Building

Requires [Foundry](https://book.getfoundry.sh/).

```bash
forge soldeer install
forge build
```

## Audits

See [docs.lagoon.finance/resources/audits](https://docs.lagoon.finance/resources/audits).

## License

Business Source License 1.1 (`BUSL-1.1`) — see [LICENSE](./LICENSE).
