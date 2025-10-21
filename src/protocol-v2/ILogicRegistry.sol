// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface ILogicRegistry {
    error LogicNotWhitelisted(address Logic);

    event DefaultLogicUpdated(address previous, address newImpl);
    event LogicAdded(address Logic);
    event LogicRemoved(address Logic);

    /**
     * @notice Updates the default logic implementation for a specific version
     * @param _newLogic The new logic implementation address
     * @dev Reverts if the new logic is not whitelisted for the version
     */
    function updateDefaultLogic(
        address _newLogic
    ) external;

    /**
     * @notice Removes a logic implementation from the whitelist for a version
     * @param _newLogic The logic implementation address to remove
     */
    function removeLogic(
        address _newLogic
    ) external;

    /**
     * @notice Adds a logic implementation to the whitelist for a version
     * @param _newLogic The logic implementation address to add
     */
    function addLogic(
        address _newLogic
    ) external;

    /**
     * @notice Checks if a logic implementation can be used for a specific version
     * @param logic The logic implementation address to check
     * @return bool True if the logic is whitelisted for the version
     */
    function canUseLogic(
        address,
        address logic
    ) external view returns (bool);

    function defaultLogic() external view returns (address);
}
