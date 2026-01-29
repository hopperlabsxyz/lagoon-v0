# CLAUDE.md - Code Audit & Review Guidelines for Lagoon Protocol

## Purpose

This document guides code audits and commit reviews for the Lagoon Protocol - an ERC7540-compliant tokenized vault handling user funds.

## Technology Stack & Versions

### Core Technologies

| Technology | Version | Official Documentation |
|------------|---------|------------------------|
| Solidity | 0.8.26 | https://docs.soliditylang.org/en/v0.8.26/ |
| Foundry/Forge | v0.3.0 | https://book.getfoundry.sh/ |
| EVM Version | Shanghai | - |

### Dependencies

| Dependency | Version | Official Documentation |
|------------|---------|------------------------|
| forge-std | 1.9.7 | https://book.getfoundry.sh/forge/forge-std |
| OpenZeppelin Contracts | 5.0.0 | https://docs.openzeppelin.com/contracts/5.x/ |
| OpenZeppelin Contracts Upgradeable | 5.0.0 | https://docs.openzeppelin.com/contracts/5.x/upgradeable |
| OpenZeppelin Foundry Upgrades | 0.4.0 | https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades |

### ERC Standards

| Standard | EIP Reference |
|----------|---------------|
| ERC7540 (Async Vault) | https://eips.ethereum.org/EIPS/eip-7540 |
| ERC7575 | https://eips.ethereum.org/EIPS/eip-7575 |
| ERC4626 (Vault) | https://eips.ethereum.org/EIPS/eip-4626 |
| ERC20 (Token) | https://eips.ethereum.org/EIPS/eip-20 |

## Audit Requirements

### Documentation Sourcing

**All audit findings and recommendations MUST be backed by official documentation.**

When reporting issues or suggesting fixes:
1. Reference the specific Solidity version documentation (v0.8.26)
2. Reference OpenZeppelin v5.x documentation (NOT v4.x - APIs differ significantly)
3. Cite the relevant EIP for standard compliance issues
4. Link to Foundry documentation for testing/tooling concerns

### Security Checklist

Review all changes against:

- [ ] **Reentrancy**: Check external calls, state changes order, use of ReentrancyGuard
- [ ] **Access Control**: Verify role checks (KEEPER, SAFE, VALUER roles)
- [ ] **Integer Overflow**: Solidity 0.8.26 has built-in checks, but verify unchecked blocks
- [ ] **Front-running**: MEV considerations for deposit/redeem operations
- [ ] **Oracle Manipulation**: Price/share calculations in vault operations
- [ ] **Rounding Errors**: ERC4626 share/asset conversions favor the vault
- [ ] **Storage Collisions**: Upgradeable contract storage layout
- [ ] **Initialization**: Proper initializer usage, no uninitialized proxies
- [ ] **ERC Compliance**: Adherence to ERC7540/ERC4626 specifications

### Common Vulnerability Patterns

1. **ERC4626 Inflation Attack**: First depositor can manipulate share price
2. **Async Request Manipulation**: ERC7540 request/claim flow vulnerabilities
3. **Fee Calculation Errors**: Entry/exit fee rounding and precision loss
4. **Proxy Upgrade Risks**: Storage layout changes, initialization gaps
5. **Role Misconfiguration**: Missing or incorrect access modifiers

## Project Structure

```
src/
├── v0.5.0/          # Core vault V0.5.0
├── v0.6.0/          # Core vault V0.6.0 (with libraries)
│   ├── libraries/   # ERC7540Lib, FeeLib, RolesLib, VaultLib
│   ├── vault/       # Vault.sol, VaultInit.sol
│   └── primitives/  # Enums, Errors, Events, VaultStorage
├── protocol-v1/     # BeaconProxyFactory, FeeRegistry
├── protocol-v2/     # OptinProxyFactory, ProtocolRegistry
└── proxy/           # OptinProxy, DelayProxyAdmin
```

## Commit Review Process

When reviewing commits:

1. **Verify test coverage** - New code must have corresponding tests
2. **Check formatting** - Run `forge fmt --check`
3. **Run full test suite** - `forge test`
4. **Review storage changes** - For upgradeable contracts, verify no storage collisions
5. **Validate documentation** - NatSpec comments on public/external functions

## Build & Test Commands

```bash
forge soldeer install  # Install dependencies
forge build            # Compile
forge test             # Run tests
forge fmt              # Format code
```

## Version-Specific Audit Notes

- **OpenZeppelin v5.0.0**: New access control patterns, `Ownable` requires constructor arg
- **Solidity 0.8.26**: Custom errors preferred over require strings, PUSH0 available
- **Shanghai EVM**: New opcodes available, verify compatibility with target chains

## License

BUSL-1.1 (Business Source License 1.1)
