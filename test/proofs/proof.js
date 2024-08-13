const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// This script allows you to generate all proofs for a given
// tree and set of accounts
//
// Please run tree.js before runing this script
// You can change the accounts you want to based you tree on
// in config.json file

const treeOutput = "output/tree.json";
const proofsOutput = "output/proofs.json";

const { accounts } = JSON.parse(fs.readFileSync("./config.json", "utf8"));

const tree = StandardMerkleTree.load(
  JSON.parse(fs.readFileSync(treeOutput, "utf8"))
);

function getProof(_account) {
  for (const [key, [account]] of tree.entries()) {
    if (account === _account) {
      const proof = tree.getProof(key);
      return { account, proof };
    }
  }
}

const proofs = [];
for (const [account] of accounts) {
  proofs.push(getProof(account));
}

fs.writeFileSync(
  proofsOutput,
  JSON.stringify({ root: tree.root, proofs }, null, 2)
);

console.log(`Success! Proofs written to ${proofsOutput}`);
