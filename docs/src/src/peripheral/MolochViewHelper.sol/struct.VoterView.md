# VoterView
[Git Source](https://github.com/z0r0z/SAW/blob/f6a0ba3113db52f4093dc799a792326706ecd9e8/src/peripheral/MolochViewHelper.sol)


```solidity
struct VoterView {
address voter;
uint8 support; // 0 = AGAINST, 1 = FOR, 2 = ABSTAIN
uint256 weight; // voting weight at snapshot
}
```

