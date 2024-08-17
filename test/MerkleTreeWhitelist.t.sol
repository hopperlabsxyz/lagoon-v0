// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import {Vault} from "@src/Vault.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {NotWhitelisted} from "@src/Whitelistable.sol";
import {BaseTest} from "./Base.sol";

bytes32 constant defaultRoot = 0x2d4a4a77812b41a135553e347ceecc3525a5a32e1bc0f2291bc10d186a847c23;

struct Proof {
    address account;
    bytes32[] proof;
}

struct Commit {
    Proof[] proofs;
    bytes32 root;
}

// Add whitelist here after adding it to proofs/config.json
struct Config {
    address[][] whitelist_0; // default whitelist (dw)
    address[][] whitelist_1; // dw + user1
    address[][] whitelist_2; // dw + user2
}

contract TestMerkleTreeWhitelist is BaseTest {
    bytes proofsData;
    bytes configData;

    function loadConfig(
        uint256 id
    )
        public
        returns (bytes32 root, Proof[] memory proofs, address[] memory accounts)
    {
        string memory rootPath = vm.projectRoot();

        // Loading config
        string memory path = string.concat(
            rootPath,
            "/test/proofs/config.json"
        );
        string memory json = vm.readFile(path);
        configData = vm.parseJson(json);
        Config memory config = abi.decode(configData, (Config));

        address[][] memory whitelist;
        if (id == 0) {
            whitelist = config.whitelist_0;
        } else if (id == 1) {
            whitelist = config.whitelist_1;
        }

        accounts = new address[](whitelist.length);
        for (uint256 i; i < whitelist.length; i++) {
            accounts[i] = whitelist[i][0];
        }

        // Loading proofs
        path = string.concat(
            rootPath,
            "/test/proofs/output/proofs_",
            Strings.toString(id),
            ".json"
        );
        json = vm.readFile(path);
        proofsData = vm.parseJson(json);
        Commit memory commit = abi.decode(proofsData, (Commit));
        proofs = commit.proofs;
        root = commit.root;
    }

    function findProof(
        address account,
        Proof[] memory proofs
    ) internal pure returns (Proof memory proof, bool found) {
        for (uint256 i; i < proofs.length; i++) {
            if (proofs[i].account == account) {
                return (proofs[i], true);
            }
        }
        return (Proof(address(0), new bytes32[](0)), false);
    }

    function withWhitelistSetUp(
        uint256 whitelistId
    )
        public
        returns (bytes32 root, Proof[] memory proofs, address[] memory accounts)
    {
        (root, proofs, accounts) = loadConfig(whitelistId);
        setUpVault(0, 0, 0);
        vm.prank(vault.whitelistManager());
        vault.setRoot(root);

        uint256 len = accounts.length;

        for (uint256 i; i < len; i++) {
            assertEq(proofs[i].account, accounts[i]);
            assertTrue(vault.isWhitelisted(accounts[i], proofs[i].proof));
        }
        dealAndApprove(user1.addr);
    }

    function withoutWhitelistSetUp() public {
        enableWhitelist = false;
        setUpVault(0, 0, 0);
        for (uint256 i; i < whitelistInit.length; i++) {
            assertFalse(
                vault.isWhitelisted(whitelistInit[i], new bytes32[](0))
            );
        }
        dealAndApprove(user1.addr);
    }

    function test_whitelistInitListMembersShouldBeWhitelisted() public {
        withWhitelistSetUp(0);
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelisted()
        public
    {
        (, Proof[] memory proofs, ) = withWhitelistSetUp(0); // user1.addr is NOT whitelisted

        (Proof memory proof, bool found) = findProof(user1.addr, proofs);
        assertEq(
            found,
            false,
            "Proof was found but we expect it not to be found"
        );

        uint256 userBalance = assetBalance(user1.addr);
        vm.startPrank(user1.addr);
        vm.expectRevert(
            abi.encodeWithSelector(NotWhitelisted.selector, user1.addr)
        );

        vault.requestDeposit(
            userBalance,
            user1.addr,
            user1.addr,
            abi.encode(proof.proof)
        );
    }

    function test_requestDeposit_ShouldFailWhenControllerNotWhitelistedAndOperatorAndOwnerAre()
        public
    {
        withWhitelistSetUp(1); // user1.addr is whitelisted
        uint256 userBalance = assetBalance(user1.addr);
        address controller = user2.addr;
        address operator = user1.addr;
        address owner = user1.addr;
        vm.startPrank(operator);
        vm.expectRevert(abi.encodeWithSelector(NotWhitelisted.selector, owner));
        vault.requestDeposit(userBalance, controller, owner);
    }

    function test_transfer_WhenReceiverNotWhitelistedAfterDeactivateOfWhitelisting()
        public
    {
        (, Proof[] memory proofs, ) = withWhitelistSetUp(1); // user1.addr is whitelisted
        (Proof memory proof, bool found) = findProof(user1.addr, proofs);
        assertEq(found, true, "Should find proof but it didn't");
        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr, abi.encode(proof.proof));
        settle();

        deposit(userBalance, user1.addr);
        address receiver = user2.addr;
        vm.prank(vault.owner());
        vault.deactivateWhitelist();
        vm.assertEq(vault.isWhitelistActivated(), false);
        uint256 shares = vault.balanceOf(user1.addr);
        vm.prank(user1.addr);
        vault.transfer(receiver, shares);
    }

    function test_transfer_ShouldWorkWhenReceiverWhitelisted() public {
        (, Proof[] memory proofs, ) = withWhitelistSetUp(1); // user1.addr is whitelisted
        (Proof memory proof, bool found) = findProof(user1.addr, proofs);
        assertEq(found, true, "Should find proof but it didn't");

        uint256 userBalance = assetBalance(user1.addr);
        requestDeposit(userBalance, user1.addr, abi.encode(proof.proof));
        settle();
        deposit(userBalance, user1.addr);
        uint256 shares = vault.balanceOf(user1.addr);
        address receiver = user2.addr;

        vm.prank(user1.addr);
        vault.transfer(receiver, shares);
    }

    function test_whitelist() public {
        (, Proof[] memory proofs, ) = withWhitelistSetUp(1); // user1.addr is whitelisted
        (Proof memory proof, bool found) = findProof(user1.addr, proofs);
        assertEq(found, true, "Should find proof but it didn't");

        assertEq(vault.isWhitelisted(user1.addr, proof.proof), true);
    }

    function test_whitelistList() public {
        (, Proof[] memory proofs, ) = withWhitelistSetUp(3); // user1.addr & user2.addr are whitelisted
        (Proof memory proof, bool found) = findProof(user1.addr, proofs);
        assertEq(found, true, "Should find proof but it didn't");
        assertEq(vault.isWhitelisted(user1.addr, proof.proof), true);
        (proof, found) = findProof(user2.addr, proofs);
        assertEq(found, true, "Should find proof but it didn't");
        assertEq(vault.isWhitelisted(user2.addr, proof.proof), true);
    }

    function test_unwhitelistList() public {
        (, Proof[] memory proofs, ) = withWhitelistSetUp(1); // user1.addr is whitelisted
        (Proof memory proof, bool found) = findProof(user1.addr, proofs);
        assertEq(found, true, "Should find proof but it didn't");

        assertEq(vault.isWhitelisted(user1.addr, proof.proof), true);
        (, proofs, ) = withWhitelistSetUp(2); // user2.addr is whitelisted
        (proof, found) = findProof(user1.addr, proofs);
        assertEq(
            found,
            false,
            "Proof was found but we expect it not to be found"
        );

        assertEq(vault.isWhitelisted(user2.addr, proof.proof), false);
        (proof, found) = findProof(user2.addr, proofs);
        assertEq(found, true, "Should find proof but it didn't");

        assertEq(
            vault.isWhitelisted(user2.addr, proof.proof),
            true,
            "user2 should be whitelisted"
        );
    }

    function test_noWhitelist() public {
        withoutWhitelistSetUp();
        requestDeposit(1, user1.addr);
    }

    function test_getRoot() public {
        (bytes32 root, , ) = withWhitelistSetUp(1); // user1.addr is whitelisted
        assertEq(root, vault.getRoot());
        (root, , ) = loadConfig(2);
        vm.prank(vault.whitelistManager());
        vault.setRoot(root);
        assertEq(root, vault.getRoot());
    }
}
