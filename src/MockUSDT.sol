// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDT
 * @notice Mock USDT token for testing airdrop functionality
 * @dev Simple ERC20 with public mint function - only for testnet use
 */
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock Tether USD", "USDT") {}

    /**
     * @notice Returns 6 decimals to match real USDT
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @notice Public mint function for testing
     * @param to Address to receive tokens
     * @param amount Amount to mint (in 6 decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
