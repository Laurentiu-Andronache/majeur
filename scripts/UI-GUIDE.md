# UI Developer Guide: Moloch CREATE2 Address Prediction

## TL;DR

You don't need pre-computed hashes. Just use the implementation addresses with the CREATE2 formula.

```typescript
import { predictAllAddresses } from './create2-predictor';

const addresses = predictAllAddresses({
  summonerAddress: '0x...',      // Your deployed Summoner
  molochImplementation: '0x...',  // Get from Summoner.implementation()
  sharesImplementation: '0x...',  // Get from Moloch.sharesImpl()
  badgesImplementation: '0x...',  // Get from Moloch.badgesImpl()
  lootImplementation: '0x...',    // Get from Moloch.lootImpl()
  initHolders: ['0x...'],
  initShares: ['1000000000000000000'], // 1 share in wei
});

// addresses = { moloch, shares, badges, loot }
```

## How CREATE2 Works in Moloch

### The Formula

```
address = keccak256(
  0xff ++
  deployer ++
  salt ++
  keccak256(bytecode)
)[12:]  // last 20 bytes
```

### The Bytecode (Minimal Proxy - 54 bytes)

```
Prefix (20 bytes):  0x602d5f8160095f39f35f5f365f5f37365f73
Implementation (20 bytes): <the implementation address>
Suffix (14 bytes):  0x5af43d5f5f3e6029573d5ffd5b3d5ff3
```

This pattern is constant. Just plug in the implementation address.

### The Salt

**For Moloch DAO:**
```solidity
salt = keccak256(abi.encode(initHolders, initShares, customSalt))
```

**For Tokens (Shares/Badges/Loot):**
```solidity
salt = bytes32(bytes20(molochAddress))
// = molochAddress + "000000000000000000000000"
```

## Complete Implementation

### TypeScript (Recommended)

Use the provided `create2-predictor.ts`:

```typescript
import { predictAllAddresses } from './create2-predictor';

// Get implementation addresses (do this once on app load)
const summoner = new Contract(SUMMONER_ADDRESS, ['function implementation() view returns (address)'], provider);
const molochImpl = await summoner.implementation();

const moloch = new Contract(molochImpl, [
  'function sharesImpl() view returns (address)',
  'function badgesImpl() view returns (address)',
  'function lootImpl() view returns (address)',
], provider);

const config = {
  summonerAddress: SUMMONER_ADDRESS,
  molochImplementation: molochImpl,
  sharesImplementation: await moloch.sharesImpl(),
  badgesImplementation: await moloch.badgesImpl(),
  lootImplementation: await moloch.lootImpl(),
};

// Now predict addresses as user types
function onFormChange(initHolders: string[], initShares: string[]) {
  const predicted = predictAllAddresses({
    ...config,
    initHolders,
    initShares,
  });

  // Show predicted.moloch, predicted.shares, etc
}
```

### JavaScript

Use `simple-create2-predictor.js`:

```javascript
const { predictAllAddresses } = require('./simple-create2-predictor');

const addresses = predictAllAddresses({
  // ... same config as TypeScript
});
```

## Visual Flow

```
User Input:
  initHolders = ["0xAlice", "0xBob"]
  initShares = ["1000000000000000000", "2000000000000000000"]
  customSalt = 0x0000...0000
       │
       ├─────────────────────────────────────────────┐
       │                                             │
       ▼                                             ▼
┌─────────────────┐                          ┌──────────────┐
│ Moloch DAO      │                          │ Bytecode     │
│ Salt Compute    │                          │ Construction │
├─────────────────┤                          ├──────────────┤
│ keccak256(      │                          │ 0x602d...73  │
│   abi.encode(   │                          │ + molochImpl │
│     holders,    │                          │ + 0x5af4...3 │
│     shares,     │                          │ = 54 bytes   │
│     salt        │                          └──────┬───────┘
│   )             │                                 │
│ )               │                                 │
└────────┬────────┘                                 │
         │                                          │
         │            ┌─────────────────────────────┘
         │            │
         ▼            ▼
   ┌─────────────────────────────┐
   │   CREATE2 Formula           │
   ├─────────────────────────────┤
   │ keccak256(                  │
   │   0xff ++                   │
   │   summoner ++               │
   │   salt ++                   │
   │   keccak256(bytecode)       │
   │ )[12:]                      │
   └─────────────┬───────────────┘
                 │
                 ▼
         Moloch DAO Address
                 │
                 ├──────────────────────────────┐
                 │                              │
                 ▼                              ▼
         ┌─────────────┐              ┌─────────────────┐
         │ Token Salt  │              │ Token Bytecode  │
         ├─────────────┤              ├─────────────────┤
         │ moloch +    │              │ 0x602d...73     │
         │ "000...000" │              │ + sharesImpl    │
         │ (24 bytes)  │              │ + 0x5af4...3    │
         └──────┬──────┘              └────────┬────────┘
                │                              │
                └──────────┬───────────────────┘
                           │
                           ▼
                   ┌───────────────┐
                   │ CREATE2       │
                   │ (moloch is    │
                   │  deployer)    │
                   └───────┬───────┘
                           │
                           ▼
                 Shares/Badges/Loot Addresses
```

## Key Points

### 1. No Pre-computed Hashes Needed

The bytecode is built on-the-fly:
```typescript
const bytecode = PROXY_PREFIX + implementation.slice(2) + PROXY_SUFFIX.slice(2);
const initCodeHash = keccak256(bytecode);
```

### 2. Implementation Addresses are Constants

Get them once from the deployed Summoner:
```typescript
// Run once when app loads
const implementations = await getImplementations(SUMMONER_ADDRESS);

// Store in your state/config
// Use for all predictions
```

### 3. Addresses are Deterministic

Same inputs = same outputs. You can:
- Predict before deployment
- Verify after deployment
- Use across chains (if Summoner is at same address)

### 4. The Minimal Proxy Pattern

This is a standard ERC1167-style minimal proxy:
- 54 bytes total
- Delegates all calls to implementation
- Different from standard clones (uses different bytecode pattern)

## Getting Implementation Addresses

### Option 1: Use the helper script

```bash
node src/scripts/get-implementations.js <SUMMONER_ADDRESS> <RPC_URL>
```

### Option 2: Query directly in your app

```typescript
async function getImplementations(summonerAddress: string) {
  const summoner = new Contract(
    summonerAddress,
    ['function implementation() view returns (address)'],
    provider
  );

  const molochImpl = await summoner.implementation();

  const moloch = new Contract(
    molochImpl,
    [
      'function sharesImpl() view returns (address)',
      'function badgesImpl() view returns (address)',
      'function lootImpl() view returns (address)',
    ],
    provider
  );

  return {
    moloch: molochImpl,
    shares: await moloch.sharesImpl(),
    badges: await moloch.badgesImpl(),
    loot: await moloch.lootImpl(),
  };
}
```

## Testing Your Implementation

After predicting, deploy and verify:

```typescript
// 1. Predict
const predicted = predictAllAddresses(config);

// 2. Deploy
const tx = await summoner.summon(...params);
const receipt = await tx.wait();

// 3. Get actual address from NewDAO event
const event = receipt.logs.find(log => {
  return log.topics[0] === summoner.interface.getEvent('NewDAO').topicHash;
});
const actualMoloch = '0x' + event.topics[2].slice(26);

// 4. Verify
console.assert(
  predicted.moloch.toLowerCase() === actualMoloch.toLowerCase(),
  'Address mismatch!'
);

// 5. Verify tokens
const dao = new Contract(actualMoloch, daoAbi, provider);
console.assert(
  predicted.shares.toLowerCase() === (await dao.shares()).toLowerCase(),
  'Shares mismatch!'
);
```

## Common Issues

### Addresses don't match

- ✅ Check implementation addresses are correct
- ✅ Check initHolders and initShares arrays are same length
- ✅ Check customSalt matches what you pass to summon()
- ✅ Verify all addresses are lowercase or properly checksummed

### "Cannot compute address" error

- ✅ Ensure ethers.js is installed: `npm install ethers`
- ✅ Check all addresses are valid (20 bytes hex)
- ✅ Check initShares are valid uint256 strings

## Files You Need

1. **`create2-predictor.ts`** (TypeScript) or **`simple-create2-predictor.js`** (JavaScript)
   - Main prediction logic
   - Copy this into your frontend

2. **`get-implementations.js`** (optional)
   - Helper to fetch implementation addresses
   - Can run as script or import as module

That's it! No other files needed.

## Reference

- Summoner: `src/Moloch.sol:2054-2110`
- CREATE2 for Moloch: `src/Moloch.sol:2066-2083`
- CREATE2 for tokens: `src/Moloch.sol:249-261`
- Minimal proxy bytecode: `src/Moloch.sol:250-260`

## Questions?

See `CREATE2-EXPLAINED.md` for detailed explanation of how CREATE2 works.
