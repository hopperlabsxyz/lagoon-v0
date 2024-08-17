const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// This script allows you to generate all proofs for a given
// set of trees and set of accounts
//
// Please run tree.js before runing this script
// Update config.json to change the whitelisted accounts for
// each config

function createProofs(pathId, accounts) {
  const treePath = `output/tree_${pathId}.json`;
  const proofsPath = `output/proofs_${pathId}.json`;
  const tree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync(treePath, "utf8"))
  );

  const getProof = (_account) => {
    for (const [key, [account]] of tree.entries()) {
      if (account === _account) {
        const proof = tree.getProof(key);
        return { account, proof };
      }
    }
  };
  const proofs = accounts.map(([a]) => getProof(a));
  const root = tree.root;

  console.log(`Config: ${pathId}`);
  console.log(`Root: ${root}`);
  console.log("-----------------");

  fs.writeFileSync(proofsPath, JSON.stringify({ root, proofs }, null, 2));
}

const config = JSON.parse(fs.readFileSync("config.json", "utf8"));

for (const [key, accounts] of Object.entries(config)) {
  createProofs(key, accounts);
}
