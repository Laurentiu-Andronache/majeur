# FutarchyView
[Git Source](https://github.com/z0r0z/SAW/blob/4543b7efb14e209f705fa5119a17da115da65148/src/peripheral/MolochViewHelper.sol)


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

