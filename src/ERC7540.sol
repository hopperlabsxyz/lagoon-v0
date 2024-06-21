//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

struct ERC7540Storage {
    mapping(address controller => mapping(address operator => bool)) isOperator;
}

abstract contract ERC7540Upgradeable is
    IERC7540Deposit,
    IERC7540Redeem,
    ERC4626Upgradeable
{
    // keccak256(abi.encode(uint256(keccak256("hopper.storage.ERC7540")) - 1)) & ~bytes32(uint256(0xff));
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant erc7540Storage =
      0x5c74d456014b1c0eb4368d944667a568313858a3029a650ff0cb7b56f8b57a00;


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
    function supportsInterface(
        bytes4 interfaceId
    ) public pure virtual returns (bool) {
        interfaceId;
        return true;
    }

    function previewDeposit(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }

    function previewMint(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }

    function previewRedeem(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }

    function previewWithdraw(
        uint256
    ) public pure override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        require(false);
    }
}
