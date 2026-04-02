// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// forge script script/deploy_vault_v060_sdk_test.s.sol \
//   --rpc-url $RPC_URL \
//   --broadcast \
//   -vvvv
//
// Required env vars:
//   UNDERLYING            – ERC20 token address used as vault asset
//   WRAPPED_NATIVE_TOKEN  – WETH / wrapped-native address on the target chain
//
// All role addresses are derived from deterministic private keys 1-8
// (TEST ONLY – never use these keys on a production network).

import {Script, console} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LagoonVault} from "@src/proxy/OptinProxy.sol";
import {AccessMode} from "@src/v0.6.0/primitives/Enums.sol";
import {Guardrails, Rates} from "@src/v0.6.0/primitives/Struct.sol";
import {InitStruct, Vault} from "@src/v0.6.0/vault/Vault-v0.6.0.sol";

interface IVaultInit {
    function initialize(
        bytes memory data,
        address feeRegistry,
        address wrappedNativeToken
    ) external;
}

// ---------------------------------------------------------------------------
// DeployVaultV060SdkTest
// ---------------------------------------------------------------------------
contract DeployVaultV060SdkTest is Script {
    // ── Deterministic role private keys (TEST ONLY)
    // ─────────────────────────
    // uint256 constant signerPK = vm.envUint("PK");

    // ── Fee rates (BPS, 1 BPS = 0.01 %)
    // ────────────────────────────────────
    uint16 constant MANAGEMENT_RATE = 200; //  2.00 %
    uint16 constant PERFORMANCE_RATE = 2000; // 20.00 %
    uint16 constant ENTRY_RATE = 50; //  0.50 %
    uint16 constant EXIT_RATE = 100; //  1.00 %
    uint16 constant HAIRCUT_RATE = 25; //  0.25 %
    uint16 constant PROTOCOL_RATE = 1000; // 10.00 % of vault fees

    // ── Post-deployment verifiable values
    // ───────────────────────────────────
    uint256 constant MAX_CAP = 1_000_000e6; // 1 M asset-units  (onlySafe)
    uint128 constant TOTAL_ASSETS_LIFESPAN = 1 days; //          (onlySafe)
    uint256 constant GUARDRAILS_UPPER_RATE = 5000; // +50 %/yr  (onlySecurityCouncil)
    int256 constant GUARDRAILS_LOWER_RATE = -3000; // -30 %/yr  (onlySecurityCouncil)
    uint256 constant NEW_TOTAL_ASSETS = 1000e6; // 1 000 units  (onlyValuationManager)

    // ── Proxy admin delay (min 1 day enforced by DelayProxyAdmin) ───────────
    uint256 constant PROXY_DELAY = 1 days;

    function run() external {
        address underlying = vm.envAddress("ASSET");
        address wrappedNativeToken = vm.envAddress("WRAPPED_NATIVE_TOKEN");

        // Derive deterministic role addresses
        address ADMIN = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;
        address SAFE = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;
        address FEE_RECEIVER = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;
        address WHITELIST_MANAGER = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;
        address VALUATION_MANAGER = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;
        address SECURITY_COUNCIL = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;
        address SUPER_OPERATOR = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;
        address PROTOCOL_FEE_RECEIVER = 0xb03EdA433d5bB1ef76b63087D4042A92C02822bD;

        // _logRoles(ADMIN, SAFE, FEE_RECEIVER, WHITELIST_MANAGER, VALUATION_MANAGER, SECURITY_COUNCIL, SUPER_OPERATOR,
        // PROTOCOL_FEE_RECEIVER);

        vm.startBroadcast();

        // ── 1. MockRegistry
        // ─────────────────────────────────────────────────
        MockRegistry registry = new MockRegistry(PROTOCOL_FEE_RECEIVER, 12);
        console.log("\nMockRegistry:            ", address(registry));

        // ── 2. Vault v0.6.0 implementation
        // ──────────────────────────────────
        Vault implementation = new Vault(true); // disable initializers on impl
        console.log("Implementation:          ", address(implementation));

        // ── 3. Wire implementation into registry
        // ─────────────────────────────
        registry.setDefaultLogic(address(implementation));

        // ── 4-5. Build InitStruct and deploy LagoonVault (OptinProxy) directly
        Vault vault = _deployProxy(
            registry,
            underlying,
            wrappedNativeToken,
            ADMIN,
            SAFE,
            FEE_RECEIVER,
            WHITELIST_MANAGER,
            VALUATION_MANAGER,
            SECURITY_COUNCIL,
            SUPER_OPERATOR
        );
        console.log("Vault proxy:             ", address(vault));

        //
        // ─────────────────────────────────────────────────────────────────────
        // Post-deployment updates
        // Each call is signed by the private key of the role that owns the
        // function, making every stored value independently verifiable by the SDK.
        //
        // ─────────────────────────────────────────────────────────────────────

        // ── 6. Safe: maxCap + totalAssetsLifespan
        // ────────────────────────────
        vault.updateMaxCap(MAX_CAP);
        vault.updateTotalAssetsLifespan(TOTAL_ASSETS_LIFESPAN);

        // ── 7. WhitelistManager: whitelist role addresses
        // ─────────────────────
        _whitelistRoles(vault, ADMIN, SAFE, FEE_RECEIVER, VALUATION_MANAGER, SUPER_OPERATOR);

        // ── 9. SecurityCouncil: configure + activate guardrails ──────────────
        vault.updateGuardrails(Guardrails({upperRate: GUARDRAILS_UPPER_RATE, lowerRate: GUARDRAILS_LOWER_RATE}));
        vault.updateActivated(true);

        vm.stopBroadcast();

        _logValues(underlying);
    }

    function _deployProxy(
        MockRegistry registry,
        address underlying,
        address wrappedNativeToken,
        address ADMIN,
        address SAFE,
        address FEE_RECEIVER,
        address WHITELIST_MANAGER,
        address VALUATION_MANAGER,
        address SECURITY_COUNCIL,
        address SUPER_OPERATOR
    ) internal returns (Vault) {
        // ── 4. Build InitStruct
        // ──────────────────────────────────────────────
        InitStruct memory init = InitStruct({
            underlying: IERC20(underlying),
            name: "Lagoon SDK Test Vault",
            symbol: "LSTV",
            safe: SAFE,
            whitelistManager: WHITELIST_MANAGER,
            valuationManager: VALUATION_MANAGER,
            admin: ADMIN,
            feeReceiver: FEE_RECEIVER,
            managementRate: MANAGEMENT_RATE,
            performanceRate: PERFORMANCE_RATE,
            accessMode: AccessMode.Whitelist,
            entryRate: ENTRY_RATE,
            exitRate: EXIT_RATE,
            haircutRate: HAIRCUT_RATE,
            securityCouncil: SECURITY_COUNCIL,
            externalSanctionsList: address(12_345),
            initialTotalAssets: 100_000,
            superOperator: SUPER_OPERATOR,
            allowHighWaterMarkReset: true
        });

        bytes memory initData =
            abi.encodeCall(IVaultInit.initialize, (abi.encode(init), address(registry), wrappedNativeToken));

        // ── 5. Deploy LagoonVault (OptinProxy) directly
        // ──────────────────────
        // _logic = address(0)  →  proxy resolves logic via registry.defaultLogic()
        return Vault(
            address(
                new LagoonVault({
                    _logic: address(0),
                    _logicRegistry: address(registry),
                    _initialOwner: ADMIN,
                    _initialDelay: PROXY_DELAY,
                    _data: initData
                })
            )
        );
    }

    function _whitelistRoles(
        Vault vault,
        address ADMIN,
        address SAFE,
        address FEE_RECEIVER,
        address VALUATION_MANAGER,
        address SUPER_OPERATOR
    ) internal {
        address[] memory toWhitelist = new address[](5);
        toWhitelist[0] = ADMIN;
        toWhitelist[1] = SAFE;
        toWhitelist[2] = FEE_RECEIVER;
        toWhitelist[3] = VALUATION_MANAGER;
        toWhitelist[4] = SUPER_OPERATOR;
        vault.addToWhitelist(toWhitelist);
    }

    function _logRoles(
        address ADMIN,
        address SAFE,
        address FEE_RECEIVER,
        address WHITELIST_MANAGER,
        address VALUATION_MANAGER,
        address SECURITY_COUNCIL,
        address SUPER_OPERATOR,
        address PROTOCOL_FEE_RECEIVER
    ) internal pure {
        console.log("=== Role addresses ===");
        console.log("Admin / proxy-admin owner:", ADMIN);
        console.log("Safe:                     ", SAFE);
        console.log("FeeReceiver:              ", FEE_RECEIVER);
        console.log("WhitelistManager:         ", WHITELIST_MANAGER);
        console.log("ValuationManager:         ", VALUATION_MANAGER);
        console.log("SecurityCouncil:          ", SECURITY_COUNCIL);
        console.log("SuperOperator:            ", SUPER_OPERATOR);
        console.log("ProtocolFeeReceiver:      ", PROTOCOL_FEE_RECEIVER);
    }

    function _logValues(
        address underlying
    ) internal view {
        console.log("\n=== Init values ===");
        console.log("name:              Lagoon SDK Test Vault");
        console.log("symbol:            LSTV");
        console.log("underlying:        ", underlying);
        console.log("managementRate:    ", MANAGEMENT_RATE, " bps");
        console.log("performanceRate:   ", PERFORMANCE_RATE, " bps");
        console.log("entryRate:         ", ENTRY_RATE, " bps");
        console.log("exitRate:          ", EXIT_RATE, " bps");
        console.log("haircutRate:       ", HAIRCUT_RATE, " bps");
        console.log("accessMode:        Whitelist (1)");
        console.log("allowHWMReset:     true");
        console.log("protocolRate:      ", PROTOCOL_RATE, " bps");
        console.log("\n=== Post-deployment values ===");
        console.log("maxCap:                      ", MAX_CAP);
        console.log("totalAssetsLifespan (s):     ", uint256(TOTAL_ASSETS_LIFESPAN));
        console.log("isSyncRedeemAllowed:         true");
        console.log("newTotalAssets:              ", NEW_TOTAL_ASSETS);
        console.log("guardrailsUpperRate (bps):   ", GUARDRAILS_UPPER_RATE);
        console.log("guardrailsLowerRate (bps):   ", GUARDRAILS_LOWER_RATE);
        console.log("guardrailsActivated:         true");
    }
}

// ---------------------------------------------------------------------------
// MockRegistry
// ---------------------------------------------------------------------------
// A minimal stand-in for ProtocolRegistry that:
//   • always returns `true` for canUseLogic  (any implementation is allowed)
//   • exposes a settable defaultLogic        (used by LagoonVault constructor)
//   • returns fixed protocol fee data        (readable by the vault's FeeLib)
// ---------------------------------------------------------------------------
contract MockRegistry {
    address public defaultLogic;
    address public immutable PROTOCOL_FEE_RECEIVER;
    uint16 public immutable PROTOCOL_RATE;

    constructor(
        address _protocolFeeReceiver,
        uint16 _protocolRate
    ) {
        PROTOCOL_FEE_RECEIVER = _protocolFeeReceiver;
        PROTOCOL_RATE = _protocolRate;
    }

    // No access control – anyone can point it at a new implementation.
    // Acceptable for a local / testnet SDK-validation registry.
    function setDefaultLogic(
        address _logic
    ) external {
        defaultLogic = _logic;
    }

    // ── LogicRegistry interface
    // ──────────────────────────────────────────────
    function canUseLogic(
        address,
        address
    ) external pure returns (bool) {
        return true;
    }

    // ── FeeRegistry interface
    // ────────────────────────────────────────────────
    function protocolFeeReceiver() external view returns (address) {
        return PROTOCOL_FEE_RECEIVER;
    }

    // Called by FeeLib as protocolRate() (msg.sender = vault)
    function protocolRate() external view returns (uint256) {
        return PROTOCOL_RATE;
    }

    // Called by FeeLib as protocolRate(vault)
    function protocolRate(
        address
    ) external view returns (uint256) {
        return PROTOCOL_RATE;
    }
}
