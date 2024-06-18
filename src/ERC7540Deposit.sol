//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {ERC7540Upgradeable} from "./ERC7540.sol";

// struct ERC7540DepositStorage {
//     // mapping(uint256 epochId => EpochData epoch) epochs;
//     mapping(address user => uint256 epochId) lastDepositRequestId;
//     mapping(address user => uint256 epochId) lastRedeemRequestId;
// }

abstract contract ERC7540Deposit is IERC7540Deposit, ERC7540Upgradeable {
    // bytes32 private constant erc7540Storage =
    //     0x0db0cd9880e84ca0b573fff91a05faddfecad925c5f393111a47359314e28e00;
    // // keccak256(
    // //     abi.encode(uint256(keccak256("hopper.ERC7540.storage")) - 1)
    // // ) & ~bytes32(uint256(0xff));
    // function _getERC7540Storage()
    //     internal
    //     pure
    //     returns (ERC7540Storage storage $)
    // {
    //     // solhint-disable-next-line no-inline-assembly
    //     assembly {
    //         $.slot := erc7540Storage
    //     }
    // }
}
