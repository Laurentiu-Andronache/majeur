# VoterView
[Git Source](https://github.com/z0r0z/SAW/blob/2b3c1d52c1b3c34600b54e1c2e32ae4821ae258a/src/peripheral/MolochViewHelper.sol)


```solidity
struct VoterView {
address voter;
uint8 support; // 0 = AGAINST, 1 = FOR, 2 = ABSTAIN
uint256 weight; // voting weight at snapshot
}
```

