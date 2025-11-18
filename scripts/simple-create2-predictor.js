/**
 * Simple CREATE2 Address Predictor for Moloch
 *
 * This is the minimal implementation - all you need is the implementation addresses.
 * No pre-computed hashes required - we compute everything from the implementation address.
 *
 * Prerequisites:
 *   npm install ethers
 *
 * Usage in your UI:
 *   const { predictAllAddresses } = require('./simple-create2-predictor');
 */

let ethers;
try {
    ethers = require('ethers');
} catch (e) {
    console.error('Error: ethers.js not found. Please install it:');
    console.error('  npm install ethers');
    process.exit(1);
}

const { keccak256, concat, AbiCoder } = ethers;

/**
 * Minimal Proxy Bytecode Pattern
 * This is the ERC1967-style minimal proxy used by Moloch
 *
 * Assembly pattern from Moloch.sol:
 *   mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73)
 *   mstore(0x14, implementation)
 *   mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3)
 *   create2(value, 0x0e, 0x36, salt)  // deploy 54 bytes starting at offset 0x0e
 */
const PROXY_BYTECODE = {
    prefix: '0x602d5f8160095f39f35f5f365f5f37365f73',  // 20 bytes
    suffix: '0x5af43d5f5f3e6029573d5ffd5b3d5ff3'       // 14 bytes
    // Total: 20 + 20 (implementation) + 14 = 54 bytes
};

/**
 * Build the complete minimal proxy bytecode for a given implementation
 */
function buildProxyBytecode(implementationAddress) {
    // Remove 0x prefix and ensure lowercase
    const impl = implementationAddress.toLowerCase().replace('0x', '');

    return PROXY_BYTECODE.prefix + impl + PROXY_BYTECODE.suffix.replace('0x', '');
}

/**
 * Compute CREATE2 address
 * Formula: keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))[12:]
 */
function computeCreate2Address(deployerAddress, salt, bytecode) {
    // Compute init code hash
    const initCodeHash = keccak256(bytecode);

    // Build CREATE2 input: 0xff ++ deployer ++ salt ++ initCodeHash
    const create2Input = concat([
        '0xff',
        deployerAddress,
        salt,
        initCodeHash
    ]);

    // Hash and take last 20 bytes
    const hash = keccak256(create2Input);
    return '0x' + hash.slice(-40);
}

/**
 * Compute salt for Moloch DAO deployment
 * Formula: keccak256(abi.encode(initHolders, initShares, customSalt))
 */
function computeMolochSalt(initHolders, initShares, customSalt) {
    const abiCoder = AbiCoder.defaultAbiCoder();
    const encoded = abiCoder.encode(
        ['address[]', 'uint256[]', 'bytes32'],
        [initHolders, initShares, customSalt]
    );
    return keccak256(encoded);
}

/**
 * Compute salt for token clones
 * Formula: bytes32(bytes20(molochAddress))
 * In practice: molochAddress padded with 24 zero bytes on the right
 */
function computeTokenSalt(molochAddress) {
    const addr = molochAddress.toLowerCase().replace('0x', '');
    return '0x' + addr + '000000000000000000000000';
}

/**
 * MAIN FUNCTION: Predict all deployment addresses
 *
 * This is all your UI needs!
 */
function predictAllAddresses({
    summonerAddress,
    molochImplementation,
    sharesImplementation,
    badgesImplementation,
    lootImplementation,
    initHolders,
    initShares,
    customSalt = '0x0000000000000000000000000000000000000000000000000000000000000000'
}) {
    // Step 1: Predict Moloch DAO address
    const molochBytecode = buildProxyBytecode(molochImplementation);
    const molochSalt = computeMolochSalt(initHolders, initShares, customSalt);
    const molochAddress = computeCreate2Address(summonerAddress, molochSalt, molochBytecode);

    // Step 2: Predict token addresses (they use Moloch address as deployer)
    const tokenSalt = computeTokenSalt(molochAddress);

    const sharesBytecode = buildProxyBytecode(sharesImplementation);
    const sharesAddress = computeCreate2Address(molochAddress, tokenSalt, sharesBytecode);

    const badgesBytecode = buildProxyBytecode(badgesImplementation);
    const badgesAddress = computeCreate2Address(molochAddress, tokenSalt, badgesBytecode);

    const lootBytecode = buildProxyBytecode(lootImplementation);
    const lootAddress = computeCreate2Address(molochAddress, tokenSalt, lootBytecode);

    return {
        moloch: molochAddress,
        shares: sharesAddress,
        badges: badgesAddress,
        loot: lootAddress
    };
}

// ============================================================================
// Example Usage
// ============================================================================

function example() {
    console.log('CREATE2 Address Prediction for Moloch\n');
    console.log('This shows how the CREATE2 formula works with the minimal proxy pattern.\n');

    // Example configuration
    const config = {
        // These are your deployed contract addresses
        summonerAddress: '0x0000000000000000000000000000000000000001',
        molochImplementation: '0x0000000000000000000000000000000000000002',
        sharesImplementation: '0x0000000000000000000000000000000000000003',
        badgesImplementation: '0x0000000000000000000000000000000000000004',
        lootImplementation: '0x0000000000000000000000000000000000000005',

        // Summoner parameters
        initHolders: [
            '0x1234567890123456789012345678901234567890',
            '0x2234567890123456789012345678901234567890'
        ],
        initShares: [
            '1000000000000000000',  // 1 share
            '2000000000000000000'   // 2 shares
        ],
        customSalt: '0x0000000000000000000000000000000000000000000000000000000000000000'
    };

    console.log('Configuration:');
    console.log('==============\n');
    console.log('Summoner:', config.summonerAddress);
    console.log('Moloch Impl:', config.molochImplementation);
    console.log('Shares Impl:', config.sharesImplementation);
    console.log('Badges Impl:', config.badgesImplementation);
    console.log('Loot Impl:', config.lootImplementation);
    console.log('\nInit Holders:', config.initHolders);
    console.log('Init Shares:', config.initShares);
    console.log('Custom Salt:', config.customSalt);

    console.log('\n\nHow CREATE2 Works:');
    console.log('==================\n');

    // Show the bytecode construction
    console.log('1. Build Minimal Proxy Bytecode:');
    console.log('   Pattern: prefix (20 bytes) + implementation (20 bytes) + suffix (14 bytes) = 54 bytes');
    console.log('   Prefix:', PROXY_BYTECODE.prefix);
    console.log('   Suffix:', PROXY_BYTECODE.suffix);
    const molochBytecode = buildProxyBytecode(config.molochImplementation);
    console.log('   Moloch Bytecode:', molochBytecode);
    console.log('   Length:', (molochBytecode.length - 2) / 2, 'bytes');

    // Show salt computation
    console.log('\n2. Compute Salt:');
    console.log('   For Moloch: keccak256(abi.encode(initHolders, initShares, customSalt))');
    const molochSalt = computeMolochSalt(config.initHolders, config.initShares, config.customSalt);
    console.log('   Moloch Salt:', molochSalt);

    // Show CREATE2 formula
    console.log('\n3. Apply CREATE2 Formula:');
    console.log('   address = keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))[12:]');
    console.log('   Init Code Hash:', keccak256(molochBytecode));

    // Predict all addresses
    console.log('\n\nPredicted Addresses:');
    console.log('====================\n');

    const result = predictAllAddresses(config);

    console.log('Moloch DAO:', result.moloch);
    console.log('Shares Token:', result.shares);
    console.log('Badges Token:', result.badges);
    console.log('Loot Token:', result.loot);

    console.log('\n\nToken Salt Explanation:');
    console.log('=======================\n');
    console.log('Tokens use the Moloch address as salt (padded to 32 bytes):');
    const tokenSalt = computeTokenSalt(result.moloch);
    console.log('Token Salt:', tokenSalt);
    console.log('           ', result.moloch + '000000000000000000000000');
    console.log('                                       └── 24 zero bytes padding');
}

if (require.main === module) {
    example();
}

// ============================================================================
// Exports
// ============================================================================

module.exports = {
    // Main function - this is all you need!
    predictAllAddresses,

    // Individual helpers if you need them
    buildProxyBytecode,
    computeCreate2Address,
    computeMolochSalt,
    computeTokenSalt,

    // Constants
    PROXY_BYTECODE
};
