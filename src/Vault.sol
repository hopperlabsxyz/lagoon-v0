// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

// import "forge-std/Test.sol";
import {ERC7540Upgradeable, EpochData} from "./ERC7540.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {AccessControlUpgradeable, IAccessControl} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Whitelistable, NotWhitelisted, WHITELISTED} from "./Whitelistable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeManager} from "./FeeManager.sol";
import {WhitelistableStorage} from "./Whitelistable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Roles} from "./Roles.sol";
import {console} from "forge-std/console.sol";

using Math for uint256;
using SafeERC20 for IERC20;

event Referral(address indexed referral, address indexed owner, uint256 indexed requestId, uint256 assets);

uint256 constant BPS_DIVIDER = 10_000;

bytes32 constant ASSET_MANAGER_ROLE = keccak256("ASSET_MANAGER");
bytes32 constant VALORIZATION_ROLE = keccak256("VALORIZATION_MANAGER");
bytes32 constant HOPPER_ROLE = keccak256("HOPPER");
bytes32 constant FEE_RECEIVER = keccak256("FEE_RECEIVER");

error CooldownNotOver();
error NotOpen();
error NotClosing();
error NotClosed();

enum State {
    Open,
    Closing,
    Closed
}

/// @custom:oz-upgrades-from VaultV2
contract Vault is ERC7540Upgradeable, Whitelistable, FeeManager {
    using Math for uint256;
    
    struct InitStruct {
        IERC20 underlying;
        string name;
        string symbol;
        address safe;
        address whitelistManager;
        address valorization;
        address admin;
        address feeReceiver;
        address feeRegistry;
        address wrappedNativeToken;
        uint256 managementRate;
        uint256 performanceRate;
        uint256 cooldown;
        bool enableWhitelist;
        address[] whitelist;
    }

    /// @custom:storage-location erc7201:hopper.storage.vault
    struct VaultStorage {
        uint256 newTotalAssets;
        uint256 newTotalAssetsTimestamp;
        uint256 newTotalAssetsCooldown;
        State state;
    }

    // keccak256(abi.encode(uint256(keccak256("hopper.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant vaultStorage =
        0x0e6b3200a60a991c539f47dddaca04a18eb4bcf2b53906fb44751d827f001400;

    function _getVaultStorage() internal pure returns (VaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := vaultStorage
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor() {
        // if (disable) _disableInitializers();
    }

    function initialize(InitStruct memory init) public virtual initializer {
        __ERC4626_init(init.underlying);
        __ERC20_init(init.name, init.symbol);
        __ERC20Pausable_init();
        __FeeManager_init(
            init.feeRegistry,
            init.managementRate,
            init.performanceRate,
            decimals()
        );
        __ERC7540_init(init.underlying, init.wrappedNativeToken);
        __Whitelistable_init(init.enableWhitelist);
        __Roles_init(Roles.RolesStorage({
            whitelistManager: init.whitelistManager,
            feeReceiver: init.feeReceiver,
            safe: init.safe,
            feeRegistry: init.feeRegistry,
            valorizationManager: init.valorization
        }));
        __Ownable_init(init.admin); // initial vault owner

        VaultStorage storage $ = _getVaultStorage();
        $.newTotalAssetsCooldown = init.cooldown;

        $.state = State.Open;

        if (init.enableWhitelist) {
            WhitelistableStorage
                storage $whitelistStorage = _getWhitelistableStorage();
            $whitelistStorage.isWhitelisted[init.feeReceiver] = true;
            $whitelistStorage.isWhitelisted[protocolFeeReceiver()] = true;
            $whitelistStorage.isWhitelisted[init.safe] = true;
            $whitelistStorage.isWhitelisted[init.whitelistManager] = true;
            $whitelistStorage.isWhitelisted[init.valorization] = true; // todo remove ??
            $whitelistStorage.isWhitelisted[init.admin] = true;
            $whitelistStorage.isWhitelisted[pendingSilo()] = true;
            for (uint256 i = 0; i < init.whitelist.length; i++) {
                $whitelistStorage.isWhitelisted[init.whitelist[i]] = true;
            }
        }
    }

    modifier onlyOpen() {
        VaultStorage storage $ = _getVaultStorage();

        require($.state == State.Open, "Not open");
        _;
    }

    modifier onlyClosing() {
        VaultStorage storage $ = _getVaultStorage();

        require($.state == State.Closing, "Not Closing");
        _;
    }

    // modifier onlyClosed() {
    //     VaultStorage storage $ = _getVaultStorage();

    //     require($.state == State.Closed, "Not Closed");
    //     _;
    // }

    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    ) public payable override(ERC7540Upgradeable) returns (uint256 requestId) {
        return _requestDeposit(assets, controller, owner, abi.encode(""));
    }

    function requestDeposit(
        uint256 assets,
        address controller,
        address owner,
        bytes calldata data
    ) public payable returns (uint256 requestId) {
        return _requestDeposit(assets, controller, owner, data);
    }

    // @notice Requests a deposit of assets, subject to whitelist validation.
    // @param assets The amount of assets to deposit.
    // @param controller The address of the controller involved in the deposit request.
    // @param owner The address of the owner for whom the deposit is requested.
    // @param data ABI-encoded data expected to contain a Merkle proof (bytes32[]) and a referral address (address).
    // @return The id of the deposit request.
    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner,
        bytes memory data
    ) internal  returns (uint256) {
        (bytes32[] memory proof, address referral) = abi.decode(data, (bytes32[], address));
        // todo: convert this to require(isWhitelisted(owner, proof), NotWhitelisted(owner));
        if (isWhitelisted(owner, proof) == false) {
          revert NotWhitelisted(owner);
        }
        uint256 requestId = super.requestDeposit(assets, controller, owner);
        if (address(referral) != address(0)) {
          emit Referral(referral, owner, requestId, assets);
        }
        return requestId;
    }

    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    ) public override(ERC7540Upgradeable) returns (uint256 requestId) {
        return _requestRedeem(shares, controller, owner, abi.encode(""));
    }

    function requestRedeem(
        uint256 shares,
        address controller,
        address owner,
        bytes calldata data
    ) external returns (uint256 requestId) {
        return _requestRedeem(shares, controller, owner, data);
    }

    // @notice Requests the redemption of tokens, subject to whitelist validation.
    // @param shares The number of tokens to redeem.
    // @param controller The address of the controller involved in the redemption request.
    // @param owner The address of the token owner requesting redemption.
    // @param data ABI-encoded Merkle proof (bytes32[]) used to validate the controller's whitelist status.
    // @return The id of the redeem request.
    function _requestRedeem(
        uint256 shares,
        address controller,
        address owner,
        bytes memory data
    ) internal onlyOpen returns (uint256) {
        bytes32[] memory proof = abi.decode(data, (bytes32[]));
        // todo: convert this to require(isWhitelisted(owner, proof), NotWhitelisted(owner));
        if (isWhitelisted(owner, proof) == false) {
          revert NotWhitelisted(owner);
        }
        return super.requestRedeem(shares, controller, owner);
    }

    function updateTotalAssets(
        uint256 _newTotalAssets
    ) public onlyValorizationManager {
        VaultStorage storage $ = _getVaultStorage();
        $.newTotalAssets = _newTotalAssets;
        $.newTotalAssetsTimestamp = block.timestamp;
    }

    function settleDeposit() public override onlySafe onlyOpen {
        _updateTotalAssets();
        _takeFees();
        _settleDeposit();
        _settleRedeem(); // if it is possible to settleRedeem, we should do so
    }

    function _updateTotalAssets() internal {
        VaultStorage storage $vault = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        if (
            $vault.newTotalAssetsTimestamp + $vault.newTotalAssetsCooldown >
            block.timestamp
        ) revert CooldownNotOver();

        $erc7540.totalAssets = $vault.newTotalAssets;
        $vault.newTotalAssetsTimestamp = type(uint256).max; // we do not allow to use 2 time the same newTotalAssets in a row
    }

    function _takeFees() internal {
        if (lastFeeTime() == block.timestamp) return;


        (uint256 managerShares, uint256 protocolShares) = _calculateFees();

        if (managerShares > 0) {
            _mint(feeReceiver(), managerShares);
             if (protocolShares > 0) // they can't be protocolShares without managerShares
                _mint(protocolFeeReceiver(), protocolShares); 
        }
       
        uint256 _pricePerShare = _convertToAssets(
            10 ** decimals(),
            Math.Rounding.Floor
        );
        _setHighWaterMark(_pricePerShare); // when fees are taken done being taken, we update highWaterMark

        FeeManagerStorage storage $feeManagerStorage = _getFeeManagerStorage();
        $feeManagerStorage.lastFeeTime = block.timestamp;
    }

    function _settleDeposit() internal {
        uint256 pendingAssets = IERC20(asset()).balanceOf(pendingSilo());
        if (pendingAssets == 0) return;

        // Then save the deposit parameters
        ERC7540Storage storage $erc7540 = _getERC7540Storage();
        uint256 _totalAssets = totalAssets();
        uint256 depositId = $erc7540.depositId;
        EpochData storage epoch = $erc7540.epochs[depositId];
        epoch.totalAssets = _totalAssets;
        epoch.totalSupply = totalSupply();


        uint256 shares = _convertToShares(pendingAssets, Math.Rounding.Floor);
        _mint(address(this), shares);
        _totalAssets += pendingAssets;
        $erc7540.totalAssets = _totalAssets;


        address _safe = safe();
        IERC20(asset()).safeTransferFrom(
            pendingSilo(),
            _safe,
            pendingAssets
        );
        $erc7540.depositId += 2;
        // todo emit event
    }

    function settleRedeem() public override onlySafe onlyOpen {
        _updateTotalAssets();
        _takeFees();
        _settleRedeem();
    }

    function _settleRedeem() internal {
        uint256 pendingShares = balanceOf(pendingSilo());
        uint256 assetsToWithdraw = _convertToAssets(
            pendingShares,
            Math.Rounding.Floor
        );
        address _safe = safe();
        uint256 assetsInTheSafe = IERC20(asset()).balanceOf(_safe);
        uint256 approvedBySafe = IERC20(asset()).allowance(
            _safe,
            address(this)
        );
        if (
            assetsToWithdraw == 0 ||
            assetsToWithdraw > assetsInTheSafe ||
            assetsToWithdraw > approvedBySafe
        ) return;

        // first we save epochs data
        ERC7540Storage storage $erc7540 = _getERC7540Storage();
        uint256 redeemId = $erc7540.redeemId;
        EpochData storage epoch = $erc7540.epochs[redeemId];
        uint256 _totalAssets = totalAssets();
        epoch.totalAssets = _totalAssets;
        epoch.totalSupply = totalSupply();

        // then we proceed to redeem the shares
        _burn(pendingSilo(), pendingShares);
        $erc7540.totalAssets = _totalAssets - assetsToWithdraw;


        IERC20(asset()).safeTransferFrom(
            _safe,
            address(this),
            assetsToWithdraw
        );
        $erc7540.redeemId += 2;
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

    // Sensible variables countdown update
    function newTotalAssetsCountdown() public view returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        if ($.newTotalAssetsTimestamp == type(uint256).max) {
            return 0;
        }
        if (
            $.newTotalAssetsTimestamp + $.newTotalAssetsCooldown >
            block.timestamp
        ) {
            return
                $.newTotalAssetsTimestamp +
                $.newTotalAssetsCooldown -
                block.timestamp;
        }
        return 0;
    }

    function updateNewTotalAssetsCountdown( //todo delete for prod
        uint256 _newTotalAssetsCooldown
    ) public onlyOwner {
        VaultStorage storage $ = _getVaultStorage();
        $.newTotalAssetsCooldown = _newTotalAssetsCooldown;
    }

    function initiateClosing() external onlyOwner {
        VaultStorage storage $ = _getVaultStorage();
        require($.state == State.Open, "Vault is not Open");
        $.state = State.Closing;
    }

    function close() external onlySafe onlyClosing {
        VaultStorage storage $ = _getVaultStorage();
        ERC7540Storage storage $erc7540 = _getERC7540Storage();

        _updateTotalAssets();
        _takeFees();
        _settleDeposit();
        _settleRedeem();

        address _safe = safe();
        uint256 safeBalance =  IERC20(asset()).balanceOf(_safe);
        require($erc7540.totalAssets <= safeBalance, "not enough liquidity to unwind");
        IERC20(asset()).safeTransferFrom(_safe, address(this), safeBalance);

        $.state = State.Closed;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    )
        public
        override
        onlyOperator(controller)
        returns (uint256)
    {
      VaultStorage storage $ = _getVaultStorage();
      if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0)
          return _exitWithdraw(assets, receiver, controller);
      return _withdraw(assets, receiver, controller);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address controller
    )
        public
        override
        onlyOperator(controller)
        returns (uint256)
    {
        VaultStorage storage $ = _getVaultStorage();

        // console.log("claimableRedeemRequest ", claimableRedeemRequest(0, controller));
        // console.log("controller             ", controller);
        if ($.state == State.Closed && claimableRedeemRequest(0, controller) == 0) {
            // console.log('IN');
            return _exitRedeem(shares, receiver, controller);

        }
        return _redeem(shares, receiver, controller);
    }
    
    function _exitWithdraw(
        uint256 assets,
        address receiver,
        address controller
    ) internal returns (uint256 shares) {
      shares = convertToShares(assets); 
      _burn(controller, shares);

      IERC20(asset()).safeTransfer(receiver, assets);

      emit Withdraw(_msgSender(), receiver, controller, assets, shares);
    }

    function _exitRedeem(
        uint256 shares,
        address receiver,
        address controller
    ) internal returns (uint256 assets) {
        assets = convertToAssets(shares);

        _burn(controller, shares);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(_msgSender(), receiver, controller, assets, shares);
    } 

    function state() external view returns(State) {
        return _getVaultStorage().state;
    }
}
