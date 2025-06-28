// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {FeeRegistry} from "./FeeRegistry.sol";
import {LogicRegistry} from "./LogicRegistry.sol";

contract ProtocolRegistry is FeeRegistry, LogicRegistry {
    /// @custom:oz-upgrades-unsafe-allow constructor
    // solhint-disable-next-line ignoreConstructors
    constructor(
        bool disable
    ) {
        if (disable) _disableInitializers();
    }

    function initialize(address initialOwner, address _protocolFeeReceiver) public initializer {
        __FeeRegistry_init(initialOwner, _protocolFeeReceiver);
    }
}
