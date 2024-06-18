//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import {IERC7540} from "./interfaces/IERC7540.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

struct ERC7540Storage {
    mapping(address controller => mapping(address operator => bool)) isOperator;
}

contract ERC7540Upgradeable is IERC7540, ERC4626Upgradeable {
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant erc7540Storage =
        0x0db0cd9880e84ca0b573fff91a05faddfecad925c5f393111a47359314e28e00;

    // keccak256(
    //     abi.encode(uint256(keccak256("hopper.ERC7540.storage")) - 1)
    // ) & ~bytes32(uint256(0xff));

    function _getERC7540Storage()
        internal
        pure
        returns (ERC7540Storage storage $)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := erc7540Storage
        }
    }

    // ## EIP7540 ##
    function isOperator(
        address controller,
        address operator
    ) public view returns (bool) {
        ERC7540Storage storage $ = _getERC7540Storage();
        return $.isOperator[controller][operator];
    }

    function setOperator(
        address operator,
        bool approved
    ) external returns (bool success) {
        ERC7540Storage storage $ = _getERC7540Storage();
        address msgSender = _msgSender();
        $.isOperator[msgSender][operator] = approved;
        emit OperatorSet(msgSender, operator, approved);
        return true;
    }

    // ## EIP7575 ##
    function share() external view returns (address) {
        return (address(this));
    }

    // ## EIP165 ##
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        interfaceId;
        return true;
    }
}
