// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {BatchScript} from "../tools/BatchScript.sol";
import {Options, Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
/*
 This script will propose safe txs to:
 - upgrade the set of signers of the DAO multisig
*/

interface Safe {
    function swapOwner(
        address prevOwner,
        address oldOwner,
        address newOwner
    ) external;
}

contract UpdateDaoSigners is BatchScript {
    address DAO;
    address oldSigner = 0xD8e6501f08A17F9459598450b520871DF6EB574C;
    address newSigner = 0x1Dacf90f26F04Eddb9d712f48d96660D88049075;
    address prevOwner = 0x27D076f6168DDc0E48103d963273B1D8d98EF70C; // this address points to oldSigner in the Safe

    function run() external virtual isBatch(vm.envAddress("SAFE_ADDRESS")) {
        DAO = vm.envAddress("DAO");
        swapSigner(DAO, prevOwner, oldSigner, newSigner);
        executeBatch(true);
    }

    function swapSigner(
        address dao,
        address _prevOwner,
        address _oldSigner,
        address _newSigner
    ) internal {
        bytes memory txn = abi.encodeWithSelector(Safe.swapOwner.selector, _prevOwner, _oldSigner, _newSigner);
        addToBatch(dao, 0, txn);
    }
}
