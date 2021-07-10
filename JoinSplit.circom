include "./base/MerkleProof.circom";
include "./node_modules/circomlib/circuits/babyjub.circom";
include "./node_modules/circomlib/circuits/poseidon.circom";
include "./node_modules/circomlib/circuits/comparators.circom";
include "./node_modules/circomlib/circuits/gates.circom";
include "./node_modules/circomlib/circuits/mux1.circom";
include "./base/HashInputs.circom";


template JoinSplit(nInputs, mOutputs, MerkleTreeDepth) {

    signal input hashOfInputs;

    //shared
    signal private input tokenField;   
    signal private input adaptID; //public
    signal private input depositAmount; //public
    signal private input withdrawAmount; //public
    signal private input outputTokenField; //public if (deposit || withdraw) then outputTokenField = tokenField
    signal private input outputEthAddress; //public 

    //join
    signal private input randomIn[nInputs];
    signal private input valuesIn[nInputs];
    signal private input spendingKeys[nInputs];
    signal private input treeNumber; //public
    signal private input merkleRoot; //public   
    signal private input pathElements[nInputs][MerkleTreeDepth];
    signal private input pathIndices[nInputs];
    signal private input nullifiers[nInputs]; //public

    //split
    signal private input recipientPK[mOutputs][2]; 
    signal private input randomOut[mOutputs];
    signal private input valuesOut[mOutputs];
    signal private input commitmentsOut[mOutputs]; //public 
    signal private input ciphertextHash; //public


    //verify public inputs hash
    //number of public input = 8 fixed parameters + nInputs + mOutputs
    var size = 8 + nInputs + mOutputs;
    component hashPublicInputs = HashInputs(size);
    hashPublicInputs.in[0] <== adaptID;
    hashPublicInputs.in[1] <== depositAmount;
    hashPublicInputs.in[2] <== withdrawAmount;
    hashPublicInputs.in[3] <== outputTokenField;
    hashPublicInputs.in[4] <== outputEthAddress;
    hashPublicInputs.in[5] <== treeNumber;
    hashPublicInputs.in[6] <== merkleRoot;
    for(var i=0; i<nInputs; i++)
        hashPublicInputs.in[7+i] <== nullifiers[i];
    for(var i=0; i<mOutputs; i++)
        hashPublicInputs.in[7+nInputs+i] <== commitmentsOut[i];
    hashPublicInputs.in[7+nInputs+mOutputs] <== ciphertextHash;

    hashPublicInputs.out === hashOfInputs;


    var inputsTotal = depositAmount;
    var outputsTotal = withdrawAmount;

    component pkDeriveInput[nInputs];
    component hasherInputNotes[nInputs];
    component hasherNullifier[nInputs];
    component merkle[nInputs];
    component isDummyInput[nInputs];
    component checkEqualIfIsNotDummy[nInputs];

    //verify input notes
    for(var i =0; i<nInputs; i++){
        
        //derive pubkey from the spending key
        pkDeriveInput[i] = BabyPbk();
        pkDeriveInput[i].in <== spendingKeys[i]

        //verify nullifier
        hasherNullifier[i] = Poseidon(3);
        hasherNullifier[i].inputs[0] <== spendingKeys[i];
        hasherNullifier[i].inputs[1] <== treeNumber;
        hasherNullifier[i].inputs[2] <== pathIndices[i];
        hasherNullifier[i].out === nullifiers[i];

        //compute note commitment
        hasherInputNotes[i] = Poseidon(5);
        hasherInputNotes[i].inputs[0] <== pkDeriveInput[i].Ax;
        hasherInputNotes[i].inputs[1] <== pkDeriveInput[i].Ay;        
        hasherInputNotes[i].inputs[2] <== randomIn[i];
        hasherInputNotes[i].inputs[3] <== valuesIn[i];
        hasherInputNotes[i].inputs[4] <== tokenField;

        //verify Merkle proof on the note commitment
        merkle[i] = MerkleProof(MerkleTreeDepth);
        merkle[i].leaf <== hasherInputNotes[i].out;
        merkle[i].pathIndices <== pathIndices[i];
        for(var j=0; j< MerkleTreeDepth; j++) {
            merkle[i].pathElements[j] <== pathElements[i][j];
        }

        //dummy note if value = 0
        isDummyInput[i] = IsZero();
        isDummyInput[i].in <== valuesIn[i];

        //Check merkle proof verification if NOT isDummyInput
        checkEqualIfIsNotDummy[i] = ForceEqualIfEnabled();
        checkEqualIfIsNotDummy[i].enabled <== 1-isDummyInput[i].out;
        checkEqualIfIsNotDummy[i].in[0] <== merkleRoot;
        checkEqualIfIsNotDummy[i].in[1] <== merkle[i].root;

        //no overflow as valueIn[i] is always 120-bit, and nInputs is assumed to be less than 100.
        //a check on Output note range is sufficient as input notes are old output notes
        //accumulates input amounts
        inputsTotal += valuesIn[i] 
    }


    component hasherOutputNotes[mOutputs];
    component isValueOut120Bits[mOutputs];

    //verify output notes
    for(var i =0; i<mOutputs; i++){
        //verify valueOut is 120 bits
        isValueOut120Bits[i] = Num2Bits(120);
        isValueOut120Bits[i].in <== valuesOut[i];

        //verify commitment of output note
        hasherOutputNotes[i] = Poseidon(5);
        hasherOutputNotes[i].inputs[0] <== recipientPK[i][0];
        hasherOutputNotes[i].inputs[1] <== recipientPK[i][1];
        hasherOutputNotes[i].inputs[2] <== randomOut[i];
        hasherOutputNotes[i].inputs[3] <== valuesOut[i];
        hasherOutputNotes[i].inputs[4] <== tokenField;
        hasherOutputNotes[i].out === commitmentsOut[i];

        //accumulates output amount
        outputsTotal += valuesOut[i] //no overflow as long as mOutputs is small e.g. 3
    }

    //check that inputs and outputs amounts are equal
    inputsTotal === outputsTotal;

    //enforce that outputTokenField is zero if deposit and withdraw are zeroes (i.e. shielded tx), otherwise it is equal to tokenField
    component isShieldedTransaction = IsZero();
    //values enforced on smart contract to be 120-bits so adding them will be less than field modulus
    isShieldedTransaction.in <== depositAmount + withdrawAmount; 
    component checkEqualTokenFieldIfIsNotShieldedTransaction = ForceEqualIfEnabled();
    checkEqualTokenFieldIfIsNotShieldedTransaction.enabled <== 1-isShieldedTransaction.out;
    checkEqualTokenFieldIfIsNotShieldedTransaction.in[0] <== tokenField;
    checkEqualTokenFieldIfIsNotShieldedTransaction.in[1] <== outputTokenField;
}
