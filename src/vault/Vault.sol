// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ERC7540Upgradeable} from "./ERC7540.sol";
import {State} from "./Enums.sol";
import {Closed, NewNAVMissing, NotClosing, NotOpen, NotWhitelisted} from "./Errors.sol";
import {Referral, StateUpdated, TotalAssetsUpdated, UpdateTotalAssets} from "./Events.sol";

import {FeeManager} from "./FeeManager.sol";
import {RolesUpgradeable} from "./Roles.sol";
import {WhitelistableUpgradeable} from "./Whitelistable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";

// import {console} from "forge-std/console.sol";

using SafeERC20 for IERC20;

contract Vault is ERC7540Upgradeable, WhitelistableUpgradeable, FeeManager {
    /// @custom:storage-definition erc7201:hopper.storage.vault
    /// @param underlying The address of the underlying asset.
    /// @param name The name of the vault and by extension the ERC20 token.
    /// @param symbol The symbol of the vault and by extension the ERC20 token.
    /// @param safe The address of the safe smart contract.
    /// @param whitelistManager The address of the whitelist manager.
    /// @param navManager The address of the NAV manager.
    /// @param admin The address of the owner of the vault.
    /// @param feeReceiver The address of the fee receiver.
    /// @param feeRegistry The address of the fee registry.
    /// @param wrappedNativeToken The address of the wrapped native token.
    /// @param managementRate The management fee rate.
    /// @param performanceRate The performance fee rate.
    /// @param rateUpdateCooldown The cooldown period for updating the fee rates.
    /// @param enableWhitelist A boolean indicating whether the whitelist is enabled.
    /// @param whitelist An array of addresses to be whitelisted.
    struct InitStruct {
        IERC20 underlying;
        string name;
        string symbol;
        address safe;
        address whitelistManager;
        address navManager;
        address admin;
        address feeReceiver;
        address feeRegistry;
        address wrappedNativeToken;
        uint16 managementRate;
        uint16 performanceRate;
        bool enableWhitelist;
        uint256 rateUpdateCooldown;
        address[] whitelist;
    }

    /// @custom:storage-location erc7201:hopper.storage.vault
    /// @param newTotalAssets The new total assets of the vault. It is used to update the totalAssets variable.
    /// @param state The state of the vault. It can be Open, Closing, or Closed.
    struct VaultStorage {
        uint256 newTotalAssets;
        State state;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    /// @custom:slot erc7201:hopper.storage.vault
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant vaultStorage = 0x0e6b3200a60a991c539f47dddaca04a18eb4bcf2b53906fb44751d827f001400;

    /// @notice Returns the storage struct of the vault.
    /// @return _vaultStorage The storage struct of the vault.
    function _getVaultStorage() internal pure returns (VaultStorage storage _vaultStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _vaultStorage.slot := vaultStorage
        }
    }

    /// @notice Initializes the vault.
    /// @param init The initialization parameters of the vault.
    function initialize(InitStruct memory init) public virtual initializer {
        __ERC4626_init(init.underlying);
        __ERC20_init(init.name, init.symbol);
        __ERC20Pausable_init();
        __FeeManager_init(
            init.feeRegistry, init.managementRate, init.performanceRate, decimals(), init.rateUpdateCooldown
        );
        __ERC7540_init(init.underlying, init.wrappedNativeToken);
        __Whitelistable_init(init.enableWhitelist);
        __Roles_init(
            RolesUpgradeable.RolesStorage({
                whitelistManager: init.whitelistManager,
                feeReceiver: init.feeReceiver,
                safe: init.safe,
                feeRegistry: FeeRegistry(init.feeRegistry),
                navManager: init.navManager
            })
        );
        __Ownable_init(init.admin); // initial vault owner

        VaultStorage storage $ = _getVaultStorage();
        RolesStorage storage $roles = _getRolesStorage();

        $.newTotalAssets = type(uint256).max;

        $.state = State.Open;
        emit StateUpdated(State.Open);

        if (init.enableWhitelist) {
            WhitelistableStorage storage $whitelistStorage = _getWhitelistableStorage();
            $whitelistStorage.isWhitelisted[init.feeReceiver] = true;
            $whitelistStorage.isWhitelisted[$roles.feeRegistry.protocolFeeReceiver()] = true;
            $whitelistStorage.isWhitelisted[init.safe] = true;
            $whitelistStorage.isWhitelisted[pendingSilo()] = true;
            uint256 i = 0;
            for (; i < init.whitelist.length;) {
                $whitelistStorage.isWhitelisted[init.whitelist[i]] = true;
                unchecked {
                    ++i;
                }
            }
        }
    }

    /// @notice Reverts if the vault is not open.
    modifier onlyOpen() {
        State _state = _getVaultStorage().state;
        if (_state != State.Open) revert NotOpen(_state);
        _;
    }

    /// @notice Reverts if the vault is not closing.
    modifier onlyClosing() {
        State _state = _getVaultStorage().state;
        if (_state != State.Closing) revert NotClosing(_state);
        _;
    }

    /// @param assets The amount of assets to deposit.
    /// @param controller The address of the controller involved in the deposit request.
    /// @param owner The address of the owner for whom the deposit is requested.
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public payable override(ERC7540Upgradeable) whenNotPaused returns (uint256 requestId) {
        return _requestDeposit(assets, controller, owner);
    }

    /// @notice Requests a deposit of assets, subject to whitelist validation.
    /// @param assets The amount of assets to deposit.
    /// @param controller The address of the controller involved in the deposit request.
    /// @param owner The address of the owner for whom the deposit is requested.
    /// @param referral The address who referred the deposit.
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner,
        address referral
    ) public payable whenNotPaused returns (uint256 requestId) {
        requestId = _requestDeposit(assets, controller, owner);
        if (address(referral) != address(0)) {
            emit Referral(referral, owner, requestId, assets);
        }
    }

    /// @param assets The amount of assets to deposit.
    /// @param controller The address of the controller involved in the deposit request.
    /// @param owner The address of the owner for whom the deposit is requested.
    /// @return The id of the deposit request.
    function _requestDeposit(uint256 assets, address controller, address owner) internal returns (uint256) {
        if (!isWhitelisted(owner)) revert NotWhitelisted();
        return super.requestDeposit(assets, controller, owner);
    }

    /// @notice Requests the redemption of tokens, subject to whitelist validation.
    /// @param shares The number of tokens to redeem.
    /// @param controller The address of the controller involved in the redemption request.
    /// @param owner The address of the token owner requesting redemption.
    /// @return requestId The id of the redeem request.
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) public override(ERC7540Upgradeable) onlyOpen whenNotPaused returns (uint256 requestId) {
        if (!isWhitelisted(owner)) revert NotWhitelisted();
        return super.requestRedeem(shares, controller, owner);
    }

    /// @notice Update newTotalAssets variable in order to update totalAssets.
    /// @param _newTotalAssets The new total assets of the vault.
    function updateNewTotalAssets(uint256 _newTotalAssets) public onlyNAVManager whenNotPaused {
        VaultStorage storage $ = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        if ($.state == State.Closed) revert Closed();

        $erc7540.epochs[$erc7540.depositEpochId].settleId = $erc7540.depositSettleId;
        $erc7540.epochs[$erc7540.redeemEpochId].settleId = $erc7540.redeemSettleId;

        address _pendingSilo = pendingSilo();
        uint256 pendingAssets = IERC20(asset()).balanceOf(_pendingSilo);
        uint256 pendingShares = balanceOf(_pendingSilo);

        if (pendingAssets != 0) $erc7540.depositEpochId += 2;
        if (pendingShares != 0) $erc7540.redeemEpochId += 2;

        $.newTotalAssets = _newTotalAssets;

        emit UpdateTotalAssets(_newTotalAssets);
    }

    /// @notice Settles deposit requests, integrates user funds into the vault strategy, and enables share claims.
    /// If possible, it also settles redeem requests.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    function settleDeposit() public override onlySafe onlyOpen {
        RolesStorage storage $roles = _getRolesStorage();

        _updateTotalAssets();
        _takeFees($roles.feeReceiver, $roles.feeRegistry.protocolFeeReceiver());
        _setHighWaterMark(
            _convertToAssets(10 ** decimals(), Math.Rounding.Floor) // this is the price per share
        );
        _settleDeposit(msg.sender);
        _settleRedeem(msg.sender); // if it is possible to settleRedeem, we should do so
    }

    /// @notice Settles redeem requests, only callable by the safe.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    /// @dev After updating totalAssets, it takes fees, updates highWaterMark and finally settles redeem requests.
    /// @inheritdoc ERC7540Upgradeable
    function settleRedeem() public override onlySafe onlyOpen {
        RolesStorage storage $roles = _getRolesStorage();

        _updateTotalAssets();
        _takeFees($roles.feeReceiver, $roles.feeRegistry.protocolFeeReceiver());
        _setHighWaterMark(_convertToAssets(10 ** decimals(), Math.Rounding.Floor));
        _settleRedeem(msg.sender);
    }

    /// @dev Updates the totalAssets variable with the newTotalAssets variable.
    function _updateTotalAssets() internal whenNotPaused {
        VaultStorage storage $vault = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint256 newTotalAssets = $vault.newTotalAssets;

        if (
            newTotalAssets == type(uint256).max // it means newTotalAssets has not been updated
        ) revert NewNAVMissing();

        $erc7540.totalAssets = newTotalAssets;
        $vault.newTotalAssets = type(uint256).max; // by setting it to max, we ensure that it is not called again
        emit TotalAssetsUpdated(newTotalAssets);
    }

    /////////////////
    // MVP UPGRADE //
    /////////////////

    /// @notice Initiates the closing of the vault. Can only be called by the owner.
    function initiateClosing() external onlyOwner onlyOpen {
        _getVaultStorage().state = State.Closing;
        emit StateUpdated(State.Closing);
    }

    /// @notice Closes the vault, only redemption and withdrawal are allowed after this. Can only be called by the safe.
    /// @dev Users can still requestDeposit but it can't be settled.
    function close() external onlySafe onlyClosing {
        RolesStorage storage $roles = _getRolesStorage();
        _updateTotalAssets();
        _takeFees($roles.feeReceiver, $roles.feeRegistry.protocolFeeReceiver());

        _settleDeposit(msg.sender);
        _settleRedeem(msg.sender);
        _getVaultStorage().state = State.Closed;

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), _getERC7540Storage().totalAssets);

        emit StateUpdated(State.Closed);
    }

    /// @dev Unusable when paused.
    /// @dev First _withdraw path: whenNotPaused via ERC20Pausable._update.
    /// @dev Second _withdraw path: whenNotPaused in ERC7540Upgradeable.
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public override(ERC4626Upgradeable, IERC4626) returns (uint256 shares) {
        VaultStorage storage $ = _getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            shares = _convertToShares(assets, Math.Rounding.Ceil);
            _withdraw(_msgSender(), receiver, controller, assets, shares);
        } else {
            return _withdraw(assets, receiver, controller);
        }
    }

    /// @dev Unusable when paused.
    /// @dev First _withdraw path: whenNotPaused via ERC20Pausable._update.
    /// @dev Second _withdraw path: whenNotPaused in ERC7540Upgradeable.
    /// @notice Claim assets from the vault. After a request is made and settled.
    /// @param shares The amount shares to convert into assets.
    /// @param receiver The receiver of the assets.
    /// @param controller The controller, who owns the redeem request.
    /// @return assets The corresponding assets.
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) public override(ERC4626Upgradeable, IERC4626) returns (uint256 assets) {
        VaultStorage storage $ = _getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            assets = _convertToAssets(shares, Math.Rounding.Floor);
            _withdraw(_msgSender(), receiver, controller, assets, shares);
        } else {
            return _redeem(shares, receiver, controller);
        }
    }

    /// @dev override ERC4626 synchronous withdraw; called only when vault is closed
    /// @param caller The address of the caller.
    /// @param receiver The address of the receiver of the assets.
    /// @param owner The address of the owner of the shares.
    /// @param assets The amount of assets to withdraw.
    /// @param shares The amount of shares to burn.
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner && !isOperator(owner, caller)) {
            _spendAllowance(owner, caller, shares);
        }

        _getERC7540Storage().totalAssets -= assets;

        _burn(owner, shares);

        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Halts core operations of the vault. Can only be called by the owner.
    /// @notice Core operations include deposit, redeem, withdraw, any type of request, settles deposit and redeem and
    /// newTotalAssets update.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Resumes core operations of the vault. Can only be called by the owner.
    function unpause() public onlyOwner {
        _unpause();
    }
}
