const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// Generate a merkle tree root based on config.json accounts
// the tree dump is then saved into output/tree.json
//
// Once you created your tree root you can run proofs.js to
// generate all proofs according to each account. Proofs or
// stored into output/proofs.json

const treeOutput = "output/tree.json";

const { accounts } = JSON.parse(fs.readFileSync("config.json", "utf8"));

const tree = StandardMerkleTree.of(accounts, ["address"]);

console.log("Merkle Root:", tree.root);

fs.writeFileSync(treeOutput, JSON.stringify(tree.dump(), null, 2));
