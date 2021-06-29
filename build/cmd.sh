#! /bin/bash
circom ../circuits/Small.circom --r1cs --wasm -v
snarkjs zkey new Small.r1cs potfinal.ptau tmp0.zkey
snarkjs zkey contribute tmp0.zkey tmp1.zkey --name="Bitcoin Cash Block 689000" -v -e="000000000000000001b1c5085327359337668c6093a80ed4920c8d4f335a5ba9"
snarkjs zkey contribute tmp1.zkey tmp2.zkey --name="Bitcoin Block 689000" -v -e="0000000000000000000831ee26b770d8321e69aa4f2e390ba0367782a765ec6b"
snarkjs zkey beacon tmp2.zkey small_final.zkey 4c742a8b7160d4cc58882d7e7dd11a6234d99e735d2bc12512d6564d1dafddfd 10 -n="Ethereum Block 12727000"
snarkjs zkey export verificationkey small_final.zkey vkey_small.json
rm tmp*

circom ../circuits/Large.circom --r1cs --wasm -v
snarkjs zkey new Large.r1cs potfinal.ptau tmp0.zkey
snarkjs zkey contribute tmp0.zkey tmp1.zkey --name="Bitcoin Cash Block 689000" -v -e="000000000000000001b1c5085327359337668c6093a80ed4920c8d4f335a5ba9"
snarkjs zkey contribute tmp1.zkey tmp2.zkey --name="Bitcoin Block 689000" -v -e="0000000000000000000831ee26b770d8321e69aa4f2e390ba0367782a765ec6b"
snarkjs zkey beacon tmp2.zkey large_final.zkey 4c742a8b7160d4cc58882d7e7dd11a6234d99e735d2bc12512d6564d1dafddfd 10 -n="Ethereum Block 12727000"
snarkjs zkey export verificationkey large_final.zkey vkey_large.json
rm tmp*
