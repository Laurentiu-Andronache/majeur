# VoterView
[Git Source](https://github.com/z0r0z/SAW/blob/85fb0d63390fce7bd4bfabe46851a83d4d00bbc1/src/peripheral/MolochViewHelper.sol)


```solidity
struct VoterView {
address voter;
uint8 support; // 0 = AGAINST, 1 = FOR, 2 = ABSTAIN
uint256 weight; // voting weight at snapshot
}
```

