// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {IERC7575} from "./IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IERC7540 is IERC7575, IERC165 {
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    // EIP7575 https://eips.ethereum.org/EIPS/eip-7575
    function share() external view returns (address);

    function isOperator(address controller, address operator) external returns (bool);

    function setOperator(address operator, bool approved) external returns (bool success);
}
