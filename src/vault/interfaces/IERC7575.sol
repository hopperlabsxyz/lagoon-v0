//SPDX-License-Identifier: MIT
pragma solidity "0.8.26";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// EIP7575 https://eips.ethereum.org/EIPS/eip-7575
interface IERC7575 is IERC4626 {
    function share() external view returns (address);
}
