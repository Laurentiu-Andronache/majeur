# FutarchyView
[Git Source](https://github.com/z0r0z/SAW/blob/f6a0ba3113db52f4093dc799a792326706ecd9e8/src/peripheral/MolochViewHelper.sol)


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

