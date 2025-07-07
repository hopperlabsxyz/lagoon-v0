// SPDX-License-Identifier: BUSL-1.1
pragma solidity "0.8.26";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DelayProxyAdmin is ProxyAdmin {
    ///@notice The `delay` period is not terminated
    error DelayIsNotOver();

    ///@notice The `new delay` must be above `minDelay`
    error DelayTooLow(uint256 minDelay);

    ///@notice The `new delay` must be under `maxDelay`
    error DelayTooHigh(uint256 maxDelay);

    /// @notice The `newImplementation` address will be enforcable at `implementationUpdateTime`
    event ImplementationUpdateSubmited(address indexed newImplementation, uint256 implementationUpdateTime);

    /// @notice The `currentDelay` will be enforcable to `newDelay`  at `delayUpdateTime`
    event DelayUpdateSubmited(uint256 currentDelay, uint256 newDelay, uint256 delayUpdateTime);

    /// @notice The `currentDelay` will be replacable by a `newDelay` period at `delayUpdateTime`
    event DelayUpdated(uint256 newDelay, uint256 oldDelay);

    /// @notice The maximum delay before which the implementation and the delay can be upgraded
    uint256 public constant MAX_DELAY = 30 days;

    /// @notice The minimum delay before which the implementation and the delay can be upgraded
    uint256 public constant MIN_DELAY = 1 days;

    /// @notice The time at which upgradeAndCall is callable
    uint256 public implementationUpdateTime;

    /// @notice The new `implementation` enforced after `upgradeAndCall`
    address public implementation;

    /// @notice The time at which `updateDelay` is callable
    uint256 public delayUpdateTime;

    /// @notice The new `delay` enforced after `updateDelay`
    uint256 public newDelay;

    /// @notice The time to wait before upgradeAndCall and updateDelay can be call to enforce `implementation` and
    /// `newDelay` respectively
    uint256 public delay;

    /// @notice Initializes the DelayProxyAdmin contract
    /// @dev Sets up the contract with initial owner and delay parameters
    /// @param initialOwner The address that will own this contract
    /// @param initialDelay The initial delay period that must be waited before upgrades can be executed
    constructor(address initialOwner, uint256 initialDelay) ProxyAdmin(initialOwner) {
        require(initialDelay >= MIN_DELAY, DelayTooLow(MIN_DELAY));
        require(initialDelay <= MAX_DELAY, DelayTooHigh(MAX_DELAY));
        implementationUpdateTime = type(uint256).max;
        delayUpdateTime = type(uint256).max;
    }

    /// @notice Updates the delay period to the previously submitted new delay
    /// @dev Can only be called by the owner after the delay period has passed
    ///
    /// Requirements:
    /// - Must be called by the owner
    /// - The delayUpdateTime must have passed
    function updateDelay() public onlyOwner {
        require(block.timestamp > delayUpdateTime, DelayIsNotOver());
        emit DelayUpdated(newDelay, delay);
        delay = newDelay;
    }

    /// @notice Submits a new implementation address for future enforcement
    /// @dev Starts the timelock period for the implementation upgrade
    /// @param _implementation The new implementation to be enforced after the timelock
    ///
    /// Requirements:
    /// - Must be called by the owner
    function submitImplementation(
        address _implementation
    ) external onlyOwner {
        implementation = _implementation;
        implementationUpdateTime = block.timestamp + delay;
        emit ImplementationUpdateSubmited(implementation, implementationUpdateTime);
    }

    /// @notice Submits a new delay period for future enforcement
    /// @dev Starts the timelock period for the delay update
    /// @param _delay The new delay period to be enforced after the timelock
    ///
    /// Requirements:
    /// - Must be called by the owner
    /// - The _delay must be within MIN_DELAY and MAX_DELAY bounds
    function submitDelay(
        uint256 _delay
    ) external onlyOwner {
        require(_delay >= MIN_DELAY, DelayTooLow(MIN_DELAY));
        require(_delay <= MAX_DELAY, DelayTooHigh(MAX_DELAY));
        newDelay = _delay;
        delayUpdateTime = block.timestamp + delay;
        emit DelayUpdateSubmited(delay, newDelay, delayUpdateTime);
    }

    /// @dev Upgrades `proxy` to `implementation` and calls a function on the new implementation.
    /// See {TransparentUpgradeableProxy-_dispatchUpgradeToAndCall}.
    ///
    /// Requirements:
    ///
    /// - This contract must be the admin of `proxy`.
    /// - If `data` is empty, `msg.value` must be zero.
    function upgradeAndCall(ITransparentUpgradeableProxy proxy, bytes memory data) public payable onlyOwner {
        require(block.timestamp > implementationUpdateTime, DelayIsNotOver());
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
        implementation = address(0);
    }
}
