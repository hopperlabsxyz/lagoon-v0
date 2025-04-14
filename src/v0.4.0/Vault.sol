// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ERC7540} from "./ERC7540.sol";
import {FeeManager} from "./FeeManager.sol";
import {Roles} from "./Roles.sol";
import {Whitelistable} from "./Whitelistable.sol";
import {State} from "./primitives/Enums.sol";
import {Closed, ERC7540InvalidOperator, NotClosing, NotOpen, NotWhitelisted} from "./primitives/Errors.sol";

import {Referral, StateUpdated} from "./primitives/Events.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FeeRegistry} from "@src/protocol/FeeRegistry.sol";

using SafeERC20 for IERC20;

/// @custom:storage-definition erc7201:hopper.storage.vault
/// @param underlying The address of the underlying asset.
/// @param name The name of the vault and by extension the ERC20 token.
/// @param symbol The symbol of the vault and by extension the ERC20 token.
/// @param safe The address of the safe smart contract.
/// @param whitelistManager The address of the whitelist manager.
/// @param valuationManager The address of the valuation manager.
/// @param admin The address of the owner of the vault.
/// @param feeReceiver The address of the fee receiver.
/// @param feeRegistry The address of the fee registry.
/// @param wrappedNativeToken The address of the wrapped native token.
/// @param managementRate The management fee rate.
/// @param performanceRate The performance fee rate.
/// @param rateUpdateCooldown The cooldown period for updating the fee rates.
/// @param enableWhitelist A boolean indicating whether the whitelist is enabled.
struct InitStruct {
    IERC20 underlying;
    string name;
    string symbol;
    address safe;
    address whitelistManager;
    address valuationManager;
    address admin;
    address feeReceiver;
    uint16 managementRate;
    uint16 performanceRate;
    bool enableWhitelist;
    uint256 rateUpdateCooldown;
}

/// @custom:oz-upgrades-from src/v0.3.0/Vault.sol:Vault
contract Vault is ERC7540, Whitelistable, FeeManager {
    /// @custom:storage-location erc7201:hopper.storage.vault
    /// @param newTotalAssets The new total assets of the vault. It is used to update the totalAssets variable.
    /// @param state The state of the vault. It can be Open, Closing, or Closed.
    struct VaultStorage {
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(
        bool disable
    ) {
        if (disable) _disableInitializers();
    }

    /// @notice Initializes the vault.
    /// @param data The encoded initialization parameters of the vault.
    function initialize(
        bytes memory data,
        address feeRegistry,
        address wrappedNativeToken
    ) public virtual initializer {
        InitStruct memory init = abi.decode(data, (InitStruct));
        __Ownable_init(init.admin); // initial vault owner
        __Roles_init(
            Roles.RolesStorage({
                whitelistManager: init.whitelistManager,
                feeReceiver: init.feeReceiver,
                safe: init.safe,
                feeRegistry: FeeRegistry(feeRegistry),
                valuationManager: init.valuationManager
            })
        );
        __ERC20_init(init.name, init.symbol);
        __ERC20Pausable_init();
        __ERC4626_init(init.underlying);
        __ERC7540_init(init.underlying, wrappedNativeToken);
        __Whitelistable_init(init.enableWhitelist, FeeRegistry(feeRegistry).protocolFeeReceiver());
        __FeeManager_init(
            feeRegistry,
            init.managementRate,
            init.performanceRate,
            IERC20Metadata(address(init.underlying)).decimals(),
            init.rateUpdateCooldown
        );

        emit StateUpdated(State.Open);
    }

    /////////////////////
    // ## MODIFIERS ## //
    /////////////////////

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

    /////////////////////////////////////////////
    // ## DEPOSIT AND REDEEM FLOW FUNCTIONS ## //
    /////////////////////////////////////////////

    /// @param assets The amount of assets to deposit.
    /// @param controller The address of the controller involved in the deposit request.
    /// @param owner The address of the owner for whom the deposit is requested.
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public payable override onlyOperator(owner) whenNotPaused returns (uint256 requestId) {
        if (!isWhitelisted(owner)) revert NotWhitelisted();
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
    ) public payable onlyOperator(owner) whenNotPaused returns (uint256 requestId) {
        if (!isWhitelisted(owner)) revert NotWhitelisted();
        requestId = _requestDeposit(assets, controller, owner);
        emit Referral(referral, owner, requestId, assets);
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
    ) public onlyOpen whenNotPaused returns (uint256 requestId) {
        if (!isWhitelisted(owner)) revert NotWhitelisted();
        return _requestRedeem(shares, controller, owner);
    }

    /// @notice Function to bundle a claim of shares and a request redeem. It can be convenient for UX.
    /// @dev if claimable == 0, it has the same behavior as requestRedeem function.
    /// @dev if claimable > 0, user shares follow this path: vault --> user ; user --> pendingSilo
    function claimSharesAndRequestRedeem(
        uint256 sharesToRedeem
    ) public onlyOpen whenNotPaused returns (uint40 requestId) {
        uint256 claimable = claimableDepositRequest(0, msg.sender);
        if (claimable > 0) _deposit(claimable, msg.sender, msg.sender);

        uint256 redeemId = _requestRedeem(sharesToRedeem, msg.sender, msg.sender);

        return uint40(redeemId);
    }

    /// @dev Unusable when paused.
    /// @dev First _withdraw path: whenNotPaused via ERC20Pausable._update.
    /// @dev Second _withdraw path: whenNotPaused in ERC7540.
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256 shares) {
        VaultStorage storage $ = _getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            shares = _convertToShares(assets, Math.Rounding.Ceil);
            _withdraw(msg.sender, receiver, controller, assets, shares); // sync
        } else {
            if (controller != msg.sender && !isOperator(controller, msg.sender)) {
                revert ERC7540InvalidOperator();
            }
            return _withdraw(assets, receiver, controller); // async
        }
    }

    /// @dev Unusable when paused.
    /// @dev First _withdraw path: whenNotPaused via ERC20Pausable._update.
    /// @dev Second _withdraw path: whenNotPaused in ERC7540.
    /// @notice Claim assets from the vault. After a request is made and settled.
    /// @param shares The amount shares to convert into assets.
    /// @param receiver The receiver of the assets.
    /// @param controller The controller, who owns the redeem request.
    /// @return assets The corresponding assets.
    function redeem(
        uint256 shares,
        address receiver,
        address controller
    ) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256 assets) {
        VaultStorage storage $ = _getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            assets = _convertToAssets(shares, Math.Rounding.Floor);
            _withdraw(msg.sender, receiver, controller, assets, shares);
        } else {
            if (controller != msg.sender && !isOperator(controller, msg.sender)) {
                revert ERC7540InvalidOperator();
            }
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

    /// @notice Claims all available shares for a list of controller addresses.
    /// @dev Iterates over each controller address, checks for claimable deposits, and deposits them on their behalf.
    /// @param controllers The list of controller addresses for which to claim shares.
    function claimSharesOnBehalf(address[] memory controllers) external onlySafe {
        for (uint256 i = 0; i < controllers.length; i++) {
    	    uint256 claimable = claimableDepositRequest(0, controllers[i]);
    	    if (claimable > 0)
    	        _deposit(claimable, controllers[i], controllers[i]);
        }
    }

    ///////////////////////////////////////////////////////
    // ## VALUATION UPDATING AND SETTLEMENT FUNCTIONS ## //
    ///////////////////////////////////////////////////////

    /// @notice Function to propose a new valuation for the vault.
    /// @notice It can only be called by the ValueManager.
    /// @param _newTotalAssets The new total assets of the vault.
    function updateNewTotalAssets(
        uint256 _newTotalAssets
    ) public onlyValuationManager {
        if (_getVaultStorage().state == State.Closed) revert Closed();
        _updateNewTotalAssets(_newTotalAssets);
    }

    /// @notice Settles deposit requests, integrates user funds into the vault strategy, and enables share claims.
    /// If possible, it also settles redeem requests.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    function settleDeposit(
        uint256 _newTotalAssets
    ) public override onlySafe onlyOpen {
        RolesStorage storage $roles = _getRolesStorage();

        _updateTotalAssets(_newTotalAssets);
        _takeFees($roles.feeReceiver, $roles.feeRegistry.protocolFeeReceiver());
        _settleDeposit(msg.sender);
        _settleRedeem(msg.sender); // if it is possible to settleRedeem, we should do so
    }

    /// @notice Settles redeem requests, only callable by the safe.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    /// @dev After updating totalAssets, it takes fees, updates highWaterMark and finally settles redeem requests.
    /// @inheritdoc ERC7540
    function settleRedeem(
        uint256 _newTotalAssets
    ) public override onlySafe onlyOpen {
        RolesStorage storage $roles = _getRolesStorage();

        _updateTotalAssets(_newTotalAssets);
        _takeFees($roles.feeReceiver, $roles.feeRegistry.protocolFeeReceiver());
        _settleRedeem(msg.sender);
    }

    /////////////////////////////
    // ## CLOSING FUNCTIONS ## //
    /////////////////////////////

    /// @notice Initiates the closing of the vault. Can only be called by the owner.
    /// @dev we make sure that initiate closing will make an epoch changement if the variable newTotalAssets is
    /// "defined"
    /// @dev (!= type(uint256).max). This guarantee that no userShares will be locked in a pending state.
    function initiateClosing() external onlyOwner onlyOpen {
        ERC7540Storage storage $ = _getERC7540Storage();
        if ($.newTotalAssets != type(uint256).max) {
            _updateNewTotalAssets($.newTotalAssets);
        }
        _getVaultStorage().state = State.Closing;
        emit StateUpdated(State.Closing);
    }

    /// @notice Closes the vault, only redemption and withdrawal are allowed after this. Can only be called by the safe.
    /// @dev Users can still requestDeposit but it can't be settled.
    function close(
        uint256 _newTotalAssets
    ) external onlySafe onlyClosing {
        RolesStorage storage $roles = _getRolesStorage();
        _updateTotalAssets(_newTotalAssets);
        _takeFees($roles.feeReceiver, $roles.feeRegistry.protocolFeeReceiver());

        _settleDeposit(msg.sender);
        _settleRedeem(msg.sender);
        _getVaultStorage().state = State.Closed;

        // Transfer will fail if there are not enough assets inside the safe, making sure that redeem requests are
        // fulfilled
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), _getERC7540Storage().totalAssets);

        emit StateUpdated(State.Closed);
    }

    /////////////////////////////////
    // ## PAUSABILITY FUNCTIONS ## //
    /////////////////////////////////

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

    // MAX FUNCTIONS OVERRIDE //

    /// @notice Returns the maximum redeemable shares for a controller.
    /// @param controller The controller.
    /// @return shares The maximum redeemable shares.
    /// @dev When the vault is closed, users may claim there assets (erc7540.redeem style) or redeem there assets in a
    /// sync manner.
    /// this is why when they have nothing to claim and the vault is closed, we return their shares balance
    function maxRedeem(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        if (paused()) return 0;
        uint256 shares = claimableRedeemRequest(0, controller);
        if (shares == 0 && _getVaultStorage().state == State.Closed) {
            // controller has no redeem claimable, we will use the synchronous flow
            return balanceOf(controller);
        }
        return shares;
    }

    /// @notice Returns the amount of assets a controller will get if he redeem.
    /// @param controller The controller.
    /// @return The maximum amount of assets to get.
    /// @dev This is the same philosophy as maxRedeem, except that we take care to convertToAssets the value before
    /// returning it
    function maxWithdraw(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        if (paused()) return 0;

        uint256 shares = claimableRedeemRequest(0, controller);
        if (shares == 0 && _getVaultStorage().state == State.Closed) {
            // controller has no redeem claimable, we will use the synchronous flow
            return convertToAssets(balanceOf(controller));
        }
        uint256 lastRedeemId = _getERC7540Storage().lastRedeemRequestId[controller];
        return convertToAssets(shares, lastRedeemId);
    }

    /// @notice Returns the amount of assets a controller will get if he redeem.
    /// @param  controller address to check
    /// @dev    If the contract is paused no deposit/claims are possible.
    function maxDeposit(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        if (paused()) return 0;
        return claimableDepositRequest(0, controller);
    }

    /// @notice Returns the amount of sharres a controller will get if he calls Deposit.
    /// @param controller The controller.
    /// @dev    If the contract is paused no deposit/claims are possible.
    /// @dev    We read the claimableDepositRequest of the controller then convert it to shares using the
    /// convertToShares
    /// of the related epochId
    /// @return The maximum amount of shares to get.
    function maxMint(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        if (paused()) return 0;
        uint256 lastDepositId = _getERC7540Storage().lastDepositRequestId[controller];
        uint256 claimable = claimableDepositRequest(lastDepositId, controller);
        return convertToShares(claimable, lastDepositId);
    }

    function version() public pure returns (string memory) {
        return "v0.4.0";
    }
}
