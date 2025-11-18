/**
 * Get Implementation Addresses from Deployed Summoner
 *
 * This script fetches all the necessary implementation addresses from a deployed
 * Summoner contract that are needed for address prediction.
 *
 * Prerequisites:
 *   npm install ethers
 *
 * Usage:
 *   node get-implementations.js <SUMMONER_ADDRESS> <RPC_URL>
 *
 * Example:
 *   node get-implementations.js 0x1234... https://eth-mainnet.g.alchemy.com/v2/YOUR-KEY
 */

let ethers;
try {
    ethers = require('ethers');
} catch (e) {
    console.error('Error: ethers.js not found. Please install it:');
    console.error('  npm install ethers');
    process.exit(1);
}

// ABIs (minimal - only what we need)
const SUMMONER_ABI = [
    'function implementation() external view returns (address)',
    'function daos(uint256) external view returns (address)',
    'event NewDAO(address indexed summoner, address indexed dao)'
];

const MOLOCH_ABI = [
    'function sharesImpl() external view returns (address)',
    'function badgesImpl() external view returns (address)',
    'function lootImpl() external view returns (address)',
    'function SUMMONER() external view returns (address)'
];

/**
 * Fetch all implementation addresses from a deployed Summoner
 */
async function getImplementations(summonerAddress, rpcUrl) {
    const provider = new ethers.JsonRpcProvider(rpcUrl);

    // Connect to Summoner
    const summoner = new ethers.Contract(summonerAddress, SUMMONER_ABI, provider);

    console.log('Fetching implementation addresses...\n');
    console.log('Summoner:', summonerAddress);

    // Get Moloch implementation
    const molochImpl = await summoner.implementation();
    console.log('Moloch Implementation:', molochImpl);

    // Connect to Moloch implementation
    const moloch = new ethers.Contract(molochImpl, MOLOCH_ABI, provider);

    // Get token implementations
    const sharesImpl = await moloch.sharesImpl();
    const badgesImpl = await moloch.badgesImpl();
    const lootImpl = await moloch.lootImpl();

    console.log('Shares Implementation:', sharesImpl);
    console.log('Badges Implementation:', badgesImpl);
    console.log('Loot Implementation:', lootImpl);

    const result = {
        summonerAddress,
        molochImplementation: molochImpl,
        sharesImplementation: sharesImpl,
        badgesImplementation: badgesImpl,
        lootImplementation: lootImpl
    };

    console.log('\nJSON Configuration:');
    console.log(JSON.stringify(result, null, 2));

    return result;
}

/**
 * Get all deployed DAOs from a Summoner
 */
async function getDeployedDAOs(summonerAddress, rpcUrl, startBlock = 0) {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const summoner = new ethers.Contract(summonerAddress, SUMMONER_ABI, provider);

    console.log('\nFetching deployed DAOs...\n');

    // Query NewDAO events
    const filter = summoner.filters.NewDAO();
    const events = await summoner.queryFilter(filter, startBlock);

    const daos = events.map((event, index) => {
        return {
            index,
            summoner: event.args[0],
            dao: event.args[1],
            blockNumber: event.blockNumber,
            transactionHash: event.transactionHash
        };
    });

    console.log(`Found ${daos.length} deployed DAOs:\n`);
    daos.forEach(dao => {
        console.log(`DAO #${dao.index}:`);
        console.log(`  Address: ${dao.dao}`);
        console.log(`  Summoned by: ${dao.summoner}`);
        console.log(`  Block: ${dao.blockNumber}`);
        console.log(`  Tx: ${dao.transactionHash}`);
        console.log();
    });

    return daos;
}

/**
 * Get token addresses for a deployed DAO
 */
async function getDAOTokens(daoAddress, rpcUrl) {
    const provider = new ethers.JsonRpcProvider(rpcUrl);

    const DAO_ABI = [
        'function shares() external view returns (address)',
        'function badges() external view returns (address)',
        'function loot() external view returns (address)',
        'function name() external view returns (string)',
        'function symbol() external view returns (string)'
    ];

    const dao = new ethers.Contract(daoAddress, DAO_ABI, provider);

    const [name, symbol, shares, badges, loot] = await Promise.all([
        dao.name(),
        dao.symbol(),
        dao.shares(),
        dao.badges(),
        dao.loot()
    ]);

    console.log(`\nDAO: ${name} (${symbol})`);
    console.log('Address:', daoAddress);
    console.log('Shares Token:', shares);
    console.log('Badges Token:', badges);
    console.log('Loot Token:', loot);

    return { daoAddress, name, symbol, shares, badges, loot };
}

// CLI interface
async function main() {
    const args = process.argv.slice(2);

    if (args.length < 2) {
        console.log('Usage: node get-implementations.js <SUMMONER_ADDRESS> <RPC_URL> [COMMAND]');
        console.log('\nCommands:');
        console.log('  implementations (default) - Get implementation addresses');
        console.log('  daos - List all deployed DAOs');
        console.log('  tokens <DAO_ADDRESS> - Get token addresses for a specific DAO');
        console.log('\nExamples:');
        console.log('  node get-implementations.js 0x1234... https://eth-mainnet.g.alchemy.com/v2/KEY');
        console.log('  node get-implementations.js 0x1234... https://eth-mainnet.g.alchemy.com/v2/KEY daos');
        console.log('  node get-implementations.js 0x1234... https://eth-mainnet.g.alchemy.com/v2/KEY tokens 0x5678...');
        process.exit(1);
    }

    const [address, rpcUrl, command = 'implementations', ...extraArgs] = args;

    try {
        switch (command) {
            case 'implementations':
                await getImplementations(address, rpcUrl);
                break;

            case 'daos':
                await getImplementations(address, rpcUrl);
                await getDeployedDAOs(address, rpcUrl);
                break;

            case 'tokens':
                if (!extraArgs[0]) {
                    console.error('Error: DAO address required for tokens command');
                    process.exit(1);
                }
                await getDAOTokens(extraArgs[0], rpcUrl);
                break;

            default:
                console.error(`Unknown command: ${command}`);
                process.exit(1);
        }
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

// Run if executed directly
if (require.main === module) {
    main();
}

// Export functions
module.exports = {
    getImplementations,
    getDeployedDAOs,
    getDAOTokens
};
