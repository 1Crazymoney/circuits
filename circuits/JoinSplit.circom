include "./base/MerkleTree.circom";
include "../node_modules/circomlib/circuits/babyjub.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "./base/HashInputs.circom";


template JoinSplit(nInputs, mOutputs, merkleTreeDepth) {

    signal input hashOfInputs;

    //shared
    signal private input tokenField;   
    signal private input adaptID; //public
    signal private input depositAmount; //public
    signal private input withdrawAmount; //public
    signal private input outputTokenField; //public if (deposit || withdraw) then outputTokenField = tokenField
    signal private input outputEthAddress; //public 

    //join
    signal private input serialsIn[nInputs];
    signal private input valuesIn[nInputs];
    signal private input spendingKeys[nInputs];
    signal private input merkleRoot; //public   
    signal private input pathElements[nInputs][merkleTreeDepth];
    signal private input pathIndices[nInputs];
    signal private input nullifiers[nInputs]; //public

    //split
    signal private input recipientPK[mOutputs][2]; 
    signal private input serialsOut[mOutputs];
    signal private input valuesOut[mOutputs];
    signal private input commitmentsOut[mOutputs]; //public 
    signal private input ciphertextHash; //public


    //verify public inputs hash
    component hashPublicInputs = HashInputs(nInputs, mOutputs);
    hashPublicInputs.in[0] <== adaptID;
    hashPublicInputs.in[1] <== depositAmount;
    hashPublicInputs.in[2] <== withdrawAmount;
    hashPublicInputs.in[3] <== outputTokenField;
    hashPublicInputs.in[4] <== outputEthAddress;
    hashPublicInputs.in[5] <== merkleRoot;
    for(var i=0; i<nInputs; i++)
        hashPublicInputs.in[6+i] <== nullifiers[i];
    for(var i=0; i<mOutputs; i++)
        hashPublicInputs.in[6+nInputs+i] <== commitmentsOut[i];
    hashPublicInputs.in[6+nInputs+mOutputs] <== ciphertextHash;

    hashPublicInputs.out === hashOfInputs;


    var inputsTotal = depositAmount;
    var outputsTotal = withdrawAmount;

    component pkDeriveInput[nInputs];
    component hasherInputNotes[nInputs];
    component hasherNullifier[nInputs];
    component merkle[nInputs];
    component isDummyInput[nInputs];

    //verify input notes
    for(var i =0; i<nInputs; i++){
        
        //derive pubkey from the spending key
        pkDeriveInput[i] = BabyPbk();
        pkDeriveInput[i].in <== spendingKeys[i]

        //verify nullifier
        hasherNullifier[i] = Poseidon(2);
        hasherNullifier[i].inputs[0] <== spendingKeys[i];
        hasherNullifier[i].inputs[1] <== serialsIn[i];
        hasherNullifier[i].out === nullifiers[i];

        //compute note commitment
        hasherInputNotes[i] = Poseidon(5);
        hasherInputNotes[i].inputs[0] <== pkDeriveInput[i].Ax;
        hasherInputNotes[i].inputs[1] <== pkDeriveInput[i].Ay;        
        hasherInputNotes[i].inputs[2] <== serialsIn[i];
        hasherInputNotes[i].inputs[3] <== valuesIn[i];
        hasherInputNotes[i].inputs[4] <== tokenField;

        //verify Merkle proof on the note commitment
        merkle[i] = MerkleTree(merkleTreeDepth);
        merkle[i].leaf <== hasherInputNotes[i].out;
        merkle[i].pathIndices <== pathIndices[i];
        for(var j=0; j< merkleTreeDepth; j++) {
            merkle[i].pathElements[j] <== pathElements[i][j];
        }

        //dummy note if value = 0
        isDummyInput[i] = IsZero();
        isDummyInput[i].in <== valuesIn[i];

        //Check merkle proof verification if NOT isDummyInput
        (merkle[i].root - merkleRoot)*(1-isDummyInput[i].out) === 0;

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
        hasherOutputNotes[i].inputs[2] <== serialsOut[i];
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
    outputTokenField === tokenField * (1-isShieldedTransaction.out); 
}
