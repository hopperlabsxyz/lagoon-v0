// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC7575} from "./IERC7575.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title IERC7540 - Asynchronous ERC-4626 Tokenized Vault interface
interface IERC7540 is IERC7575, IERC165 {
    /// @notice Emitted when an operator is approved or revoked for a controller
    /// @param controller The address of the controller granting/revoking operator rights
    /// @param operator The address being approved or revoked as operator
    /// @param approved True if the operator is approved, false if revoked
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    /// @notice Returns the address of the share token
    /// @return The address of the ERC20 share token
    function share() external view returns (address);

    /// @notice Checks whether an address is an approved operator for a controller
    /// @param controller The address of the controller
    /// @param operator The address to check operator status for
    /// @return True if the operator is approved for the controller
    function isOperator(
        address controller,
        address operator
    ) external view returns (bool);

    /// @notice Approves or revokes an operator for the caller
    /// @param operator The address to approve or revoke as operator
    /// @param approved True to approve, false to revoke
    /// @return success True if the operation succeeded
    function setOperator(
        address operator,
        bool approved
    ) external returns (bool success);
}
