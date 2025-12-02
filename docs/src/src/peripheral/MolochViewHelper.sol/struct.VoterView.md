# VoterView
[Git Source](https://github.com/z0r0z/SAW/blob/1098c25d112838b519fc1471aa11e5ab4aaeadc5/src/peripheral/MolochViewHelper.sol)


```solidity
struct VoterView {
address voter;
uint8 support; // 0 = AGAINST, 1 = FOR, 2 = ABSTAIN
uint256 weight; // voting weight at snapshot
}
```

