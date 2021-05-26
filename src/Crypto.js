const assert = require('assert')
const crypto = require('crypto')
const ethers = require('ethers')
const ff = require('ffjavascript')
const { babyJub, mimc7, poseidon, eddsa } =require('circomlib')
const stringifyBigInts = ff.utils.stringifyBigInts
const unstringifyBigInts = ff.utils.unstringifyBigInts


const SNARK_FIELD_SIZE = BigInt('21888242871839275222246405745257275088548364400416034343698204186575808495617')

/*
 * Convert a BigInt to a Buffer
 */
const bigInt2Buffer = (i) => {
    return Buffer.from(i.toString(16))
}

/*
 * Convert a Buffer to a BigInt
 */
const buffer2BigInt = (b) => {
    return BigInt('0x' + b.toString('hex'))
}
/*
* inputs : BigInt[]
*/
const hash = (inputs) => { return poseidon(inputs) }


/*
 * Returns a BabyJub-compatible random value. We create it by first generating
 * a random value (initially 256 bits large) modulo the snark field size as
 * described in EIP197. This results in a key size of roughly 253 bits and no
 * more than 254 bits. To prevent modulo bias, we then use this efficient
 * algorithm:
 * http://cvsweb.openbsd.org/cgi-bin/cvsweb/~checkout~/src/lib/libc/crypt/arc4random_uniform.c
 * @return A BabyJub-compatible random value.
 */
const genRandomBabyJubValue = () => {

    // Prevent modulo bias
    //const lim = BigInt('0x10000000000000000000000000000000000000000000000000000000000000000')
    //const min = (lim - SNARK_FIELD_SIZE) % SNARK_FIELD_SIZE
    const min = BigInt('6350874878119819312338956282401532410528162663560392320966563075034087161851')

    let rand
    while (true) {
        rand = BigInt('0x' + crypto.randomBytes(32).toString('hex'))

        if (rand >= min) {
            break
        }
    }

    const privKey = rand % SNARK_FIELD_SIZE
    assert(privKey < SNARK_FIELD_SIZE)

    return privKey
}

/*
 * @return A BabyJub-compatible private key.
 */
const genPrivKey = () => {

    return genRandomBabyJubValue()
}

/*
 * @return A BabyJub-compatible salt.
 */
const genRandomSalt = () => {

    return genRandomBabyJubValue()
}

/*
 * An internal function which formats a random private key to be compatible
 * with the BabyJub curve. This is the format which should be passed into the
 * PublicKey and other circuits.
 */
const formatPrivKeyForBabyJub = (privKey) => {

    // TODO: clarify this explanation
    // https://tools.ietf.org/html/rfc8032
    // Because of the "buff[0] & 0xF8" part which makes sure you have a point
    // with order that 8 divides (^ pruneBuffer)
    // Every point in babyjubjub is of the form: aP + bH, where H has order 8
    // and P has a big large prime order
    // Guaranteeing that any low order points in babyjubjub get deleted
    const sBuff = eddsa.pruneBuffer(
        bigInt2Buffer(
            hash([privKey])
        ).slice(0, 32)
    )

    const s = ff.utils.leBuff2int(sBuff)
    return ff.Scalar.shr(s, 3)
}

/*
 * Losslessly reduces the size of the representation of a public key
 * @param pubKey The public key to pack
 * @return A packed public key
 */
const packPubKey = (pubKey) => {
    return babyJub.packPoint(pubKey)
}

/*
 * Restores the original PubKey from its packed representation
 * @param packed The value to unpack
 * @return The unpacked public key
 */
const unpackPubKey = (packed) => {
    return babyJub.unpackPoint(packed)
}

/*
 * @param privKey A private key generated using genPrivKey()
 * @return A public key associated with the private key
 */
const genPubKey = (privKey) => {
    // Check whether privKey is a field element
    assert(privKey < SNARK_FIELD_SIZE)

    // TODO: check whether privKey is valid (i.e. that the prune buffer step
    // worked)

    const pubKey = babyJub.mulPointEscalar(
        babyJub.Base8,
        formatPrivKeyForBabyJub(privKey),
    )

    // TODO: assert that pubKey is valid
    // TODO: figure out how to check if pubKey is valid

    assert(pubKey.length === 2)
    assert(pubKey[0] < SNARK_FIELD_SIZE)
    assert(pubKey[1] < SNARK_FIELD_SIZE)

    return pubKey
}

const genKeypair = () => {
    const privKey = genPrivKey()
    const pubKey = genPubKey(privKey)

    const Keypair = { privKey, pubKey }

    return Keypair
}


module.exports =  {
    genRandomSalt,
    genPrivKey,
    genPubKey,
    genKeypair,
    stringifyBigInts,
    unstringifyBigInts,
    formatPrivKeyForBabyJub,
    SNARK_FIELD_SIZE,
    bigInt2Buffer,
    buffer2BigInt,
    packPubKey,
    unpackPubKey,
    hash,
}
