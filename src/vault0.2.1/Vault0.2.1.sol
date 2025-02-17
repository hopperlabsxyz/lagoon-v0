// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {Vault0_2_0} from "@src/vault0.2.0/Vault0.2.0.sol";

contract Vault0_2_1 is Vault0_2_0 {
    constructor(
        bool disable
    ) Vault0_2_0(disable) {}

    function version() public pure returns (string memory) {
        return "v0.2.1";
    }
}
