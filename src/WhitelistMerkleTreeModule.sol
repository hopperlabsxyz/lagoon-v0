// SPDX-License-Identifier: MIT
pragma solidity "0.8.25";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IWhitelistModule} from "./interfaces/IWhitelistModule.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistMapModule is IWhitelistModule, Ownable {
    event AddedToWhitelist(address indexed account);
    event RevokedFromWhitelist(address indexed account);

    bytes32 internal root;

    constructor(address owner, bytes32 _root) Ownable(owner) {
        root = _root;
    }

    function updateRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function isWhitelisted(
        address account,
        bytes calldata data
    ) external view returns (bool) {
        bytes32[] memory proof = abi.decode(data, (bytes32[]));
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account))));
        return MerkleProof.verify(proof, root, leaf);
    }
}
