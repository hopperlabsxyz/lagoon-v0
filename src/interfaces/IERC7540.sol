//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {IERC7540Deposit} from "./IERC7540Deposit.sol";
import {IERC7540Redeem} from "./IERC7540Redeem.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC7575} from "./IERC7575.sol";

interface IERC7540 is IERC7540Deposit, IERC7540Redeem, IERC7575, IERC165 {
    event OperatorSet(
        address indexed controller,
        address indexed operator,
        bool approved
    );

    // EIP7575 https://eips.ethereum.org/EIPS/eip-7575
    function share() external view returns (address);

    function isOperator(
        address controller,
        address operator
    ) external returns (bool);

    function setOperator(
        address operator,
        bool approved
    ) external returns (bool success);

    function deposit(
        uint256 assets,
        address receiver,
        address controller
    ) external;

    function mint(
        uint256 shares,
        address receiver,
        address controller
    ) external;
}
