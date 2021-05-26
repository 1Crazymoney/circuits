const ethers = require("ethers");
const { poseidon } = require("circomlib");

class MerkleTree {
  constructor(depth) {
    // Set depth
    this.depth = depth;

    // Calculate zero values
    this.zeros = MerkleTree.getZeroValueLevels(depth);

    // Initialize leaves array, stores commitment hash, block number,
    // and transaction index in an object
    // { hash, block, txindex }
    this.leaves = [];

    // Initialize tree (2d array of merkle tree levels)
    // Don't use .fill([]) here as it fills with references to the same array
    this.tree = Array(depth)
      .fill(0)
      .map(() => []);

    // Set empty tree root
    this.tree[depth] = [
      MerkleTree.hashLeftRight(this.zeros[depth - 1], this.zeros[depth - 1]),
    ];
  }

  rebuildSparseTree() {
    for (let level = 0; level < this.depth; level += 1) {
      this.tree[level + 1] = [];

      for (let pos = 0; pos < this.tree[level].length; pos += 2) {
        this.tree[level + 1].push(
          MerkleTree.hashLeftRight(
            this.tree[level][pos],
            this.tree[level][pos + 1] ?? this.zeros[level]
          )
        );
      }
    }
  }

  insertLeaves(leaves) {
    // Make all leaves BigInts
    // eslint-disable-next-line no-param-reassign
    leaves = leaves.map(BigInt);

    // Add leaves to bottom of tree
    this.tree[0] = this.tree[0].concat(leaves);

    // Rebuild tree
    this.rebuildSparseTree();
  }

  generateProof(element) {
    // Ensure element is BigInt
    // eslint-disable-next-line no-param-reassign
    element = BigInt(element);

    // Initialize array for proof
    const proof = [];

    // Get initial index
    let index = this.tree[0].indexOf(element);

    // Loop through each level
    for (let level = 0; level < this.depth; level += 1) {
      if (index % 2 === 0) {
        // If index is even get element on right
        proof.push({
          position: 0,
          pair: this.tree[level][index + 1] ?? this.zeros[level],
        });
      } else {
        // If index is odd get element on left
        proof.push({
          position: 1,
          pair: this.tree[level][index - 1] ?? this.zeros[level],
        });
      }

      // Get index for next level
      index = Math.floor(index / 2);
    }

    return {
      element,
      proof,
    };
  }

  validateProof(proof) {
    // Return false on invalid proof depth
    if (proof.proof.length !== this.depth) return false;

    // Inital currentHash value is the element we're prooving membership for
    let currentHash = proof.element;

    // Loop though each proof level and hash together
    for (let i = 0; i < proof.proof.length; i += 1) {
      if (proof.proof[i].position === 0) {
        currentHash = MerkleTree.hashLeftRight(
          currentHash,
          proof.proof[i].pair
        );
      } else {
        currentHash = MerkleTree.hashLeftRight(
          proof.proof[i].pair,
          currentHash
        );
      }
    }

    // Return true if result is equal to merkle root
    return currentHash === this.root;
  }

  get root() {
    return this.tree[this.depth][0];
  }

  static hashLeftRight(left, right) {
    return poseidon([left, right]);
  }

  static getZeroValue() {
    // Snark scalar field, this is a constant from the ECC curve used in the SNARK prooving system
    const snarkScalarField = ethers.BigNumber.from(
      "21888242871839275222246405745257275088548364400416034343698204186575808495617"
    );
    const railgunHash = ethers.BigNumber.from(
      ethers.utils.keccak256(Buffer.from("Railgun", "utf8"))
    );
    return BigInt(railgunHash.mod(snarkScalarField));
  }

  static getZeroValueLevels(depth) {
    // Initialize empty array for levels
    const levels = [];

    // First level should be the leaf zero value
    levels.push(this.getZeroValue());

    // Loop through remaining levels to root
    for (let level = 1; level < depth; level += 1) {
      // Push left right hash of level below's zero level
      levels.push(
        MerkleTree.hashLeftRight(levels[level - 1], levels[level - 1])
      );
    }

    return levels;
  }
}

module.exports = MerkleTree;
