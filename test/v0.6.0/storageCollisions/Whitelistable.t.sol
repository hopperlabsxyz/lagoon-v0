// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.26;

// import "../VaultHelper.sol";
// import "forge-std/Test.sol";

// import {BaseTest} from "../Base.sol";
// import {TransparentUpgradeableProxy} from
// "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol"; import {IERC20} from
// "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// contract WhitelistableStorageV0_5_0 {
//     mapping(address => bool) public isWhitelisted;
//     bool public isActivated;

//     function initialize(
//         bool _isActivated
//     ) public {
//         isActivated = _isActivated;
//     }
// }

// contract WhitelistableStorageV0_6_0 {
//     mapping(address => bool) public isWhitelisted;
//     WhitelistState public whitelistState;
//     mapping(address => bool) public isBlacklisted;
// }

// contract TestWhitelistStorageCollisions is BaseTest {
//     WhitelistableStorageV0_5_0 whitelistableStorageV0_5_0;
//     WhitelistableStorageV0_6_0 whitelistableStorageV0_6_0;
//     TransparentUpgradeableProxy proxy;

//     function setUp() public {
//         whitelistableStorageV0_5_0 = new WhitelistableStorageV0_5_0();
//         proxy = new TransparentUpgradeableProxy(address(whitelistableStorageV0_5_0), address(this), "");
//     }

//     function test_storageLayout_ShouldBeTheSame() public {}
// }
