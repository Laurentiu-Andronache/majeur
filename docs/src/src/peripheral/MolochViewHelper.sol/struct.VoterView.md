# VoterView
[Git Source](https://github.com/z0r0z/SAW/blob/4543b7efb14e209f705fa5119a17da115da65148/src/peripheral/MolochViewHelper.sol)


```solidity
struct VoterView {
address voter;
uint8 support; // 0 = AGAINST, 1 = FOR, 2 = ABSTAIN
uint256 weight; // voting weight at snapshot
}
```

