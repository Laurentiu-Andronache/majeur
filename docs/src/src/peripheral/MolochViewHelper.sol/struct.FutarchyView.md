# FutarchyView
[Git Source](https://github.com/z0r0z/SAW/blob/2b3c1d52c1b3c34600b54e1c2e32ae4821ae258a/src/peripheral/MolochViewHelper.sol)


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

