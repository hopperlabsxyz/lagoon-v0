// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Silo} from "./Silo.sol";
// import {IERC7540} from "./IERC7540.sol";

using Math for uint256;
using SafeERC20 for IERC20;

// IERC7540,
contract Vault is
    ERC4626Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable
{
    /// @custom:storage-location erc7201:hopper.storage.vault
    struct VaultStorage {
        uint256 totalAssets;
        uint256 epochId;
        Silo pendingSilo;
        Silo claimableSilo;
        mapping(address controller => mapping(address operator => bool)) isOperator;
    }

    // keccak256(abi.encode(uint256(keccak256("hopperprotocol.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant HopperVaultStorage =
        0xfdb0cd9880e84ca0b573fff91a05faddfecad925c5f393111a47359314e28e00;

    function _getVaultStorage() private pure returns (VaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := HopperVaultStorage
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 underlying,
        string memory name,
        string memory symbol
    ) public virtual onlyInitializing {
        __ERC4626_init(underlying);
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __ERC20Pausable_init();
        VaultStorage storage $ = _getVaultStorage();
        $.claimableSilo = new Silo(underlying);
        $.pendingSilo = new Silo(underlying);
    }

    // ## Overrides ##
    function totalAssets() public view override returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        return $.totalAssets;
    }

    function decimals()
        public
        view
        override(ERC4626Upgradeable, ERC20Upgradeable)
        returns (uint8)
    {
        return ERC4626Upgradeable.decimals();
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20PausableUpgradeable, ERC20Upgradeable) {
        return ERC20PausableUpgradeable._update(from, to, value);
    }

    // ## Requests ##
}
