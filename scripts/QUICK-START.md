# Quick Start - Moloch CREATE2 Predictor

## What You Have

7 files in `/workspaces/SAW/src/scripts/`:

### For Your UI Developer (Give them these 3)

1. **`create2-predictor.ts`** - Main predictor (TypeScript) - **COPY THIS TO YOUR FRONTEND**
2. **`get-implementations.js`** - Get addresses from deployed Summoner
3. **`UI-GUIDE.md`** - Complete guide with examples

### Supporting Files

4. **`simple-create2-predictor.js`** - JavaScript version (if not using TypeScript)
5. **`CREATE2-EXPLAINED.md`** - Deep dive on CREATE2
6. **`DeploymentPredictor.sol`** - On-chain helper (optional)
7. **`README.md`** - Full documentation

## Usage (3 Steps)

### Step 1: Get Implementation Addresses

```bash
node get-implementations.js <YOUR_SUMMONER_ADDRESS> <RPC_URL>
```

Copy the output addresses.

### Step 2: Add to Your Frontend

```typescript
// Copy create2-predictor.ts into your project

import { predictAllAddresses } from './create2-predictor';

const IMPLEMENTATIONS = {
  summonerAddress: '0x...',      // From your deployment
  molochImplementation: '0x...',  // From step 1
  sharesImplementation: '0x...',  // From step 1
  badgesImplementation: '0x...',  // From step 1
  lootImplementation: '0x...',    // From step 1
};
```

### Step 3: Predict Addresses

```typescript
function predictDAO(holders: string[], shares: string[]) {
  return predictAllAddresses({
    ...IMPLEMENTATIONS,
    initHolders: holders,
    initShares: shares,
  });
}

// Returns: { moloch, shares, badges, loot }
```

## The CREATE2 Formula

```javascript
// 1. Build bytecode (54 bytes)
bytecode = PROXY_PREFIX + implementation + PROXY_SUFFIX

// 2. Compute salt
// For Moloch:
salt = keccak256(abi.encode(initHolders, initShares, customSalt))

// For tokens:
salt = molochAddress + "000000000000000000000000"

// 3. Compute address
address = keccak256(
  0xff ++ deployer ++ salt ++ keccak256(bytecode)
)[last 20 bytes]
```

## That's It!

No pre-computed hashes, no complex setup. Just implementation addresses + CREATE2 formula.

See **`UI-GUIDE.md`** for complete examples.
