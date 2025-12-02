# FutarchyView
[Git Source](https://github.com/z0r0z/SAW/blob/1098c25d112838b519fc1471aa11e5ab4aaeadc5/src/peripheral/MolochViewHelper.sol)


```solidity
struct FutarchyView {
bool enabled;
address rewardToken;
uint256 pool;
bool resolved;
uint8 winner; // 1 = YES/FOR, 0 = NO/AGAINST
uint256 finalWinningSupply;
uint256 payoutPerUnit; // scaled by 1e18
}
```

