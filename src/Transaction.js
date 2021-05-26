const {babyJub} = require("circomlib")
const MerkleTree = require("./MerkleTree");
const { soliditySha256 } = require("ethers").utils;
const {BigNumber} = require("ethers")
const {
  stringifyBigInts,
  hash,
  genKeypair,
  genRandomSalt,
  formatPrivKeyForBabyJub,
  genPubKey,
  SNARK_FIELD_SIZE
} = require("./Crypto");


function createNote(value, tokenField) {
  kp = genKeypair();
  return {
  PrivateKey:  kp.privKey,
  PublicKey: kp.pubKey,
  Value: value, 
  Serial: genRandomSalt(),
  TokenField: tokenField
  }
}
function commitNote(note){
  return hash([...note.PublicKey,note.Serial,note.Value,note.TokenField])
}

function getNullifier(note) {
  return hash([
    formatPrivKeyForBabyJub(note.PrivateKey),
    note.Serial,
  ]);
}

function createTransaction(nInputs, mOutputs, adaptID, merkleTree, depositAmount, withdrawAmount, notesIn, notesOut, outputEthAddress, tokenField, outputTokenField){
  
  proofs = notesIn.map(x=> merkleTree.generateProof(commitNote(x)));
  
  //add dummy proofs
  dummyTree = new MerkleTree(16);
  for(var i=notesIn.length; i<nInputs; i++)
    {
      notesIn.push(createNote(0n, tokenField))
      commit = commitNote(notesIn[i])
      dummyTree.insertLeaves([commit])
      proofs.push(dummyTree.generateProof(commit))
    }
  for(var i=notesOut.length; i<mOutputs; i++)
    notesOut.push(createNote(0n, tokenField))
  pathIndices =proofs.map(x=> BigInt("0b"+ x.proof.map((x) => x.position).reverse().join('')))
  pathElements = proofs.map(x=>x.proof.map((x) => x.pair));
  ciphertextHash = genRandomSalt();// should encrypt with aes then % SNARK_field_size
  types=[]
  for(var i=0;i<(7+nInputs+mOutputs); i++)
    types.push('uint256')
  hashOfInputs =BigInt( soliditySha256(types, [adaptID, depositAmount, withdrawAmount,
    outputTokenField, outputEthAddress, merkleTree.root, ...(notesIn.map(x=>getNullifier(x))),
     ...(notesOut.map(x=>commitNote(x))), ciphertextHash]))%SNARK_FIELD_SIZE

  const circuitInputs = stringifyBigInts({
    hashOfInputs,
    tokenField,
    adaptID,
    depositAmount,
    withdrawAmount,
    ciphertextHash,
    outputTokenField,
    outputEthAddress,
    //join
    serialsIn: notesIn.map(x=>x.Serial),
    valuesIn: notesIn.map(x=>x.Value),
    spendingKeys: notesIn.map(x=>formatPrivKeyForBabyJub(x.PrivateKey)),
    nullifiers: notesIn.map(x=>getNullifier(x)),
    merkleRoot: merkleTree.root,
    pathElements,
    pathIndices,
    //split
    recipientPK:notesOut.map(x=>x.PublicKey),
    serialsOut: notesOut.map(x=>x.Serial),
    valuesOut: notesOut.map(x=>x.Value),
    commitmentsOut: notesOut.map(x=>commitNote(x)), 
  });
  return circuitInputs;
}

module.exports={
  createNote,
  createTransaction,
  commitNote
}