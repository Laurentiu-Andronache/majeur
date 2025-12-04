# IMoloch
[Git Source](https://github.com/z0r0z/SAW/blob/2b3c1d52c1b3c34600b54e1c2e32ae4821ae258a/src/peripheral/DAICO.sol)

Minimal Moloch interface for tap mechanism.


## Functions
### spendAllowance


```solidity
function spendAllowance(address token, uint256 amount) external;
```

### setAllowance


```solidity
function setAllowance(address spender, address token, uint256 amount) external;
```

### allowance


```solidity
function allowance(address token, address spender) external view returns (uint256);
```

### setTransfersLocked


```solidity
function setTransfersLocked(bool sharesLocked, bool lootLocked) external;
```

