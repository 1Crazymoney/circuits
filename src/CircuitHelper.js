const circom = require('circom')
const path = require('path')


const compileAndLoadCircuit = async (circuitPath) => {
    const circuit = await circom.tester(path.join(__dirname,`../circuits/${circuitPath}`))
    await circuit.loadSymbols()
    return circuit
}

const executeCircuit = async (
    circuit,
    inputs,
) => {

    const witness = await circuit.calculateWitness(inputs, true)
    await circuit.checkConstraints(witness)
    await circuit.loadSymbols()

    return witness
}
const getSignalByName = (
    circuit,
    witness,
    signal,
) => {

    return witness[circuit.symbols[signal].varIdx]
}
module.exports = {
    compileAndLoadCircuit,
    getSignalByName,
    executeCircuit
}
