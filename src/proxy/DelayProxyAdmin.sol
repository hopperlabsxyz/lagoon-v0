// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DelayProxyAdmin is ProxyAdmin {
    ///@notice The `delay` period is not terminated
    error DelayIsNotOver();

    ///@notice The `new delay` must be above `minDelay`
    error DelayTooLow(uint256 minDelay);

    ///@notice The `new delay` must be under `maxDelay`
    error DelayTooHigh(uint256 maxDelay);

    /// @notice A `newImplementation` will be enforcable at `implementationUpdateTime`
    event ImplementationUpdateSubmited(
        address indexed newImplementation,
        uint256 implementationUpdateTime
    );

    /// @notice The `currentDelay` will be replacable by a `newDelay` period at `delayUpdateTime`
    event DelayUpdateSubmited(
        uint256 currentDelay,
        uint256 newDelay,
        uint256 delayUpdateTime
    );

    /// @notice The `currentDelay` will be replacable by a `newDelay` period at `delayUpdateTime`
    event DelayUpdated(uint256 newDelay, uint256 oldDelay);

    /// @notice This value is used to protect owner to put an infinite amount
    uint256 public constant MAX_DELAY = 30 days;

    /// @notice The minimum delay before which the implementation can be upgraded
    uint256 public constant MIN_DELAY = 1 days;

    /// @notice The time at can call upgradeAndCall to upgrade to implementation
    uint256 public implementationUpdateTime;

    /// @notice The new implementation used after successfull upgradeAndCall
    address public implementation;

    /// @notice The moment when you can call updateDelay to a new delay
    uint256 public delayUpdateTime;

    /// @notice The new delay enforced after updateDelay
    uint256 public newDelay;

    /// @notice The delay to wait before upgradeAndCall can be call and updateDelay
    uint256 public delay;

    constructor(
        address initialOwner,
        uint256 initialDelay
    ) ProxyAdmin(initialOwner) {
        _updateDelay(initialDelay);
        implementationUpdateTime = type(uint256).max;
        delayUpdateTime = type(uint256).max;
    }

    function _updateDelay(uint256 _delay) internal {
        require(block.timestamp > delayUpdateTime, DelayIsNotOver());
        require(_delay >= MIN_DELAY, DelayTooLow(MIN_DELAY));
        require(_delay <= MAX_DELAY, DelayTooHigh(MAX_DELAY));
        emit DelayUpdated(_delay, delay);
        delay = _delay;
    }

    function updateDelay() public onlyOwner {
        _updateDelay(newDelay);
    }

    function submitImplementation(address _implementation) external onlyOwner {
        implementation = _implementation;
        implementationUpdateTime = block.timestamp + delay;
        emit ImplementationUpdateSubmited(
            implementation,
            implementationUpdateTime
        );
    }

    function submitDelay(uint256 _delay) external onlyOwner {
        newDelay = _delay;
        delayUpdateTime = block.timestamp + delay;
        emit DelayUpdateSubmited(delay, newDelay, delayUpdateTime);
    }

    /**
     * @dev Upgrades `proxy` to `implementation` and calls a function on the new implementation.
     * See {TransparentUpgradeableProxy-_dispatchUpgradeToAndCall}.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     * - If `data` is empty, `msg.value` must be zero.
     */
    function upgradeAndCall(
        ITransparentUpgradeableProxy proxy,
        bytes memory data
    ) public payable onlyOwner {
        require(block.timestamp > implementationUpdateTime, DelayIsNotOver());
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
        implementation = address(0);
    }
}
