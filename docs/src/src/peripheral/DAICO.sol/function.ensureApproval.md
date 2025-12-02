# ensureApproval
[Git Source](https://github.com/z0r0z/SAW/blob/1098c25d112838b519fc1471aa11e5ab4aaeadc5/src/peripheral/DAICO.sol)

Ensures approval to spender is sufficient (>= type(uint128).max threshold).
Compatible with USDT-style tokens that require allowance to be 0 before setting non-zero.
We check against uint128.max as threshold because:
1. It's astronomically large (3.4e38) - will never be exhausted
2. After ZAMM uses some allowance via transferFrom, it stays above threshold
3. This avoids re-approving on every call (which breaks USDT)


```solidity
function ensureApproval(address token, address spender) ;
```

