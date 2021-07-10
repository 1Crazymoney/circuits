include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/switcher.circom";


template MerkleProof(n_levels) {
    signal input leaf;
    signal input pathIndices; //bitify it to know separate indices
    signal input pathElements[n_levels];
    signal output root;

    component hashers[n_levels];
    component switchers[n_levels];
    component index = Num2Bits(n_levels);
    index.in <== pathIndices;

    var levelHash;
    levelHash = leaf;

    for (var i = 0; i < n_levels; i++) {
        switchers[i] = Switcher();
        switchers[i].L <== levelHash;
        switchers[i].R <== pathElements[i];
        switchers[i].sel <== index.out[i];
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== switchers[i].outL;
        hashers[i].inputs[1] <== switchers[i].outR;
        levelHash = hashers[i].out;
    }
    root <== levelHash;
}


