// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC7540} from "../ERC7540.sol";
import {ERC7540Lib} from "../libraries/ERC7540Lib.sol";
import {FeeLib} from "../libraries/FeeLib.sol";
import {RolesLib} from "../libraries/RolesLib.sol";
import {VaultLib} from "../libraries/VaultLib.sol";
import {FeeType} from "../primitives/Enums.sol";
import {VaultStorage} from "../primitives/VaultStorage.sol";

import {VaultInit} from "./VaultInit.sol";

import {FeeManager} from "../FeeManager.sol";
import {Roles} from "../Roles.sol";
import {Whitelistable} from "../Whitelistable.sol";
import {State} from "../primitives/Enums.sol";
import {
    CantDepositNativeToken,
    Closed,
    ERC7540InvalidOperator,
    NotClosing,
    NotOpen,
    NotWhitelisted,
    OnlyAsyncDepositAllowed,
    OnlySyncDepositAllowed,
    ValuationUpdateNotAllowed
} from "../primitives/Errors.sol";

import {FeeRegistry} from "../../protocol-v1/FeeRegistry.sol";
import {DepositSync, Referral, StateUpdated} from "../primitives/Events.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
/// @param entryRate The entry fee rate.
/// @param exitRate The exit fee rate.
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
    // added in v0.6.0
    uint16 entryRate;
    uint16 exitRate;
}

/// @custom:oz-upgrades-from src/v0.5.0/Vault.sol:Vault
contract Vault is ERC7540, Whitelistable, FeeManager {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    VaultInit immutable init;

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors

    constructor(
        bool disable
    ) {
        init = new VaultInit(disable);
    }

    /// @notice Initializes the vault.
    /// @param data The encoded initialization parameters of the vault.
    function initialize(
        bytes memory data,
        address feeRegistry,
        address wrappedNativeToken
    ) public virtual {
        // init.initialize(data, feeRegistry, wrappedNativeToken);
        bytes memory callData =
            abi.encodeWithSignature("initialize(bytes,address,address)", data, feeRegistry, wrappedNativeToken);

        // Perform delegate call to the init contract
        (bool success,) = address(init).delegatecall(callData);

        // Revert if the delegate call failed
        require(success, "Delegate call failed");
    }

    /////////////////////
    // ## MODIFIERS ## //
    /////////////////////

    /// @notice Reverts if the vault is not open.
    modifier onlyOpen() {
        VaultLib._onlyOpen();
        _;
    }

    /// @notice Reverts if the vault is not closing.
    modifier onlyClosing() {
        VaultLib._onlyClosing();
        _;
    }

    // @notice Reverts if totalAssets is expired.
    modifier onlySyncDeposit() {
        VaultLib._onlySyncDeposit();
        _;
    }

    // @notice Reverts if totalAssets is valid.
    modifier onlyAsyncDeposit() {
        VaultLib._onlyAsyncDeposit();
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
    ) public payable override onlyOperator(owner) whenNotPaused onlyAsyncDeposit returns (uint256 requestId) {
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
    ) public payable onlyOperator(owner) whenNotPaused onlyAsyncDeposit returns (uint256 requestId) {
        if (!isWhitelisted(owner)) revert NotWhitelisted();
        requestId = _requestDeposit(assets, controller, owner);

        emit Referral(referral, owner, requestId, assets);
    }

    /// @notice Deposit in a sychronous fashion into the vault.
    /// @param assets The assets to deposit.
    /// @param receiver The receiver of the shares.
    /// @return shares The resulting shares.
    function syncDeposit(
        uint256 assets,
        address receiver,
        address referral
    ) public payable onlySyncDeposit onlyOpen returns (uint256 shares) {
        ERC7540Storage storage $ = ERC7540Lib._getERC7540Storage();

        if (!isWhitelisted(msg.sender)) revert NotWhitelisted();

        if (msg.value != 0) {
            // if user sends eth and the underlying is wETH we will wrap it for him
            if (asset() == address($.wrappedNativeToken)) {
                assets = msg.value;
                // we do not send directly eth in case the safe is not payable
                $.pendingSilo.depositEth{value: assets}();
                IERC20(asset()).safeTransferFrom(address($.pendingSilo), safe(), assets);
            } else {
                revert CantDepositNativeToken();
            }
        } else {
            IERC20(asset()).safeTransferFrom(msg.sender, safe(), assets);
        }
        shares = _convertToShares(assets, Math.Rounding.Floor);
        // introduced in v0.6.0
        uint16 entryRate = FeeLib.feeRates().entryRate;
        uint256 entryFeeShares = FeeLib.computeFee(shares, entryRate);
        shares -= entryFeeShares;
        FeeLib.takeFees(entryFeeShares, FeeType.Entry, entryRate, 0);

        $.totalAssets += assets;
        _mint(receiver, shares);

        emit DepositSync(msg.sender, receiver, assets, shares);

        emit Referral(referral, msg.sender, 0, assets);
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
        if (!isWhitelisted(msg.sender)) revert NotWhitelisted();

        uint256 claimable = claimableDepositRequest(0, msg.sender);
        if (claimable > 0) _deposit(claimable, msg.sender, msg.sender);

        uint256 redeemId = _requestRedeem(sharesToRedeem, msg.sender, msg.sender);

        return uint40(redeemId);
    }

    /// @dev Unusable when paused.
    /// @dev First _withdraw path: whenNotPaused via ERC20Pausable._update.
    /// @dev Second _withdraw path: whenNotPaused in ERC7540.
    /// @return shares The number of shares withdrawn.
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256) {
        VaultStorage storage $ = VaultLib._getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            uint256 netShares = _convertToShares(assets, Math.Rounding.Ceil);
            uint16 exitRate = FeeLib.feeRates().exitRate;
            uint256 exitFeeShares = FeeLib.computeFeeReverse(netShares, exitRate);
            uint256 totalShares = netShares + exitFeeShares;
            FeeLib.takeFees(exitFeeShares, FeeType.Exit, exitRate, 0);
            _withdraw(msg.sender, receiver, controller, assets, totalShares); // sync
            return totalShares;
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
    ) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256) {
        VaultStorage storage $ = VaultLib._getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            uint16 exitRate = FeeLib.feeRates().exitRate;
            uint256 exitFeeShares = FeeLib.computeFee(shares, exitRate);
            uint256 assets = _convertToAssets(shares - exitFeeShares, Math.Rounding.Floor);
            FeeLib.takeFees(exitFeeShares, FeeType.Exit, exitRate, 0);
            _withdraw(msg.sender, receiver, controller, assets, shares); // sync
            return assets;
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

        ERC7540Lib._getERC7540Storage().totalAssets -= assets;

        _burn(owner, shares);

        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Claims all available shares for a list of controller addresses.
    /// @dev Iterates over each controller address, checks for claimable deposits, and deposits them on their behalf.
    /// @param controllers The list of controller addresses for which to claim shares.
    function claimSharesOnBehalf(
        address[] memory controllers
    ) external onlySafe {
        for (uint256 i = 0; i < controllers.length; i++) {
            uint256 claimable = claimableDepositRequest(0, controllers[i]);
            if (claimable > 0) {
                _deposit(claimable, controllers[i], controllers[i]);
            }
        }
    }

    /// @notice Claims all available assets for a list of controller addresses.
    /// @dev Iterates over each controller address, checks for claimable redeems, and redeems them on their behalf.
    /// @param controllers The list of controller addresses for which to claim assets.
    function claimAssetsOnBehalf(
        address[] memory controllers
    ) external onlySafe {
        for (uint256 i = 0; i < controllers.length; i++) {
            uint256 claimable = claimableRedeemRequest(0, controllers[i]);
            if (claimable > 0) {
                _redeem(claimable, controllers[i], controllers[i]);
            }
        }
    }

    ///////////////////////////////////////////////////////
    // ## VALUATION UPDATING AND SETTLEMENT FUNCTIONS ## //
    ///////////////////////////////////////////////////////

    function updateTotalAssetsLifespan(
        uint128 lifespan
    ) external onlySafe {
        ERC7540Lib.updateTotalAssetsLifespan(lifespan);
    }

    /// @notice Function to propose a new valuation for the vault.
    /// @notice It can only be called by the ValueManager.
    /// @param _newTotalAssets The new total assets of the vault.
    function updateNewTotalAssets(
        uint256 _newTotalAssets
    ) public onlyValuationManager {
        if (VaultLib._getVaultStorage().state == State.Closed) {
            revert Closed();
        }

        // if totalAssets is not expired yet it means syncDeposit are allowed
        // in this case we do not allow onlyValuationManager to propose a new nav
        // he must call unvalidateTotalAssets first.
        if (isTotalAssetsValid()) {
            revert ValuationUpdateNotAllowed();
        }
        ERC7540Lib.updateNewTotalAssets(_newTotalAssets);
    }

    /// @notice Settles deposit requests, integrates user funds into the vault strategy, and enables share claims.
    /// If possible, it also settles redeem requests.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    function settleDeposit(
        uint256 _newTotalAssets
    ) public override onlySafe onlyOpen {
        ERC7540Lib.updateTotalAssets(_newTotalAssets);
        uint40 contextId = ERC7540Lib._getERC7540Storage().depositSettleId;
        FeeLib.takeManagementAndPerformanceFees(contextId);
        ERC7540Lib.settleDeposit(msg.sender);
        ERC7540Lib.settleRedeem(msg.sender); // if it is possible to settleRedeem, we should do so
    }

    /// @notice Settles redeem requests, only callable by the safe.
    /// @dev Unusable when paused, protected by whenNotPaused in _updateTotalAssets.
    /// @dev After updating totalAssets, it takes fees, updates highWaterMark and finally settles redeem requests.
    /// @inheritdoc ERC7540
    function settleRedeem(
        uint256 _newTotalAssets
    ) public override onlySafe onlyOpen {
        ERC7540Lib.updateTotalAssets(_newTotalAssets);
        uint40 contextId = ERC7540Lib._getERC7540Storage().redeemSettleId;
        FeeLib.takeManagementAndPerformanceFees(contextId);
        ERC7540Lib.settleRedeem(msg.sender); // if it is possible to settleRedeem, we should do so
    }

    /////////////////////////////
    // ## CLOSING FUNCTIONS ## //
    /////////////////////////////

    /// @notice Initiates the closing of the vault. Can only be called by the owner.
    /// @dev we make sure that initiate closing will make an epoch changement if the variable newTotalAssets is
    /// "defined"
    /// @dev (!= type(uint256).max). This guarantee that no userShares will be locked in a pending state.
    function initiateClosing() external onlyOwner onlyOpen {
        VaultLib.initiateClosing();
    }

    /// @notice Closes the vault, only redemption and withdrawal are allowed after this. Can only be called by the safe.
    /// @dev Users can still requestDeposit but it can't be settled.
    function close(
        uint256 _newTotalAssets
    ) external onlySafe onlyClosing {
        VaultLib.close(_newTotalAssets);
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

    function expireTotalAssets() public onlySafe {
        ERC7540Lib._getERC7540Storage().totalAssetsExpiration = 0;
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
        if (shares == 0 && VaultLib._getVaultStorage().state == State.Closed) {
            // controller has no redeem claimable, we will use the synchronous flow
            return balanceOf(controller);
        }
        return shares;
    }

    /// @notice Returns the amount of assets a controller will get if he redeem.
    /// @param controller The controller.
    /// @dev This is the same philosophy as maxRedeem, except that we take care to convertToAssets the value before
    /// returning it
    /// @return assets the maximum amount of assets to withdraw
    function maxWithdraw(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256 assets) {
        if (paused()) return 0;
        uint256 shares = claimableRedeemRequest(0, controller);
        if (shares == 0 && VaultLib._getVaultStorage().state == State.Closed) {
            // controller has no redeem claimable, we will use the synchronous flow
            // exit fees will be taken when the user withdraws
            uint256 controllerShares = balanceOf(controller);
            uint16 exitRate = FeeLib.feeRates().exitRate;
            uint256 syncExitFeeShares = FeeLib.computeFee(controllerShares, exitRate);
            return convertToAssets(controllerShares - syncExitFeeShares);
        }
        uint40 lastRedeemId = ERC7540Lib._getERC7540Storage().lastRedeemRequestId[controller];
        // introduced in v0.6.0
        // we need to take into account the exit fee to compute the assets
        uint256 exitFeeShares = FeeLib.computeFee(shares, ERC7540Lib.getSettlementExitFeeRate(lastRedeemId));
        assets = convertToAssets(shares - exitFeeShares, lastRedeemId);

        return assets;
    }

    /// @notice Returns the maximun amount of assets a controller can use to claim shares.
    /// @param  controller address to check
    /// @dev    If the contract is paused no deposit/claims are possible.
    function maxDeposit(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        if (paused()) return 0;
        return claimableDepositRequest(0, controller);
    }

    /// @notice Returns the maximun amount of shares a controller can get by claiming a deposit request.
    /// @param controller The controller.
    /// @dev    If the contract is paused no deposit/claims are possible.
    /// @dev    We read the claimableDepositRequest of the controller then convert it to shares using the
    /// convertToShares of the related epochId.
    /// @return The maximum amount of shares to get.
    function maxMint(
        address controller
    ) public view override(IERC4626, ERC4626Upgradeable) returns (uint256) {
        if (paused()) return 0;
        uint40 lastDepositId = ERC7540Lib._getERC7540Storage().lastDepositRequestId[controller];
        uint256 claimable = claimableDepositRequest(lastDepositId, controller);
        uint256 shares = convertToShares(claimable, lastDepositId);
        // the maximun amount of shares a controller can claim is the normal claimable amount minus the entry fee
        shares -= FeeLib.computeFee(shares, ERC7540Lib.getSettlementEntryFeeRate(lastDepositId));
        return shares;
    }

    /// @notice Returns the amount of shares a controller can get by depositing assets in a synchronous fashion.
    /// @param assets The amount of assets to deposit.
    /// @return shares The amount of shares to get after fees.
    function previewSyncDeposit(
        uint256 assets
    ) public view returns (uint256 shares) {
        if (paused() || !isTotalAssetsValid()) return 0;
        shares = _convertToShares(assets, Math.Rounding.Floor);
        uint256 entryFeeShares = FeeLib.computeFee(shares, FeeLib.feeRates().entryRate);
        shares -= entryFeeShares;
        return shares;
    }

    function isTotalAssetsValid() public view returns (bool) {
        return VaultLib.isTotalAssetsValid();
    }

    function safe() public view override returns (address) {
        return RolesLib._getRolesStorage().safe;
    }

    function version() public pure returns (string memory) {
        return "v0.6.0";
    }
}
