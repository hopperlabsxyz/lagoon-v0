// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";
import {GuardrailsLib} from "@src/v0.6.0/libraries/GuardrailsLib.sol";
import {Guardrails} from "@src/v0.6.0/primitives/Struct.sol";

contract TestisCompliant is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
    }

    // Helper function to convert percentage per year to scaled bips (multiplied by 1e18)
    // Example: ratePerYearToBips(20) returns 20% * 1e18 = 2e17
    function ratePerYearToBips(
        uint256 ratePercent
    ) internal pure returns (uint256) {
        return ratePercent * 1e16; // ratePercent * 1e16 = (ratePercent / 100) * 1e18
    }

    // Helper function to convert negative percentage per year to scaled bips
    // Example: negRatePerYearToBips(-10) returns -10% * 1e18 = -1e17
    function negRatePerYearToBips(
        int256 ratePercent
    ) internal pure returns (int256) {
        return ratePercent * int256(1e16);
    }

    function test_NoPpsVariation() public {
        Guardrails memory guardrails = Guardrails({upperRate: ratePerYearToBips(1), lowerRate: negRatePerYearToBips(0)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = pps;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid");
    }

    function test_NoPpsVariation_withZeroLowerRate() public {
        Guardrails memory guardrails = Guardrails({upperRate: ratePerYearToBips(1), lowerRate: negRatePerYearToBips(0)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = pps;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid");
    }

    function test_IncreasePps_UnderUpperRate() public {
        Guardrails memory guardrails = Guardrails({upperRate: ratePerYearToBips(20), lowerRate: 0});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 109 * 1e16;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid");
    }

    function test_IncreasePps_ExactUpperRate() public {
        Guardrails memory guardrails = Guardrails({upperRate: ratePerYearToBips(20), lowerRate: 0});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 110 * 1e16;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid");
    }

    function test_IncreasePps_ExactUpperRate_LowerBoundIsNeg() public {
        Guardrails memory guardrails = Guardrails({upperRate: ratePerYearToBips(20), lowerRate: -1});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 110 * 1e16;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid");
    }

    function test_IncreasePps_GreaterUpperRate() public {
        uint256 upperRate = 20; // 20%
        int256 lowerRate = 0; // 0%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 118 * 1e16;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertFalse(isValid, "guardrails is not valid");
    }

    function test_IncreasePps_UnderLowerBound() public {
        uint256 upperRate = 20; // 20%
        int256 lowerRate = 10; // 10%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 1045 * 1e15; // +4.5 in 6 months so 9 over a year
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertFalse(isValid, "guardrails is not valid, new pps implies less than 10% growth over a year");
    }

    function test_IncreasePps_ExactLowerBound() public {
        uint256 upperRate = 20; // 20%
        int256 lowerRate = 10; // 10%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 105 * 1e16; // +5% in 6 months so 10% over a year
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid, new pps implies a 10% growth over a year");
    }

    function test_IncreasePps_InBetweenAndLowerBoundIsNeg() public {
        uint256 upperRate = 20; // 20%
        int256 lowerRate = -10; // -10%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 105 * 1e16; // +5% in 6 months so 10% over a year
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid, new pps implies a 10% growth over a year");
    }

    function test_IncreasePps_OverUpperAndLowerBoundIsNeg() public {
        uint256 upperRate = 9; // 9%
        int256 lowerRate = -10; // -10%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 105 * 1e16; // +5% in 6 months so 10% over a year
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertFalse(isValid, "guardrails is not valid, it should fail since growth is higher than 9%");
    }

    function test_decreasePpsUnderLowerRate() public {
        uint256 upperRate = 0; // 0%
        int256 lowerRate = -10; // -10%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 99 * 1e16;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid");
    }

    function test_decreasePpsExactLowerRate() public {
        uint256 upperRate = 0; // 0%
        int256 lowerRate = -10; // -10%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 95 * 1e16;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertTrue(isValid, "guardrails is not valid");
    }

    function test_decreasePpsOverLowerRate() public {
        uint256 upperRate = 0; // 0%
        int256 lowerRate = -10; // -10%
        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(upperRate), lowerRate: negRatePerYearToBips(lowerRate)});

        vm.prank(admin.addr);
        vault.updateGuardrails(guardrails);

        uint256 pps = 1e18;
        uint256 proposedPps = 95 * 1e16 - 1;
        uint256 timePast = GuardrailsLib.ONE_YEAR / 2; // 6 months

        bool isValid = vault.isCompliant(pps, proposedPps, timePast);
        assertFalse(isValid, "guardrails is not valid");
    }
}
