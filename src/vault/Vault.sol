// SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {ERC7540Upgradeable, SettleData} from "./ERC7540.sol";

import {State} from "./Enums.sol";
import {NewNAVMissing, NotClosing, NotEnoughLiquidity, NotOpen, NotWhitelisted} from "./Errors.sol";
import {Referral, StateUpdated, TotalAssetsUpdated, UpdateTotalAssets} from "./Events.sol";

import {FeeManager} from "./FeeManager.sol";
import {RolesUpgradeable} from "./Roles.sol";
import {WhitelistableUpgradeable} from "./Whitelistable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// import {console} from "forge-std/console.sol";

using SafeERC20 for IERC20;

contract Vault is ERC7540Upgradeable, WhitelistableUpgradeable, FeeManager {
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
        uint256 rateUpdateCooldown;
        bool enableWhitelist;
        address[] whitelist;
    }

    /// @custom:storage-location erc7201:hopper.storage.vault
    struct VaultStorage {
        uint256 newTotalAssets;
        State state;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant vaultStorage = 0x0e6b3200a60a991c539f47dddaca04a18eb4bcf2b53906fb44751d827f001400;

    function _getVaultStorage() internal pure returns (VaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := vaultStorage
        }
    }

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
                feeRegistry: init.feeRegistry,
                navManager: init.navManager
            })
        );
        __Ownable_init(init.admin); // initial vault owner

        VaultStorage storage $ = _getVaultStorage();

        $.newTotalAssets = type(uint256).max;

        $.state = State.Open;
        emit StateUpdated(State.Open);

        if (init.enableWhitelist) {
            WhitelistableStorage storage $whitelistStorage = _getWhitelistableStorage();
            $whitelistStorage.isWhitelisted[init.feeReceiver] = true;
            $whitelistStorage.isWhitelisted[protocolFeeReceiver()] = true;
            $whitelistStorage.isWhitelisted[init.safe] = true;
            $whitelistStorage.isWhitelisted[init.whitelistManager] = true;
            $whitelistStorage.isWhitelisted[init.admin] = true;
            $whitelistStorage.isWhitelisted[pendingSilo()] = true;
            for (uint256 i = 0; i < init.whitelist.length; i++) {
                $whitelistStorage.isWhitelisted[init.whitelist[i]] = true;
            }
        }
    }

    modifier onlyOpen() {
        State _state = _getVaultStorage().state;
        if (_state != State.Open) revert NotOpen(_state);
        _;
    }

    modifier onlyClosing() {
        State _state = _getVaultStorage().state;
        if (_state != State.Closing) revert NotClosing(_state);
        _;
    }

    /// @dev should not be usable when contract is paused
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public payable override(ERC7540Upgradeable) returns (uint256 requestId) {
        return _requestDeposit(assets, controller, owner, address(0));
    }

    /// @dev should not be usable when contract is paused
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner,
        address referral
    ) public payable returns (uint256 requestId) {
        return _requestDeposit(assets, controller, owner, referral);
    }

    /// @notice Requests a deposit of assets, subject to whitelist validation.
    /// @param assets The amount of assets to deposit.
    /// @param controller The address of the controller involved in the deposit request.
    /// @param owner The address of the owner for whom the deposit is requested.
    /// @param referral The address who referred the deposit.
    /// @return The id of the deposit request.
    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner,
        address referral
    ) internal returns (uint256) {
        uint256 requestId = super.requestDeposit(assets, controller, owner);
        if (!isWhitelisted(owner)) revert NotWhitelisted();
        if (address(referral) != address(0)) {
            emit Referral(referral, owner, requestId, assets);
        }
        return requestId;
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

    /// @dev should not be usable when contract is paused
    function updateNewTotalAssets(uint256 _newTotalAssets) public onlyNAVManager whenNotPaused {
        VaultStorage storage $ = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

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

    /// @dev should not be usable when contract is paused
    function settleDeposit() public override onlySafe onlyOpen {
        _updateTotalAssets();
        _takeFees();
        _settleDeposit();
        _settleRedeem(); // if it is possible to settleRedeem, we should do so
    }

    function _updateTotalAssets() internal whenNotPaused {
        VaultStorage storage $vault = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint256 newTotalAssets = $vault.newTotalAssets;

        if (
            newTotalAssets == type(uint256).max // it means newTotalAssets has not been updated
        ) {
            revert NewNAVMissing();
        }

        $erc7540.totalAssets = newTotalAssets;
        $vault.newTotalAssets = type(uint256).max; // by setting it to max, we ensure that it is not called again
        emit TotalAssetsUpdated(newTotalAssets);
    }

    function _takeFees() internal {
        if (lastFeeTime() == block.timestamp) return;

        (uint256 managerShares, uint256 protocolShares) = _calculateFees();

        if (managerShares > 0) {
            _mint(feeReceiver(), managerShares);
            if (
                protocolShares > 0 // they can't be protocolShares without managerShares
            ) {
                _mint(protocolFeeReceiver(), protocolShares);
            }
        }

        uint256 _pricePerShare = _convertToAssets(10 ** decimals(), Math.Rounding.Floor);
        _setHighWaterMark(_pricePerShare); // when fees are taken done being taken, we update highWaterMark

        _getFeeManagerStorage().lastFeeTime = block.timestamp;
    }

    function _settleDeposit() internal {
        address _asset = asset();
        address _pendingSilo = pendingSilo();

        uint256 pendingAssets = IERC20(_asset).balanceOf(_pendingSilo);
        if (pendingAssets == 0) return;

        uint256 shares = _convertToShares(pendingAssets, Math.Rounding.Floor);

        // Then save the deposit parameters
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint256 _totalAssets = totalAssets();
        uint40 depositSettleId = $erc7540.depositSettleId;

        SettleData storage settleData = $erc7540.settles[depositSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = totalSupply();
        _mint(address(this), shares);

        _totalAssets += pendingAssets;

        $erc7540.totalAssets = _totalAssets;

        $erc7540.depositSettleId = depositSettleId + 2;
        $erc7540.lastDepositEpochIdSettled = $erc7540.depositEpochId - 2;

        IERC20(_asset).safeTransferFrom(_pendingSilo, safe(), pendingAssets);

        // change this event maybe
        emit Deposit(_msgSender(), address(this), pendingAssets, shares);
    }

    /// @dev should not be usable when contract is paused
    function settleRedeem() public override onlySafe onlyOpen {
        _updateTotalAssets();
        _takeFees();
        _settleRedeem();
    }

    function _settleRedeem() internal {
        address _safe = safe();
        address _asset = asset();
        address _pendingSilo = pendingSilo();

        uint256 pendingShares = balanceOf(_pendingSilo);
        uint256 assetsToWithdraw = _convertToAssets(pendingShares, Math.Rounding.Floor);

        uint256 assetsInTheSafe = IERC20(_asset).balanceOf(_safe);
        if (assetsToWithdraw == 0 || assetsToWithdraw > assetsInTheSafe) return;

        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        uint256 _totalAssets = totalAssets();
        uint40 redeemSettleId = $erc7540.redeemSettleId;

        SettleData storage settleData = $erc7540.settles[redeemSettleId];

        settleData.totalAssets = _totalAssets;
        settleData.totalSupply = totalSupply();

        _burn(_pendingSilo, pendingShares);

        _totalAssets -= assetsToWithdraw;
        $erc7540.totalAssets = _totalAssets;

        $erc7540.redeemSettleId = redeemSettleId + 2;
        $erc7540.lastRedeemEpochIdSettled = $erc7540.redeemEpochId - 2;

        IERC20(_asset).safeTransferFrom(_safe, address(this), assetsToWithdraw);

        // change this event maybe
        emit Withdraw(_msgSender(), address(this), _pendingSilo, assetsToWithdraw, pendingShares);
    }

    /////////////////
    // MVP UPGRADE //
    /////////////////

    // Pending states
    function pendingDeposit() public view returns (uint256) {
        return IERC20(asset()).balanceOf(pendingSilo());
    }

    function pendingRedeem() public view returns (uint256) {
        return balanceOf(pendingSilo());
    }

    function initiateClosing() external onlyOwner onlyOpen {
        VaultStorage storage $ = _getVaultStorage();
        $.state = State.Closing;
        emit StateUpdated(State.Closing);
    }

    function close() external onlySafe onlyClosing {
        VaultStorage storage $ = _getVaultStorage();
        uint256 _totalAssets = _getERC7540Storage().totalAssets;

        _updateTotalAssets();
        _takeFees();
        _settleDeposit();
        _settleRedeem();

        address _safe = safe();
        uint256 safeBalance = IERC20(asset()).balanceOf(_safe);

        if (_totalAssets > safeBalance) {
            revert NotEnoughLiquidity(safeBalance, _totalAssets);
        }

        $.state = State.Closed;

        IERC20(asset()).safeTransferFrom(_safe, address(this), safeBalance);
        emit StateUpdated(State.Closed);
    }

    /// @dev should not be usable when contract is paused
    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    ) public override whenNotPaused returns (uint256 shares) {
        VaultStorage storage $ = _getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            shares = _convertToShares(assets, Math.Rounding.Ceil);
            _withdraw(_msgSender(), receiver, controller, assets, shares);
        } else {
            return _withdraw(assets, receiver, controller);
        }
    }

    /// @dev should not be usable when contract is paused
    function redeem(uint256 shares, address receiver, address controller) public override returns (uint256 assets) {
        VaultStorage storage $ = _getVaultStorage();

        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            assets = _convertToAssets(shares, Math.Rounding.Floor);
            _withdraw(_msgSender(), receiver, controller, assets, shares);
        } else {
            return _redeem(shares, receiver, controller);
        }
    }

    /// @dev override ERC4626 synchronous withdraw; called when vault is closed
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

    function state() external view returns (State) {
        return _getVaultStorage().state;
    }

    /// @notice Halts core operations of the vault. Can only be called by the owner.
    /// @notice Core operations include deposit, redeem, withdraw, any type of request, settles deposit and redeem and
    /// totalAssets update.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Resumes core operations of the vault. Can only be called by the owner.
    function unpause() public onlyOwner {
        _unpause();
    }
}
