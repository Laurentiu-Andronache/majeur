# MemberView
[Git Source](https://github.com/z0r0z/SAW/blob/f6a0ba3113db52f4093dc799a792326706ecd9e8/src/peripheral/MolochViewHelper.sol)


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

