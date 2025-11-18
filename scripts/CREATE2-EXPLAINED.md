# CREATE2 Address Prediction - Deep Dive

## What is CREATE2?

CREATE2 is an EVM opcode that creates a contract at a **deterministic address** based on:
1. The deployer address
2. A salt (32 bytes)
3. The contract's init code (bytecode)

Unlike `CREATE` (which uses a nonce), CREATE2 allows you to know the address before deployment.

## The Formula

```solidity
address = keccak256(
    0xff ++               // 1 byte
    deployer ++           // 20 bytes
    salt ++               // 32 bytes
    keccak256(initCode)   // 32 bytes
)[12:]                    // Take last 20 bytes
```

**Total input**: 1 + 20 + 32 + 32 = 85 bytes
**Output**: 32 bytes (take last 20 bytes for address)

## Moloch's Minimal Proxy Pattern

Moloch doesn't deploy full contracts. It uses **minimal proxies** that delegate to implementations.

### The Bytecode (54 bytes)

```
Position  | Bytes | Value                              | Description
----------|-------|------------------------------------|--------------------------
0x00-0x13 | 20    | 602d5f8160095f39f35f5f365f5f37365f73 | Proxy logic (prefix)
0x14-0x27 | 20    | <implementation address>            | Where to delegate calls
0x28-0x35 | 14    | 5af43d5f5f3e6029573d5ffd5b3d5ff3   | Proxy logic (suffix)
```

### What This Bytecode Does

When you call a function on the deployed proxy:
1. Takes the calldata
2. Delegates to the implementation address
3. Returns the result

It's a minimal forwarding contract.

### Why 54 bytes?

From the Moloch assembly:
```solidity
mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73)  // 20 bytes at position 0
mstore(0x14, implementation)                         // 20 bytes at position 20
mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3)   // 14 bytes at position 36

// Deploy from offset 0x0e (14), length 0x36 (54)
create2(value, 0x0e, 0x36, salt)
```

The memory layout skips the first 14 bytes of the prefix during deployment.

## Moloch Deployment Flow

### Step 1: Deploy Summoner

```solidity
contract Summoner {
    Moloch immutable implementation;

    constructor() {
        // Create Moloch implementation at salt = 0
        implementation = new Moloch{salt: bytes32(0)}();
    }
}
```

The Moloch implementation's constructor creates token implementations:
```solidity
contract Moloch {
    address immutable sharesImpl;
    address immutable badgesImpl;
    address immutable lootImpl;

    constructor() {
        bytes32 _salt = bytes32(bytes20(address(this)));
        sharesImpl = address(new Shares{salt: _salt}());
        badgesImpl = address(new Badges{salt: _salt}());
        lootImpl = address(new Loot{salt: _salt}());
    }
}
```

### Step 2: Summon a DAO

```solidity
function summon(
    ...,
    address[] calldata initHolders,
    uint256[] calldata initShares,
    bytes32 salt,
    ...
) public payable returns (Moloch dao) {
    // Compute salt from params
    bytes32 _salt = keccak256(abi.encode(initHolders, initShares, salt));

    // CREATE2 deploy Moloch clone
    assembly {
        // Build minimal proxy bytecode
        mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3)
        mstore(0x14, implementation)
        mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73)

        // CREATE2 deploy
        dao := create2(callvalue(), 0x0e, 0x36, _salt)
    }

    // Initialize the clone
    dao.init(...);
}
```

### Step 3: Initialize DAO (creates token clones)

```solidity
function init(...) public {
    require(msg.sender == SUMMONER);

    bytes32 _salt = bytes32(bytes20(address(this)));

    // CREATE2 deploy token clones
    badges = Badges(_init(badgesImpl, _salt));
    shares = Shares(_init(sharesImpl, _salt));
    loot = Loot(_init(lootImpl, _salt));
}

function _init(address _implementation, bytes32 _salt) internal returns (address clone) {
    assembly {
        // Same minimal proxy pattern
        mstore(0x24, 0x5af43d5f5f3e6029573d5ffd5b3d5ff3)
        mstore(0x14, _implementation)
        mstore(0x00, 0x602d5f8160095f39f35f5f365f5f37365f73)

        clone := create2(0, 0x0e, 0x36, _salt)
    }
}
```

## Salt Calculations

### Moloch DAO Salt

```solidity
salt = keccak256(abi.encode(initHolders, initShares, customSalt))
```

**Why this formula?**
- Includes initialization params
- Different holders/shares = different address
- customSalt allows same params to deploy at different addresses

**Example:**
```javascript
initHolders = ["0x1111...", "0x2222..."]
initShares = ["1000000000000000000", "2000000000000000000"]
customSalt = "0x0000...0000"

// ABI encode
encoded = abi.encode(
  ["address[]", "uint256[]", "bytes32"],
  [initHolders, initShares, customSalt]
)

// Hash
salt = keccak256(encoded)
```

### Token Salt

```solidity
salt = bytes32(bytes20(molochAddress))
```

**What does this do?**
- Takes the Moloch address (20 bytes)
- Casts to bytes32 (pads with zeros on the right)

**Example:**
```
molochAddress = 0x1234567890123456789012345678901234567890
bytes20(molochAddress) = 0x1234567890123456789012345678901234567890
bytes32(...) = 0x1234567890123456789012345678901234567890000000000000000000000000
                └── moloch address ──┘└── 24 zero bytes ──┘
```

**Why this formula?**
- Token addresses are tied to their Moloch
- Same Moloch always gets same token addresses
- Simple and deterministic

## Putting It Together

### Predict Moloch Address

```javascript
// Inputs
deployer = summonerAddress
salt = keccak256(abi.encode(initHolders, initShares, customSalt))
bytecode = "0x602d...73" + molochImpl.slice(2) + "5af4...f3"
initCodeHash = keccak256(bytecode)

// CREATE2
molochAddress = keccak256(
  "0xff" + deployer + salt + initCodeHash
).slice(-40)
```

### Predict Token Addresses

```javascript
// Inputs
deployer = molochAddress
salt = molochAddress + "000000000000000000000000"
bytecode = "0x602d...73" + sharesImpl.slice(2) + "5af4...f3"
initCodeHash = keccak256(bytecode)

// CREATE2
sharesAddress = keccak256(
  "0xff" + deployer + salt + initCodeHash
).slice(-40)
```

## Why This Matters for UI

1. **Show addresses before deployment**
   - User can see where their DAO will be
   - Can prepare integrations

2. **Verify deployment**
   - Check actual address matches predicted
   - Detect issues immediately

3. **Multi-chain planning**
   - Same params = same address (if Summoner is at same address)
   - Can coordinate across chains

4. **No backend needed**
   - All computation in frontend
   - Just needs implementation addresses

## Implementation Gotchas

### 1. Bytecode Construction

```javascript
// ❌ Wrong - includes "0x" twice
const bytecode = prefix + implementation + suffix;

// ✅ Right - strip "0x" from parts
const bytecode = prefix + implementation.slice(2) + suffix.slice(2);
```

### 2. Salt Padding

```javascript
// ❌ Wrong - direct conversion
const salt = molochAddress;

// ✅ Right - pad to 32 bytes
const salt = molochAddress.slice(2) + "000000000000000000000000";
```

### 3. Address Extraction

```javascript
// ❌ Wrong - takes first 20 bytes
const address = hash.slice(0, 42);

// ✅ Right - takes last 20 bytes
const address = "0x" + hash.slice(-40);
```

## Testing CREATE2 Predictions

```solidity
// Test contract
contract CREATE2Test {
    function predict(
        address deployer,
        bytes32 salt,
        bytes memory initCode
    ) public pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                deployer,
                salt,
                keccak256(initCode)
            )
        );
        return address(uint160(uint256(hash)));
    }
}
```

Compare your JS/TS implementation against this Solidity version.

## References

- EIP-1014 (CREATE2): https://eips.ethereum.org/EIPS/eip-1014
- Minimal Proxy (EIP-1167): https://eips.ethereum.org/EIPS/eip-1167
- Moloch source: `src/Moloch.sol`
