// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseTest} from "./Base.sol";
import {GuardrailsLib} from "@src/v0.6.0/libraries/GuardrailsLib.sol";
import {GuardrailsViolation, LowerRateCannotBeInt256Min, OnlySecurityCouncil} from "@src/v0.6.0/primitives/Errors.sol";
import {Guardrails} from "@src/v0.6.0/primitives/Struct.sol";

contract TestGuardrails is BaseTest {
    function setUp() public {
        setUpVault(0, 0, 0);
    }

    // Those tests focus on the updateGuardrails function. //

    function test_updateGuardrails_onlySecurityCouncilCanUpdate() public {
        vm.expectRevert(abi.encodeWithSelector(OnlySecurityCouncil.selector, vault.securityCouncil()));
        vault.updateGuardrails(Guardrails({upperRate: 0, lowerRate: 0}));
    }

    function test_securityCouncilCanUpdateGuardrails() public {
        vm.prank(vault.securityCouncil());
        vault.updateGuardrails(Guardrails({upperRate: 1, lowerRate: 2}));

        assertEq(vault.guardrails().upperRate, 1);
        assertEq(vault.guardrails().lowerRate, 2);
    }

    function test_updateNewTotalAssets_RevertsIfGuardrailsAreNotCompliant() public {
        dealAndApproveAndWhitelist(user1.addr);
        requestDeposit(10 ** vault.decimals(), user1.addr);
        updateAndSettle(0);
        vm.warp(block.timestamp + 12);

        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(1), lowerRate: negRatePerYearToBips(-2)});

        vm.prank(vault.securityCouncil());
        vault.updateGuardrails(guardrails);

        vm.prank(vault.valuationManager());
        vm.expectRevert(abi.encodeWithSelector(GuardrailsViolation.selector));
        vault.updateNewTotalAssets(1);
    }

    function test_updateNewTotalAssets_PassesIfSubmittedBySecurityCouncil() public {
        dealAndApproveAndWhitelist(user1.addr);
        requestDeposit(10 ** vault.decimals(), user1.addr);
        updateAndSettle(0);
        vm.warp(block.timestamp + 12);

        Guardrails memory guardrails =
            Guardrails({upperRate: ratePerYearToBips(1), lowerRate: negRatePerYearToBips(-2)});

        vm.prank(vault.securityCouncil());
        vault.updateGuardrails(guardrails);

        vm.prank(vault.securityCouncil());
        vault.updateNewTotalAssets(1);
    }

    function test_updateGuardrails_RevertsIfLowerRateIsInt256Min() public {
        Guardrails memory guardrails = Guardrails({upperRate: ratePerYearToBips(20), lowerRate: type(int256).min});

        vm.prank(vault.securityCouncil());
        vm.expectRevert(abi.encodeWithSelector(LowerRateCannotBeInt256Min.selector));
        vault.updateGuardrails(guardrails);
    }
}
