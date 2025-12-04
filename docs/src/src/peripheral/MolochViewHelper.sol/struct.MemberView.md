# MemberView
[Git Source](https://github.com/z0r0z/SAW/blob/2b3c1d52c1b3c34600b54e1c2e32ae4821ae258a/src/peripheral/MolochViewHelper.sol)


```solidity
struct MemberView {
address account;
uint256 shares;
uint256 loot;
uint16 seatId; // 1..256, or 0 if none

uint256 votingPower; // current getVotes(account)
address[] delegates; // split delegation targets
uint32[] delegatesBps; // bps per delegate
}
```

