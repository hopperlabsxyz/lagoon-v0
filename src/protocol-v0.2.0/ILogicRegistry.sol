// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface ILogicRegistry {
    error LogicNotWhitelisted(address Logic);

    event DefaultLogicUpdated(string version, address previous, address newImpl);
    event LogicAdded(string version, address Logic);
    event LogicRemoved(string version, address Logic);

    /**
     * @notice Updates the default logic implementation for a specific version
     * @param version The version identifier
     * @param _newLogic The new logic implementation address
     * @dev Reverts if the new logic is not whitelisted for the version
     */
    function updateDefaultLogic(string calldata version, address _newLogic) external;

    /**
     * @notice Removes a logic implementation from the whitelist for a version
     * @param version The version identifier
     * @param _newLogic The logic implementation address to remove
     */
    function removeLogic(string calldata version, address _newLogic) external;

    /**
     * @notice Adds a logic implementation to the whitelist for a version
     * @param version The version identifier
     * @param _newLogic The logic implementation address to add
     */
    function addLogic(string calldata version, address _newLogic) external;

    /**
     * @notice Checks if a logic implementation can be used for a specific version
     * @param version The version identifier
     * @param logic The logic implementation address to check
     * @return bool True if the logic is whitelisted for the version
     */
    function canUseLogic(string calldata version, address, address logic) external view returns (bool);

    function defaultLogic(
        string calldata version
    ) external view returns (address);
}
