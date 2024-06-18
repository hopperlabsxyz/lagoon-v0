//SPDX-License-Identifier: MIT
pragma solidity "0.8.25";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {ERC7540Upgradeable} from "./ERC7540.sol";

abstract contract ERC7540Redeem is IERC7540Redeem, ERC7540Upgradeable {}
