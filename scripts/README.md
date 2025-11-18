# Moloch CREATE2 Address Predictor

Predict Moloch DAO deployment addresses using CREATE2 - no pre-computed hashes needed.

## Quick Start

### For UI Developers

**Step 1:** Copy `create2-predictor.ts` (or `simple-create2-predictor.js`) into your project

**Step 2:** Get implementation addresses from your deployed Summoner:

```bash
node get-implementations.js <SUMMONER_ADDRESS> <RPC_URL>
```

**Step 3:** Use in your app:

```typescript
import { predictAllAddresses } from './create2-predictor';

const addresses = predictAllAddresses({
  summonerAddress: '0x...',
  molochImplementation: '0x...',
  sharesImplementation: '0x...',
  badgesImplementation: '0x...',
  lootImplementation: '0x...',
  initHolders: ['0xAlice', '0xBob'],
  initShares: ['1000000000000000000', '2000000000000000000'],
});

// addresses = { moloch, shares, badges, loot }
```

**See UI-GUIDE.md for complete examples.**

## Files

### Core Implementation
- **`create2-predictor.ts`** - TypeScript implementation (recommended)
- **`simple-create2-predictor.js`** - JavaScript/Node.js implementation

### Documentation
- **`UI-GUIDE.md`** - **Start here** - Complete guide for UI developers
- **`CREATE2-EXPLAINED.md`** - Deep dive into how CREATE2 works
- **`README.md`** - This file

### Utilities
- **`get-implementations.js`** - Fetch implementation addresses from deployed Summoner
- **`DeploymentPredictor.sol`** - Solidity helper for on-chain predictions

## How It Works

### The CREATE2 Formula

```
address = keccak256(
  0xff ++ deployer ++ salt ++ keccak256(bytecode)
)[12:]  // last 20 bytes
```

### Minimal Proxy Bytecode (54 bytes)

```
Prefix (20 bytes):  0x602d5f8160095f39f35f5f365f5f37365f73
Implementation:     <20 bytes - the implementation address>
Suffix (14 bytes):  0x5af43d5f5f3e6029573d5ffd5b3d5ff3
```

### Salts

**Moloch DAO:**
```solidity
salt = keccak256(abi.encode(initHolders, initShares, customSalt))
```

**Tokens (Shares/Badges/Loot):**
```solidity
salt = bytes32(bytes20(molochAddress))
// = molochAddress + "000000000000000000000000"
```

## Key Concepts

1. **No pre-computed hashes needed** - Build bytecode on-the-fly from implementation address
2. **Implementation addresses are constants** - Get once from Summoner, use forever
3. **Deterministic** - Same inputs always produce same address
4. **Works across chains** - If Summoner is at same address

## Architecture

```
Summoner (deployed once)
  │
  └─ Moloch Implementation
      ├─ Shares Implementation
      ├─ Badges Implementation
      └─ Loot Implementation

For each summon():
  │
  ├─ Moloch DAO (CREATE2)
  │   ├─ Shares (CREATE2)
  │   ├─ Badges (CREATE2)
  │   └─ Loot (CREATE2)
```

## Getting Implementation Addresses

### Option 1: Script

```bash
node get-implementations.js <SUMMONER_ADDRESS> <RPC_URL>
```

### Option 2: Directly in your app

```typescript
const summoner = new Contract(
  SUMMONER_ADDRESS,
  ['function implementation() view returns (address)'],
  provider
);
const molochImpl = await summoner.implementation();

const moloch = new Contract(molochImpl, [
  'function sharesImpl() view returns (address)',
  'function badgesImpl() view returns (address)',
  'function lootImpl() view returns (address)',
], provider);

const implementations = {
  moloch: molochImpl,
  shares: await moloch.sharesImpl(),
  badges: await moloch.badgesImpl(),
  loot: await moloch.lootImpl(),
};
```

## Testing Predictions

```typescript
// 1. Predict
const predicted = predictAllAddresses(config);

// 2. Deploy
const tx = await summoner.summon(...params);
const receipt = await tx.wait();

// 3. Verify
const actualMoloch = getAddressFromEvent(receipt);
console.assert(
  predicted.moloch.toLowerCase() === actualMoloch.toLowerCase()
);
```

## React Example

```typescript
import { useState, useEffect } from 'react';
import { predictAllAddresses } from './create2-predictor';

function SummonForm({ implementations }) {
  const [holders, setHolders] = useState(['']);
  const [shares, setShares] = useState(['']);
  const [predicted, setPredicted] = useState(null);

  useEffect(() => {
    if (holders.length && shares.length) {
      setPredicted(predictAllAddresses({
        ...implementations,
        initHolders: holders,
        initShares: shares,
      }));
    }
  }, [holders, shares, implementations]);

  return (
    <div>
      {/* Form inputs */}
      {predicted && (
        <div>
          <h3>Predicted Addresses</h3>
          <p>DAO: {predicted.moloch}</p>
          <p>Shares: {predicted.shares}</p>
          <p>Badges: {predicted.badges}</p>
          <p>Loot: {predicted.loot}</p>
        </div>
      )}
    </div>
  );
}
```

## Dependencies

Only ethers.js:

```bash
npm install ethers
```

## Common Issues

### Addresses don't match
- ✅ Verify implementation addresses
- ✅ Check initHolders/initShares array lengths match
- ✅ Ensure customSalt matches summon() parameter

### Type errors
- ✅ initShares must be strings (not numbers)
- ✅ All addresses must be valid hex strings

## Advanced: On-Chain Prediction

Deploy `DeploymentPredictor.sol` for on-chain address prediction:

```bash
forge create src/scripts/DeploymentPredictor.sol:DeploymentPredictor
```

Then call `predictAllAddresses()` view function.

## References

- Summoner contract: `src/Moloch.sol:2054`
- CREATE2 for Moloch: `src/Moloch.sol:2066`
- CREATE2 for tokens: `src/Moloch.sol:249`
- EIP-1014 (CREATE2): https://eips.ethereum.org/EIPS/eip-1014
