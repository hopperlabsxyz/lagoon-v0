// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title SanctionsList - Interface for external sanctions list oracle
/// @notice Used to check whether an address is sanctioned and should be denied access
interface SanctionsList {
    /// @notice Checks whether an address is on the sanctions list
    /// @param addr The address to check
    /// @return True if the address is sanctioned
    function isSanctioned(
        address addr
    ) external view returns (bool);
}
