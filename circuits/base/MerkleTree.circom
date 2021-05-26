include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";


template MerkleTree(n_levels) {
    signal input leaf;
    signal input pathIndices; //bitify it to know separate indices
    signal input pathElements[n_levels];
    signal output root;

    component hashers[n_levels];
    component index = Num2Bits(n_levels);
    index.in <== pathIndices;

    var levelHash;
    levelHash = leaf;

    for (var i = 0; i < n_levels; i++) {
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== index.out[i]*(pathElements[i] - levelHash) + levelHash;
        hashers[i].inputs[1] <== index.out[i]*(levelHash - pathElements[i]) + pathElements[i];
        levelHash = hashers[i].out;
    }
    root <== levelHash;
}


