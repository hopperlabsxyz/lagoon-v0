// SPDX-License-Identifier: MIT
// pragma solidity 0.8.25;
// 
// import "forge-std/Test.sol";
// 
// import {FeeLibrary} from "@src/libraries/FeeLibrary.sol";
// import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
// 
// uint256 constant BPS = 10_000;
// uint256 constant EXIT_RATE = 100; // 1 %
// uint256 constant ENTRY_RATE = 100; // 1 %
// uint256 constant MANAGEMENT_RATE = 200; // 2 %
// uint256 constant PERFORMANCE_RATE = 2000; // 20 %
// 
// uint256 constant ONE_YEAR = 365 days;
// 
// contract FeeLibraryTest is Test {
//     using Math for uint256;
// 
//     uint256 _1M;
// 
//     function setUp() public {
//         _1M = 1_000_000 * 10 ** 6;
//     }
// 
//     function test_calculatePerformanceFee() public pure {
//         assertEq(FeeLibrary.calculatePerformanceFee(10_000, 0, 2_000), 2_000);
//         assertEq(
//             FeeLibrary.calculatePerformanceFee(10_000, 2_000, 2_000),
//             1_600
//         );
//         assertEq(FeeLibrary.calculatePerformanceFee(2_000, 2_001, 2_000), 0);
//     }
// 
//     function test_calculateManagementFee() public pure {
//         assertEq(FeeLibrary.calculateManagementFee(10_000, ONE_YEAR, 200), 200);
//     }
// }
