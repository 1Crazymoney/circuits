#! /bin/bash
if [ ! -f "potfinal.ptau" ]; then
snarkjs powersoftau new bn128 20 pot0.ptau -v
snarkjs powersoftau contribute pot0.ptau pot1.ptau --name="First contribution" -v -e="random text"
snarkjs powersoftau contribute pot1.ptau pot2.ptau --name="Second contribution" -v -e="some random text"
snarkjs powersoftau beacon pot2.ptau potbeacon.ptau 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon"
snarkjs powersoftau prepare phase2 potbeacon.ptau potfinal.ptau -v
fi

circom ../circuits/Small.circom --r1cs --wasm -v
snarkjs zkey new Small.r1cs potfinal.ptau tmp0.zkey
snarkjs zkey contribute tmp0.zkey tmp1.zkey --name="1st Contributor Name" -v -e="more random text"
snarkjs zkey contribute tmp1.zkey tmp2.zkey --name="Second contribution Name" -v -e="Another random entropy"
snarkjs zkey beacon tmp2.zkey small_final.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
snarkjs zkey export verificationkey small_final.zkey vkey_small.json
snarkjs zkey export solidityverifier small_final.zkey verifier_small.sol
rm tmp*

circom ../circuits/Large.circom --r1cs --wasm -v
snarkjs zkey new LArge.r1cs potfinal.ptau tmp0.zkey
snarkjs zkey contribute tmp0.zkey tmp1.zkey --name="1st Contributor Name" -v -e="more random text"
snarkjs zkey contribute tmp1.zkey tmp2.zkey --name="Second contribution Name" -v -e="Another random entropy"
snarkjs zkey beacon tmp2.zkey large_final.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
snarkjs zkey export verificationkey large_final.zkey vkey_small.json
snarkjs zkey export solidityverifier large_final.zkey verifier_large.sol
rm tmp*