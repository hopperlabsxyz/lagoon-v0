const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// Generate a merkle trees based on the whitelist config in config.json
//
// Create the whitelist you want in config.json and then run this script
// It will dump all trees in output folder
//
// Then you can run proofs.js which will generate proofs for each account
// of each whitelist

const config = JSON.parse(fs.readFileSync("config.json", "utf8"));

for (const [key, accounts] of Object.entries(config)) {
  const treeOutput = `output/tree_${key}.json`;
  const tree = StandardMerkleTree.of(accounts, ["address"]);
  console.log("Merkle Root:", tree.root);
  fs.writeFileSync(treeOutput, JSON.stringify(tree.dump(), null, 2));
}
