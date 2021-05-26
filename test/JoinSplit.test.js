const { expect } = require("chai");
const fs = require("fs")
const snarkjs = require("snarkjs")
const{
  commitNote,
  createNote,
  createTransaction
} =require("../src/Transaction");

const MerkleTree = require("../src/MerkleTree");
const {compileAndLoadCircuit, executeCircuit} = require("../src/CircuitHelper");

describe("JoinSplit", () => {

  it("Test 2x3", async () => {
    merkleTree = new MerkleTree(16);
    depositAmount = 0n
    withdrawAmount = 0n;
    tokenField =1n;
    outputTokenField =0n;
    address = 0n;
    adaptID = 5n;

    notesIn= [createNote(8n, tokenField)];
    merkleTree.insertLeaves(notesIn.map(x=>commitNote(x)))
    notesOut = [createNote(7n, tokenField), createNote(1n,tokenField)]
    circuitInputs = createTransaction(2, 3, adaptID, merkleTree, depositAmount, withdrawAmount, notesIn, notesOut, address, tokenField, outputTokenField)
    //  const circuit = await compileAndLoadCircuit("./Small.circom");
    //  await executeCircuit(circuit, circuitInputs);
    //  return
    console.time("Small Proving Time");
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
      circuitInputs,
      "./build/Small.wasm",
      "./build/small_final.zkey"
    );
    console.timeEnd("Small Proving Time");
    vkey = JSON.parse(fs.readFileSync("./build/vkey_small.json"));
    const res = await snarkjs.groth16.verify(vkey, publicSignals, proof);
    expect(res).to.equal(true);
  }).timeout(10000000);

});
