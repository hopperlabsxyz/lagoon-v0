const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

// (1)
const values = [
  ["0x344ef496b004663a04d70B427a78E33cC3E9f619"], // feeReceiver
  ["0x952687863142ce6f9cFE7D264C5AF405642F6AA8"], // dao
  ["0x42188104f27FeaAB648388227ae3C5C7cB16Ca6e"], // assetManager
  ["0xB670F3Bf357A4cC997eCb663E8BFF04e27A10c5D"], // whitelistManager
  ["0x058e2D3ed069dfB9B76dA682c7842F5a27a94767"], // valorizator
  ["0xaA10a84CE7d9AE517a52c6d5cA153b369Af99ecF"], // admin
  ["0xf801f3A6F4e09F82D6008505C67a0A5b39842406"], // pendingSilo
  ["0x0000000000000000000000000000000000000000"], // void
];

// (2)
const tree = StandardMerkleTree.of(values, ["address"]);

// (3)
console.log("Merkle Root:", tree.root);

// (4)
fs.writeFileSync("tree.json", JSON.stringify(tree.dump(), null, 4));
